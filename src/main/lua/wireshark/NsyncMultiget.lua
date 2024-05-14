if INCGUARD_06BMkSmD5M3PQVff then
    error( "Module loaded twice: E_20230526154810" )
else
    INCGUARD_06BMkSmD5M3PQVff = true


local CONTENT_TYPE_MULTIGET_RESPONSE = "application/multiget-response"
local MGET_CONTENT_CHUNK = 0x15
local MGET_CONTENT_TYPE = 0x0B
local MGET_EOF = 0x1B
local MGET_PATH = 0x01

local log = io.stderr

local attachInfoToTree, collectInfo, dissector, dissectorProtected, init, seal


function init()
    local app = seal{
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
    app.proto.fields = {
        app.field_path, app.field_cType, app.field_chunk, app.field_eof, app.field_error
    }
    app.proto.dissector = function(...)return dissectorProtected(app, ...)end
    DissectorTable.get("media_type"):add(CONTENT_TYPE_MULTIGET_RESPONSE, app.proto)
end


-- I disagree that concealing errors is funny. Therefore I prefer to
-- make them visible again with help of this workaround.
function dissectorProtected( app, ... )
    local ok, a, b, c = pcall(dissector, app, ...)
    if not ok then
        log:write("[ERROR] "..(a or"nil").."\n")
        error(a)
    else
        return a, b, c
    end
end


function dissector( app, buf, pinfo, tree )
    local frameNr = app.field_frameNr().value
    local info = app.frameInfo[frameNr]
    if not info then
        --log:write("[DEBUG] Dissect frame "..tostring(frameNr).."\n")
        if frameNr <= app.frameNrMax then
            log:write("[WARN ] frameNr "..frameNr.." unexpectedly smaller than ".. app.frameNrMax .."\n")
        end
        app.frameNrMax = frameNr
        collectInfo(app, buf, pinfo, tree)
    end
    attachInfoToTree(app, frameNr, buf, pinfo, tree)
end


function collectInfo( app, buf, pinfo, tree )
    local frameNr = app.field_frameNr().value
    assert(app.frameInfo[frameNr] == nil)
    local info = seal{
        mgetMsgs = {},
    }
    app.frameInfo[frameNr] = info
    --
    local tcpStream = app.field_tcpStrm()
    if not tcpStream then return --[[TODO Why is tcpStream nil?]] end
    tcpStream = tcpStream.value
    --if #app.oldBuf > 0 then log:write("[WARN ] TODO oldBuf has data. Use it!\n") end
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
        msg.tag = buf(off, 1):uint()
        if msg.tag > 0x7F then -- TODO
            log:write("[WARN ] Multibyte tag val (".. tostring(msg.tag) ..") not impl yet!\n")
        end
        msg.tagOff = off
        msg.tagLen = 1 -- TODO multibyte support
        off = off + 1
        --log:write("Found multiget tag ".. tostring(msg.tag) .."\n")
        local count, shift, len = 0, 0, 0
        while true do
            local b = buf(off, 1):uint();
            len = bit.bor(len, (bit.lshift(bit.band(b, 0x7F), shift)))
            off = off + 1;  count = count + 1;  shift = shift + 7
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


function attachInfoToTree( app, frameNr, buf, pinfo, tree )
    local info = app.frameInfo[frameNr]
    local protoTree = tree:add(app.proto, buf(), "Nsync Multiget Protocol")
    for _, mgetMsg in ipairs(info.mgetMsgs) do
        local tileStr = "Nsync Multiget Message"
        if mgetMsg.errStr then tileStr = tileStr .." (ERROR)" end
        local msgTree = protoTree:add(app.proto, buf(mgetMsg.msgOff, mgetMsg.msgLen), tileStr)
        if mgetMsg.errStr then
            local msg = "ERROR: ".. mgetMsg.errStr
            msgTree:add(buf(mgetMsg.tagOff,buf:raw():len()-mgetMsg.tagOff), msg)
            msgTree:add(app.field_error, msg)
        else
            local tagStr, fieldFunc
            if mgetMsg.tag == MGET_PATH then
                tagStr = "Type PATH (0x01)"
                fieldFunc = app.field_path
            elseif mgetMsg.tag == MGET_CONTENT_TYPE then
                tagStr = "Type CONTENT_TYPE (0x0B)"
                fieldFunc = app.field_cType
            elseif mgetMsg.tag == MGET_CONTENT_CHUNK then
                tagStr = "Type CONTENT_CHUNK (0x15)"
                fieldFunc = app.field_chunk
            elseif mgetMsg.tag == MGET_EOF then
                tagStr = "Type EOF (0x1B)"
                fieldFunc = app.field_eof
            else
                tagStr = "N/A ("..tostring(mgetMsg.tag)..")"
                fieldFunc = app.field_error
            end
            msgTree:add(buf(mgetMsg.tagOff,mgetMsg.tagLen), tagStr)
            msgTree:add(buf(mgetMsg.lenOff,mgetMsg.lenLen), "Length ".. mgetMsg.len .." bytes")
            msgTree:add(fieldFunc, buf(mgetMsg.valOff, mgetMsg.valLen))
            --
        end
    end
end


function seal(obj)
    return setmetatable(obj, {
        __index = function(t,k,v)error("No such field '"..(k or"nil").."'")end,
        __newindex = function(t,k,v)error("No such field '"..(k or"nil").."'")end,
    })
end


init()    

end -- INCGUARD_06BMkSmD5M3PQVff
