
local newPcapParser = assert(require("pcapit").newPcapParser)

local out, log = io.stdout, io.stderr
local main, onPcapFrame, printStats


function main()
    local app = {
        parser = false,
        youngestEpochSec = -math.huge,
        oldestEpochSec = math.huge,
        foundPortNumbers = {},
    }
    app.parser = newPcapParser{
        dumpFilePath = "-",
        onFrame = function(f)onPcapFrame(app, f)end,
    }
    app.parser:resume()
    printStats(app)
end


function onPcapFrame( app, it )
    local sec, usec = it:frameArrivalTime()
    local srcPort, dstPort = it:trspSrcPort(), it:trspDstPort()
    --local srcIp, dstIp = it:netSrcIpStr(), it:netDstIpStr()
    --local isTcp = (it:tcpSeqNr() ~= nil)
    --
    if sec < app.oldestEpochSec then app.oldestEpochSec = sec end
    if sec > app.youngestEpochSec then app.youngestEpochSec = sec end
    --
    if not app.foundPortNumbers[srcPort] then app.foundPortNumbers[srcPort] = 1
    else app.foundPortNumbers[srcPort] = app.foundPortNumbers[srcPort] + 1 end
    if not app.foundPortNumbers[dstPort+100000] then app.foundPortNumbers[dstPort+100000] = 1
    else app.foundPortNumbers[dstPort+100000] = app.foundPortNumbers[dstPort+100000] + 1 end
end


function printStats( app )
    local sorted = {}
    local totalPackets, maxOccurValue = 0, 0
    for port, pkgcnt in pairs(app.foundPortNumbers) do
        if pkgcnt > maxOccurValue then maxOccurValue = pkgcnt end
        table.insert(sorted, { port=port, pkgcnt=pkgcnt })
        totalPackets = totalPackets + pkgcnt
    end
    table.sort(sorted, function(a, b)return a.pkgcnt > b.pkgcnt end)
    local dumpDurationSec = app.youngestEpochSec - app.oldestEpochSec
    local timeFmt = "!%Y-%m-%d_%H:%M:%SZ"
    out:write("\n")
    out:write(string.format("   Subject  TCP/UDP stats\n"))
    out:write(string.format("     Begin  %s\n", os.date(timeFmt,app.oldestEpochSec)))
    out:write(string.format("  Duration  %d seconds\n", dumpDurationSec))
    out:write(string.format("Throughput  %.1f packets per second\n", totalPackets / dumpDurationSec))
    out:write("\n")
    out:write("  .- TCP/UDP Port\n")
    out:write("  |   .-Direction (Send, Receive)\n")
    out:write("  |   |     .- Packets per second\n")
    out:write(".-+-. | .---+-.\n")
    local chartWidth = 60
    for i, elem in ipairs(sorted) do
        local port, pkgcnt = elem.port, elem.pkgcnt
        local dir = (port > 100000)and("R")or("S")
        if port > 100000 then port = port - 100000 end
        if port > 30000 then goto nextPort end
        local pkgsPerSec = math.floor((pkgcnt / dumpDurationSec)*10+.5)/10
        out:write(string.format("%5d %s %7.1f |", port, dir, pkgsPerSec))
        local barLen = pkgcnt / maxOccurValue
        --local barLen = (math.log(pkgcnt) / math.log(maxOccurValue))
        for i=1, chartWidth-1 do
            out:write((i < (barLen*chartWidth))and("=")or(" "))
        end
        out:write("|\n")
        ::nextPort::
    end
    out:write("\n")
end


main()

