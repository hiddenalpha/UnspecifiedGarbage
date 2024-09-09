
-- Related: SDCISA-17355.

local objectSeal = require("scriptlee").objectSeal
local newPcapDumper = require("pcapit").newPcapDumper
local newPcapParser = require("pcapit").newPcapParser


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

    print("", trspProtoStr, frame.trspProtoStr, "")
    print("", frameCaplen, frame.frameCaplen(), "")
    print("", frameLen, frame.frameLen(), "")
    print("", trspSrcPort, frame.trspSrcPort(), "")
    print("", netProtoStr, frame.netProtoStr(), "")
    print("", netSrcIpStr, frame.netSrcIpStr(), "")
    print("", trspDstPort, frame.trspDstPort(), "")
    print("", tcpFlags, frame.tcpFlags(), "")
    print("", frameArrivalTime, frame.frameArrivalTime(), "")
    print("", rawFrame, frame.rawFrame(), "")
    print("", tcpSeqNr, frame.tcpSeqNr(), "")
    print("", netDstIpStr, frame.netDstIpStr(), "")
    print("", tcpAckNr, frame.tcpAckNr(), "")
    print("", trspPayload, frame.trspPayload(), "")

    error("whopsii")
end


function main()
    local app = objectSeal{
        srcPath = "houston-prod-tcp-20240906-143144Z.pcap",
        parser = false,
    }
    app.parser = newPcapParser{
        dumpFilePath = app.srcPath,
        onFrame = function(...)onFrame(app, ...)end,
    }
    app.parser:resume()
end


main()
