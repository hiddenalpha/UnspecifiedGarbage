
local newPcapParser = assert(require("pcapit").newPcapParser)

local out, log = io.stdout, io.stderr
local main, onPcapFrame, vapourizeUrlVariables, printHttpRequestStats


function main()
    local app = {
        parser = false,
        youngestEpochSec = -math.huge,
        oldestEpochSec = math.huge,
        foundHttpRequests = {},
    }
    app.parser = newPcapParser{
        dumpFilePath = "-",
        onFrame = function(f)onPcapFrame(app, f)end,
    }
    app.parser:resume()
    printHttpRequestStats(app)
end


function onPcapFrame( app, it )
    local sec, usec = it:frameArrivalTime()
    local srcPort, dstPort = it:trspSrcPort(), it:trspDstPort()
    --
    if sec < app.oldestEpochSec then app.oldestEpochSec = sec end
    if sec > app.youngestEpochSec then app.youngestEpochSec = sec end
    --
    local portOfInterest = 7012
    if dstPort == portOfInterest then
        local httpMethod, httpUri =
            it:trspPayload():match("^([A-Z]+) ([^ ]+) [^ \r\n]+\r?\n")
        if httpMethod then
            --out:write(string.format("%5d->%5d %s %s\n", srcPort, dstPort, httpMethod, httpUri))
            httpUri = vapourizeUrlVariables(app, httpUri)
            local key = httpUri -- httpMethod .." ".. httpUri
            local obj = app.foundHttpRequests[key]
            if not obj then
                obj = { count=0, httpMethod=false, httpUri=false, }
                app.foundHttpRequests[key] = obj
            end
            obj.count = obj.count + 1
            obj.httpMethod = httpMethod
            obj.httpUri = httpUri
        end
    elseif srcPort == portOfInterest then
        local httpStatus, httpPhrase =
            it:trspPayload():match("^HTTP/%d.%d (%d%d%d) ([^\r\n]*)\r?\n")
        if httpStatus then
            --out:write(string.format("%5d<-%5d %s %s\n", srcPort, dstPort, httpStatus, httpPhrase))
        end
    end
end


function vapourizeUrlVariables( app, uri )
    -- A very specific case
    uri = uri:gsub("^(/houston/users/)%d+(/.*)$", "%1{}%2");
    if uri:find("^/houston/users/[^/]+/user/.*$") then return uri end
    --
    -- Try to do some clever guesses to group URIs wich only differ in variable segments
    uri = uri:gsub("(/|-)[%dI_-]+/", "%1{}/"):gsub("(/|-)[%dI-]+/", "%1{}/") -- two turns, to also get consecutive number segments
    uri = uri:gsub("([/-])[%dI_-]+$", "%1{}")
    uri = uri:gsub("/%d+(%.%w+)$", "/{}%1")
    uri = uri:gsub("(/|-)[%w%d]+%-[%w%d]+%-[%w%d]+%-[%w%d]+%-[%w%d]+(/?)$", "%1{}%2")
    uri = uri:gsub("/v%d/", "/v0/") -- Merge all API versions
    --
    -- Generify remaining by trimming URIs from right
    uri = uri:gsub("^(/from%-houston/[^/]+/eagle/nsync/).*$", "%1...")
    uri = uri:gsub("^(/from%-houston/[^/]+/eagle/fis/information/).*$", "%1...")
    uri = uri:gsub("^(/from%-houston/[^/]+/eagle/nsync/v%d/push/trillian%-phonebooks%-).*$", "%1...")
    uri = uri:gsub("^(/from%-houston/[^/]+/eagle/timetable/wait/).*$", "%1...")
    uri = uri:gsub("^(/houston/service%-instances/).*$", "%1...")
    uri = uri:gsub("^(/vortex/stillInterested%?vehicleId%=).*$", "%1...")
    uri = uri:gsub("^(/houston/[^/]+/[^/]+/).*$", "%1...")
    return uri
end


function printHttpRequestStats( app )
    local sorted = {}
    local maxOccurValue = 0
    local overallCount = 0
    for _, reqObj in pairs(app.foundHttpRequests) do
        if reqObj.count > maxOccurValue then maxOccurValue = reqObj.count end
        overallCount = overallCount + reqObj.count
        table.insert(sorted, reqObj)
    end
    table.sort(sorted, function(a, b)return a.count > b.count end)
    local dumpDurationSec = app.youngestEpochSec - app.oldestEpochSec
    local timeFmt = "!%Y-%m-%d_%H:%M:%SZ"
    out:write("\n")
    out:write(string.format("   Subject  HTTP Request Statistics\n"))
    out:write(string.format("     Begin  %s\n", os.date(timeFmt,app.oldestEpochSec)))
    out:write(string.format("  Duration  %d seconds\n", dumpDurationSec))
    out:write(string.format("Throughput  %.1f HTTP requests per second\n", overallCount / dumpDurationSec))
    out:write("\n")
    out:write("   .-- HTTP Requests per Second\n")
    out:write("   |       .-- URI\n")
    out:write(".--+--.  .-+---------\n")
    local chartWidth = 60
    local cntPrinted = 0
    for i, elem in ipairs(sorted) do
        local count, httpMethod, httpUri = elem.count, elem.httpMethod, elem.httpUri
        local cntPerSec = math.floor((count / dumpDurationSec)*10+.5)/10
        out:write(string.format("%7.1f  %s\n", cntPerSec, httpUri))
        cntPrinted = cntPrinted + 1
        ::nextPort::
    end
    out:write("\n")
end


main()

