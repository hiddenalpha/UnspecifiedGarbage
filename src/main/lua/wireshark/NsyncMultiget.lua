if INCGUARD_20230313152157 then
    error( "Module loaded twice: E_20230526154810" )
else
    INCGUARD_20230313152157 = true


local CONTENT_TYPE_MULTIGET_RESPONSE = "application/multiget-response"
local MGET_CONTENT_CHUNK = 0x15
local MGET_CONTENT_TYPE = 0x0B
local MGET_EOF = 0x1B
local MGET_PATH = 0x01

local log = io.stderr
local mod = {}


function mod.init()
    local that = mod.seal{
        proto = Proto("Multiget", "Nsync Multiget Response"),
        field_frameNr = Field.new("frame.number"),
        field_tcpStrm = Field.new("tcp.stream"),
        field_httpReqMth = Field.new("http.request.method"),
        field_httpRspCode = Field.new("http.response.code"),
        field_path = ProtoField.string("multiget.path", "Path"),
        field_cType = ProtoField.string("multiget.contentType", "Content Type"),
        field_chunk = ProtoField.string("multiget.chunk", "Chunk"),
        field_eof = ProtoField.string("multiget.eof", "EOF"),
        field_error = ProtoField.string("multiget.error", "Error"),
        frameNrMax = 0,
        tcpBuf = {}, -- key=tcpStream+srcPort val=string - half-baked buffer from last packet
        prevReqContentType = {},
        prevRspContentType = {},
        frameInfo = {}, -- key=frameNr val=info
    }
    that.proto.fields = {
        that.field_path, that.field_cType, that.field_chunk, that.field_eof, that.field_error
    }
    that.proto.dissector = function(...)return mod.dissectorProtected(that, ...)end
    DissectorTable.get("media_type"):add(CONTENT_TYPE_MULTIGET_RESPONSE, that.proto)
end


-- tshark thinks it is funny to conceal errors. So we have to workaround it.
function mod.dissectorProtected( that, ... )
    local ok, a, b, c = pcall(mod.dissector, that, ...)
    if not ok then
        log:write("[ERROR] "..(a or"nil").."\n")
        error(a)
    else
        return a, b, c
    end
end


function mod.dissector( that, buf, pinfo, tree )
    local frameNr = that.field_frameNr().value
    local info = that.frameInfo[frameNr]
    if not info then
        --log:write("[DEBUG] Dissect frame "..tostring(frameNr).."\n")
        if frameNr <= that.frameNrMax then
            log:write("[WARN ] frameNr "..frameNr.." unexpectedly smaller than ".. that.frameNrMax .."\n")
        end
        that.frameNrMax = frameNr
        mod.collectInfo(that, buf, pinfo, tree)
    end
    mod.attachInfoToTree(that, frameNr, buf, pinfo, tree)
end


function mod.collectInfo( that, buf, pinfo, tree )
    local frameNr = that.field_frameNr().value
    assert(that.frameInfo[frameNr] == nil)
    local info = mod.seal{
        mgetMsgs = {},
    }
    that.frameInfo[frameNr] = info
    --
    local tcpStream = that.field_tcpStrm()
    if not tcpStream then return --[[TODO Why is tcpStream nil?]] end
    tcpStream = tcpStream.value
    --if #that.oldBuf > 0 then log:write("[WARN ] TODO oldBuf has data. Use it!\n") end
    --
    local off = 0
    local raw = buf:raw()
    while true do
        local msg = {
            msgOff = off, msgLen = raw:len() - off,
            errStr = false,
            tagOff = false, tagLen = false, tag = false,
            lenOff = false, lenLen = false, len = false,
        }
        msg.tag = buf(off,1):uint()
        if msg.tag > 0x7F then log:write("[WARN ] Multibyte tag val ("..tostring(msg.tag)..") not impl yet!\n") end -- TODO
        msg.tagOff = off
        msg.tagLen = 1 -- TODO multibyte support
        off = off + 1
        --log:write("Found multiget tag ".. tostring(msg.tag) .."\n")
        local count = 0
        local shift = 0
        local len = 0
        while true do
            local b = buf(off, 1):uint();
            len = bit.bor(len, (bit.lshift(bit.band(b, 0x7F), shift)))
            off = off +1;  count = count +1;  shift = shift +7
            if bit.band(b, 0x80) == 0 then break end
            if count > 8 then
                msg.errStr = "Msg Length looks too large"
                table.insert(info.mgetMsgs, msg)
                return
            end
        end
        msg.len = len
        msg.lenOff = off - count
        msg.lenLen = count
        msg.valOff = off
        msg.valLen = len
        off = off + len
        msg.msgLen = off - msg.msgOff
        table.insert(info.mgetMsgs, msg)
        ---
        if off == raw:len() then break end
        assert(off < raw:len())
    end
end


function mod.attachInfoToTree( that, frameNr, buf, pinfo, tree )
    local info = that.frameInfo[frameNr]
    local protoTree = tree:add(that.proto, buf(), "Nsync Multiget Protocol")
    for _,mgetMsg in ipairs(info.mgetMsgs) do
        local tileStr = "Nsync Multiget Message"
        if mgetMsg.errStr then tileStr = tileStr .. " (ERROR)" end
        local msgTree = protoTree:add(that.proto, buf(mgetMsg.msgOff, mgetMsg.msgLen), tileStr)
        if mgetMsg.errStr then
            local msg = "ERROR: ".. mgetMsg.errStr
            msgTree:add(buf(mgetMsg.tagOff,buf:raw():len()-mgetMsg.tagOff), msg)
            msgTree:add(that.field_error, msg)
        else
            local tagStr, fieldFunc
            if mgetMsg.tag == MGET_PATH then
                tagStr = "Type PATH (0x01)"
                fieldFunc = that.field_path
            elseif mgetMsg.tag == MGET_CONTENT_TYPE then
                tagStr = "Type CONTENT_TYPE (0x0B)"
                fieldFunc = that.field_cType
            elseif mgetMsg.tag == MGET_CONTENT_CHUNK then
                tagStr = "Type CONTENT_CHUNK (0x15)"
                fieldFunc = that.field_chunk
            elseif mgetMsg.tag == MGET_EOF then
                tagStr = "Type EOF (0x1B)"
                fieldFunc = that.field_eof
            else
                tagStr = "N/A ("..tostring(mgetMsg.tag)..")"
                fieldFunc = that.field_error
            end
            msgTree:add(buf(mgetMsg.tagOff,mgetMsg.tagLen), tagStr)
            msgTree:add(buf(mgetMsg.lenOff,mgetMsg.lenLen), "Length ".. mgetMsg.len .." bytes")
            msgTree:add(fieldFunc, buf(mgetMsg.valOff, mgetMsg.valLen))
            --
        end
    end
end


function mod.seal(obj)
    return setmetatable(obj, {
        __index = function(t,k,v)error("No such field '"..(k or"nil").."'")end,
        __newindex = function(t,k,v)error("No such field '"..(k or"nil").."'")end,
    })
end


mod.init()    

end -- INCGUARD_20230313152157
