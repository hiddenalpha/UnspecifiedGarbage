
local newPcapParser = assert(require("pcapit").newPcapParser)

local out, log = io.stdout, io.stderr
local main, onPcapFrame, vapourizeUrlVariables, printStats


function main()
    local app = {
        parser = false,
        youngestEpochSec = -math.huge,
        oldestEpochSec = math.huge,
        services = {},
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
    --
    if sec < app.oldestEpochSec then app.oldestEpochSec = sec end
    if sec > app.youngestEpochSec then app.youngestEpochSec = sec end
    --
    local portsOfInterest = {
        [  80] = true,
        [8080] = true,
        [7012] = true,
    }
    --if not portsOfInterest[dstPort] and not portsOfInterest[srcPort] then return end
    local trspPayload = it:trspPayload()
    local httpReqLinePart1, httpReqLinePart2, httpReqLinePart3 =
        trspPayload:match("^([A-Z/1.0]+) ([^ ]+) [^ \r\n]+\r?\n")
    if not httpReqLinePart1 then return end
    if httpReqLinePart1:find("^HTTP/1.%d$") then return end
    --log:write(string.format("%5d->%5d  %s %s %s\n", srcPort, dstPort, httpReqLinePart1, httpReqLinePart2, httpReqLinePart3))
    xService = trspPayload:match("\n[Xx]%-[Ss][Ee][Rr][Vv][Ii][Cc][Ee]:%s+([^\r\n]+)\r?\n");
    if not xService then return end
    --log:write("X-Service is '".. xService .."'\n")
    local obj = app.services[xService]
    if not obj then
        app.services[xService] = {
            xService = xService,
            count=0,
        }
    else
        assert(xService == obj.xService)
        obj.count = obj.count + 1
    end
end


function printStats( app )
    local sorted = {}
    local maxOccurValue = 0
    local overallCount = 0
    for _, reqObj in pairs(app.services) do
        if reqObj.count > maxOccurValue then maxOccurValue = reqObj.count end
        overallCount = overallCount + reqObj.count
        table.insert(sorted, reqObj)
    end
    table.sort(sorted, function(a, b)return a.count > b.count end)
    local dumpDurationSec = app.youngestEpochSec - app.oldestEpochSec
    local timeFmt = "!%Y-%m-%d_%H:%M:%SZ"
    out:write("\n")
    out:write(string.format("   Subject  Pressure by Services\n"))
    out:write(string.format("     Begin  %s\n", os.date(timeFmt,app.oldestEpochSec)))
    out:write(string.format("  Duration  %d seconds\n", dumpDurationSec))
    out:write(string.format("Throughput  %.1f HTTP requests per second\n", overallCount / dumpDurationSec))
    out:write("\n")
    out:write("  .-- HTTP Requests per Second\n")
    out:write("  |        .-- Service\n")
    out:write(".-+---.  .-+-----\n")
    for i, elem in ipairs(sorted) do
        local xService, count = elem.xService, elem.count
        local countPerSecond = math.floor((count / dumpDurationSec)*10+.5)/10
        out:write(string.format("%7.1f  %s\n", countPerSecond, xService))
    end
    out:write("\n")
end


main()

