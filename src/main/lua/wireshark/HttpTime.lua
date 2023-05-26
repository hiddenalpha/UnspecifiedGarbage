if INCGUARD_20211104184619 then
    error( "Module loaded twice: E_20230526154713" )
else
    INCGUARD_20211104184619 = true


local out, log = io.stdout, io.stderr
local mod = {}


function mod.init()
    local that = mod.seal{
        proto = Proto("__", "Additional Metadata"),
        f_andy_httpTime = ProtoField.float("_.httpTime", "HttpTime"),
        f_andy_synSeen = ProtoField.bool("_.synSeen", "SynSeen"),
        f_andy_uri = ProtoField.string("_.uri", "Request URI"),
        f_andy_contentType = ProtoField.string("_.contentType", "Content Type"),
        f_andy_xService = ProtoField.string("_.xService", "X Service"),
        f_andy_xVehicleId = ProtoField.string("_.xVehicleId", "X Vehicleid"),
        f_http_request = Field.new("http.request"),
        f_http_time = Field.new("http.time"),
        f_http_uri = Field.new("http.request.uri"),
        f_tcp_flags_syn = Field.new("tcp.flags.syn"),
        f_tcp_stream = Field.new("tcp.stream"),
        f_frame_number = Field.new("frame.number"),
        frameNrMax = 0,
        frameInfo = {},
        prevUris = {}, -- key=tcpStream val=string - URL path of the last http request.
        prevContentType = {},
        prevXService = {}, -- key=tcpStream val=string - Value of 'X-Service' HTTP header.
        prevXVehicleId = {},
        synSeen = {}, -- key=tcpStream val=bool - true if we have a SYN for this stream.
    }
    that.proto.dissector = function(...)return mod.dissectorProtected(that,...)end
    that.proto.fields = {
        that.f_andy_httpTime,
        that.f_andy_synSeen, that.f_andy_uri, that.f_andy_contentType,
        that.f_andy_xService, that.f_andy_xVehicleId,
    }
    register_postdissector(that.proto)
end


function mod.dissector( that, buf, pinfo, tree )
    local frameNr = that.f_frame_number().value
    local info = that.frameInfo[frameNr]
    if not info then
        if frameNr <= that.frameNrMax then
            log:write("[WARN ] frameNr "..frameNr.." unexpectedly smaller than ".. that.frameNrMax .."\n")
        end
        that.frameNrMax = frameNr
        mod.collectInfo(that, buf, pinfo, tree, frameNr)
    end
    mod.attachInfoToTree(that, buf, pinfo, tree, frameNr)
end


function mod.collectInfo( that, buf, pinfo, tree, frameNr )
    assert(that.frameInfo[frameNr] == nil)
    local info = mod.seal{
        synSeen = false,
        httpTime = false,
        httpUri = false,
        cType = false,
        xService = false,
        xVehicleId = false,
    } that.frameInfo[frameNr] = info
    -- Tcp Stream
    local tcpStream = that.f_tcp_stream()
    if not tcpStream then return --[[TODO Why is tcpStream nil?]] end
    tcpStream = tcpStream.value
    --
    if that.f_tcp_flags_syn().value then
        that.synSeen[tcpStream] = true
        info.synSeen = true
    end
    -- HTTP
    local httpTime = that.f_http_time()
    local isHttpRequest = that.f_http_request()
    local isHttpResponse = (httpTime ~= nil)
    if isHttpRequest then
        local tmp
        tmp = tostring(that.f_http_uri())
        that.prevUris[tcpStream] = tmp
        info.httpUri = tmp or false
        tmp = buf:raw():match("\x0A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]:[%s]*([^\x0D\x0A]+)[\x0D\x0A]")
        that.prevContentType[tcpStream] = tmp or nil
        info.cType = tmp or false
        tmp = buf:raw():match("\x0A[Xx]%-[Ss][Ee][Rr][Vv][Ii][Cc][Ee]:[%s]*([^\x0D\x0A]+)[\x0D\x0A]")
        that.prevXService[tcpStream] = tmp or nil
        info.xService = tmp or false
        tmp = buf:raw():match("\x0A[Xx]%-[Vv][Ee][Hh][Ii][Cc][Ll][Ee][Ii][Dd]:[%s]*([^\x0D\x0A]+)[\x0D\x0A]")
        that.prevXVehicleId[tcpStream] = tmp or nil
        info.xVehicleId = tmp or false
    elseif isHttpResponse then
        -- Need to re-evaluate Content-Type, as response has this too
        local contentType = buf:raw():match("\x0A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]:[%s]*([^\x0D\x0A]+)[\x0D\x0A]")
        that.prevContentType[tcpStream] = (contentType)and(contentType)or(nil)
        info.httpTime = tonumber(tostring(httpTime))
    end
    -- Enrich by info from other packets around this same tcpStream
    info.synSeen = that.synSeen[tcpStream] or false
    info.httpUri = that.prevUris[tcpStream] or false
    info.cType = that.prevContentType[tcpStream] or false
    info.xService = that.prevXService[tcpStream] or false
    info.xVehicleId = that.prevXVehicleId[tcpStream] or false
end


function mod.attachInfoToTree( that, buf, pinfo, tree, frameNr )
    local info = that.frameInfo[frameNr]
    local metaTree = tree:add(that.proto, "AdditionalMetadata")
    local tmp
    metaTree:add(that.f_andy_synSeen, info.synSeen)
    if info.httpUri then metaTree:add(that.f_andy_uri, info.httpUri) end
    if info.cType then metaTree:add(that.f_andy_contentType, info.cType) end
    if info.xService then metaTree:add(that.f_andy_xService, info.xService) end
    if info.xVehicleId then metaTree:add(that.f_andy_xVehicleId, info.xVehicleId) end
    if info.httpTime then metaTree:add(that.f_andy_httpTime, info.httpTime) end
end


-- Looks like tshark just conceals all errors inside this callback. This
-- wrapper is to make our problems visible again.
function mod.dissectorProtected( that, buf, pinfo, tree )
    local ok, msg = pcall(function( that, buf, pinfo, tree )
        mod.dissector( that, buf, pinfo, tree )
    end, that, buf, pinfo, tree )
    if not ok then
        log:write("[ERROR] "..(msg or"nil").."\n")
    end
end


function mod.seal(obj)
    return setmetatable(obj, {
        __index = function(t,k,v)error("No such field '"..(k or"nil").."'")end,
        __newindex = function(t,k,v)error("No such field '"..(k or"nil").."'")end,
    })
end



mod.init()    

end -- INCGUARD_20211104184619

