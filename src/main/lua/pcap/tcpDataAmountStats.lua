
local newPcapParser = assert(require("pcapit").newPcapParser)

local main, onPcapFrame, vapourizeUrlVariables, printResult


function main()
    local app = {
        parser = false,
        youngestEpochSec = -math.huge,
        oldestEpochSec = math.huge,
        nextStreamNr = 1,
        httpStreams = {},
    }
    app.parser = newPcapParser{
        dumpFilePath = "-",
        onFrame = function(f)onPcapFrame(app, f)end,
    }
    app.parser:resume()
    printResult(app)
end


function onPcapFrame( app, it )
    local out = io.stdout
    --
    if not it:tcpSeqNr() then return end
    --
    --
    local sec, usec = it:frameArrivalTime()
    if sec < app.oldestEpochSec then app.oldestEpochSec = sec end
    if sec > app.youngestEpochSec then app.youngestEpochSec = sec end
    --
    local srcIp, dstIp = it:netSrcIpStr(), it:netDstIpStr()
    local srcPort, dstPort = it:trspSrcPort(), it:trspDstPort()
    local lowIp = (srcIp < dstIp)and(srcIp)or(dstIp)
    local higIp = (lowIp == dstIp)and(srcIp)or(dstIp)
    local lowPort = math.min(srcPort, dstPort)
    local streamId = lowIp .."\0".. higIp .."\0".. lowPort
    local stream = app.httpStreams[streamId]
    if not stream then
        stream = {
            srcIp = srcIp, dstIp = dstIp, srcPort = srcPort, dstPort = dstPort,
            streamNr = app.nextStreamNr, numBytes = 0,
        }
        app.nextStreamNr = app.nextStreamNr + 1
        app.httpStreams[streamId] = stream
    end
    local trspPayload = it:trspPayload()
    stream.numBytes = stream.numBytes + trspPayload:len()
end


function printResult( app )
    local out = io.stdout
    local sorted = {}
    local overalValue, maxValue = 0, 0
    for _, stream in pairs(app.httpStreams) do
        if stream.numBytes > maxValue then maxValue = stream.numBytes end
        overalValue = overalValue + stream.numBytes
        table.insert(sorted, stream)
    end
    table.sort(sorted, function(a, b)return a.numBytes > b.numBytes end)
    local dumpDurationSec = app.youngestEpochSec - app.oldestEpochSec
    local overallBytesPerSec = overalValue / dumpDurationSec
    local maxValuePerSec = maxValue / dumpDurationSec
    local timeFmt = "!%Y-%m-%d_%H:%M:%SZ"
    out:write("\n")
    out:write(string.format("   Subject  TCP data throughput\n"))
    out:write(string.format("     Begin  %s\n", os.date(timeFmt,app.oldestEpochSec)))
    out:write(string.format("  Duration  %d seconds\n", dumpDurationSec))
    out:write(string.format("   Overall  %.3f KiB per second (%.3f KiBit per second)\n",
        overallBytesPerSec/1024, overallBytesPerSec/1024*8))
    out:write("\n")
    out:write("   .-- KiB per Second\n")
    out:write("   |            .-- IP endpoints\n")
    out:write("   |            |                          .-- TCP server port\n")
    out:write("   |            |                          |       .-- TCP Payload (less is better)\n")
    out:write("   |            |                          |       |\n")
    out:write(".--+----.  .----+----------------------.  .+--.  .-+------------\n")
    local bar = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    for i, elem in ipairs(sorted) do
        local streamNr, srcIp, dstIp, srcPort, dstPort, numBytes =
            elem.streamNr, elem.srcIp, elem.dstIp, elem.srcPort, elem.dstPort, elem.numBytes
        local lowPort = math.min(srcPort, dstPort)
        local bytesPerSecond = math.floor((numBytes / dumpDurationSec)*10+.5)/10
        out:write(string.format("%9.3f  %-14s %-14s  %5d ", bytesPerSecond/1024, srcIp, dstIp, lowPort))
        local part = bytesPerSecond / maxValuePerSec;
        out:write(bar:sub(0, math.floor(part * bar:len())))
        out:write("\n")
    end
    out:write("\n")
end


main()

