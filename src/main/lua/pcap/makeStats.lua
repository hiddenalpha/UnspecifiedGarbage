
local newPcapParser = assert(require("pcapit").newPcapParser)
local newPcapDumper = assert(require("pcapit").newPcapDumper)

local main, onPcapFrame, printStats


function main()
    local app = {
        dumpr = false,
        parser = false,
        foundPortNumbers = {},
        youngestEpochSec = -math.huge,
        oldestEpochSec = math.huge,
    }
    --app.dumpr = newPcapDumper{
    --    dumpFilePath = "/tmp/meins/my.out.pcap",
    --}
    app.parser = newPcapParser{
        dumpFilePath = "-",
        onFrame = function(f)onPcapFrame(app, f)end,
    }
    app.parser:resume()
    printStats(app)
end


function onPcapFrame( app, it )
    local out = io.stdout
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
    --
    local portOfInterest = 7012
    if dstPort == portOfInterest then
        local httpMethod, httpUri =
            it:trspPayload():match("^([A-Z]+) ([^ ]+) [^ \r\n]+\r?\n")
        if httpMethod then
            out:write(string.format("%5d->%5d %s %s\n", srcPort, dstPort, httpMethod, httpUri))
        end
    elseif srcPort == portOfInterest then
        local httpStatus, httpPhrase =
            it:trspPayload():match("^HTTP/%d.%d (%d%d%d) ([^\r\n]*)\r?\n")
        if httpStatus then
            out:write(string.format("%5d<-%5d %s %s\n", srcPort, dstPort, httpStatus, httpPhrase))
        end
    end
    --if srcPort ~= 53 and dstPort ~= 53 then return end
    if app.dumpr then it:dumpTo(app.dumpr) end
end


function printStats( app )
    local out = io.stdout
    local sorted = {}
    local maxOccurValue = 0
    for port, pkgcnt in pairs(app.foundPortNumbers) do
        if pkgcnt > maxOccurValue then maxOccurValue = pkgcnt end
        table.insert(sorted, { port=port, pkgcnt=pkgcnt })
    end
    table.sort(sorted, function(a, b)return a.pkgcnt > b.pkgcnt end)
    local dumpDurationSec = app.youngestEpochSec - app.oldestEpochSec
    local timeFmt = "!%Y-%m-%d_%H:%M:%SZ"
    out:write("\n")
    out:write("Statistics\n")
    out:write("From: ")out:write(os.date(timeFmt,app.oldestEpochSec))out:write("\n")
    out:write("To:   ")out:write(os.date(timeFmt,app.youngestEpochSec))out:write("\n")
    out:write("\n")
    out:write("  .- Port (TCP/UDP)\n")
    out:write("  |   .-Direction (Send, Receive)\n")
    out:write("  |   |     .- Frames per second\n")
    out:write(".-+-. | .---+-.   Amount of frames compared:\n")
    local chartWidth = 60
    local cntPrinted = 0
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
        cntPrinted = cntPrinted + 1
        if cntPrinted >= 20 then break end
        ::nextPort::
    end
    out:write("\n")
end


main()

