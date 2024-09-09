
-- Related: SDCISA-17355.

local newPcapDumper = require("pcapit").newPcapDumper
local newPcapParser = require("pcapit").newPcapParser
local log, dst = io.stderr, io.stdout


function onFrame( app, frame )
    -- Fields in 'frame' are:
    --   trspProtoStr
    --   dumpTo
    --   frameCaplen
    --   frameLen
    --   trspSrcPort
    --   netProtoStr
    --   netSrcIpStr
    --   pause
    --   trspDstPort
    --   datalinkStr
    --   tcpFlags
    --   frameArrivalTime
    --   rawFrame
    --   tcpSeqNr
    --   netDstIpStr
    --   tcpAckNr
    --   trspPayload

    local trspPayload = frame:trspPayload()
    local a, b, c = trspPayload:match("^([^ ]+) ([^ ]+) ([^\r\n]+)\r?\n")
    local isHttpRsp = (a and a:sub(1, 6) == "HTTP/1.")
    local isHttpReq = (a and not isHttpRsp)
    local httpProto, httpStatus, httpPhrase, httpMethod, httpUri
    if isHttpRsp then httpProto, httpStatus, httpPhrase = a, b, c end
    if isHttpReq then httpMethod, httpUri, httpProto = a, b, c end
    --
    if  trspPayload
    and trspPayload:find("HTTP")
    and not trspPayload:find("^GET ")
    and not trspPayload:find("^PUT ")
    and not trspPayload:find("^POST ")
    and not trspPayload:find("^DELETE ")
    then
        log:write("SUB: '".. trspPayload:sub(1, 6) .."'\n")
    end
    --
    local tcpStreamKey = getTcpStreamKey(frame)
    if isHttpReq then
        if not httpUri:find("/preflux/from/vehicles/[^/]+/system/status/v1/system/info") then return end
        log:write(os.date("%H:%M:%S", frame:frameArrivalTime()) .." "
            .. httpMethod .." ".. httpUri.." ".. httpProto .."\n")
        local tcpStreamFoo = app.tcpStreamFooById[tcpStreamKey]
        if not tcpStreamFoo then
            tcpStreamFoo = 42
            app.tcpStreamFooById[tcpStreamKey] = tcpStreamFoo
        end
    end
    if isHttpRsp then
        log:write(os.date("%H:%M:%S", frame:frameArrivalTime()) .." "
            .. httpProto .." ".. httpStatus .." ".. httpPhrase .."\n")
    end
    app.tcpStreamFooById[tcpStreamKey] = false

    --if not isHttpReq and not isHttpRsp then return end
    --if not foo then foo = 1 else foo = foo + 1 end
    --if foo > 99 then error("TUDUDELI_vjUAADBKAABXTQAA") end
end


function getTcpStreamKey( frame )
    local f = frame
    return f:netDstIpStr() .."\0".. f:netSrcIpStr() .."\0".. f:trspDstPort() .."\0".. f:trspSrcPort()
end


function main()
    log:write("[WARN ] This script is NOT ready for usage.\n")
    local app = {
        srcPath = "houston-prod-tcp-20240906-143144Z.pcap",
        parser = false,
        tcpStreamFooById = {},
    }
    app.parser = newPcapParser{
        dumpFilePath = app.srcPath,
        onFrame = function(...)onFrame(app, ...)end,
    }
    app.parser:resume()
end


main()
