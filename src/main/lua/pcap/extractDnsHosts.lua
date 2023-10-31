
local newPcapParser = assert(require("pcapit").newPcapParser)
local out, log = io.stdout, io.stderr

local main, onPcapFrame, vapourizeUrlVariables, printResult


function main()
    local app = {
        parser = false,
        youngestEpochSec = -math.huge,
        oldestEpochSec = math.huge,
        dnsResponses = {},
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
    local sec, usec = it:frameArrivalTime()
    sec = sec + (usec/1e6)
    if sec < app.oldestEpochSec then app.oldestEpochSec = sec end
    if sec > app.youngestEpochSec then app.youngestEpochSec = sec end
    --
    if it:trspSrcPort() == 53 then
        extractHostnameFromDns(app, it)
    elseif it:tcpSeqNr() then
        extractHostnameFromHttpHeaders(app, it)
    end
end


function extractHostnameFromDns( app, it )
    local payload = it:trspPayload()
    local bug = 8 -- TODO looks as lib has a bug and payload is offset by some bytes.
    local dnsFlags = (payload:byte(bug+3) << 8) | (payload:byte(bug+4))
    if (dnsFlags & 0x0004) ~= 0 then return end -- ignore error responses
    local numQuestions = payload:byte(bug+5) << 8 | payload:byte(bug+6)
    local numAnswers = payload:byte(bug+7) << 8 | payload:byte(bug+8)
    if numQuestions ~= 1 then
        log:write("[WARN ] numQuestions ".. numQuestions .."?!?\n")
        return
    end
    if numAnswers == 0 then return end -- empty answers are boring
    if numAnswers ~= 1 then log:write("[WARN ] dns.count.answers ".. numAnswers .." not supported\n") return end
    local questionsOffset = bug+13
    local hostname = payload:match("^([^\0]+)", questionsOffset)
    hostname = hostname:gsub("^[\r\n]", "") -- TODO WTF?!?
    hostname = hostname:gsub("[\x04\x02]", ".") -- TODO WTF?!?
    local answersOffset = bug + 13 + (24 * numQuestions)
    local ttl = payload:byte(answersOffset+6) << 24 | payload:byte(answersOffset+7) << 16
        | payload:byte(answersOffset+8) << 8 | payload:byte(answersOffset+9)
    local dataLen = payload:byte(answersOffset+10) | payload:byte(answersOffset+11)
    if dataLen ~= 4 then log:write("[WARN ] dns.resp.len ".. dataLen .." not impl\n") return end
    local ipv4Str = string.format("%d.%d.%d.%d", payload:byte(answersOffset+12), payload:byte(answersOffset+13),
        payload:byte(answersOffset+14), payload:byte(answersOffset+15))
    --
    addEntry(app, ipv4Str, hostname, ttl)
end


function extractHostnameFromHttpHeaders( app, it )
    local payload = it:trspPayload()
    local _, beg = payload:find("^([A-Z]+ [^ \r\n]+ HTTP/1%.%d\r?\n)")
    if not beg then return end
    beg = beg + 1
    local httpHost
    while true do
        local line
        local f, t = payload:find("^([^\r\n]+)\r?\n",  beg)
        if not f then return end
        if not payload:byte(1) == 0x72 or payload:byte(1) == 0x68 then goto nextHdr end
        line = payload:sub(f, t)
        httpHost = line:match("^[Hh][Oo][Ss][Tt]:%s*([^\r\n]+)\r?\n$")
        if not httpHost then goto nextHdr end
        break
        ::nextHdr::
        beg = t
    end
    httpHost = httpHost:gsub("^(.+):%d+$", "%1")
    local dstIp = it:netDstIpStr()
    if dstIp == httpHost then return end
    addEntry(app, dstIp, httpHost, false, "via http host header")
end


function addEntry( app, ipv4Str, hostname, ttl, kludge )
    local key
    --log:write("addEntry(app, ".. ipv4Str ..", ".. hostname ..")\n")
    if kludge == "via http host header" then
        key = ipv4Str .."\0".. hostname .."\0".. "via http host header"
    else
        key = ipv4Str .."\0".. hostname .."\0".. ttl
    end
    local entry = app.dnsResponses[key]
    if not entry then
        entry = { ipv4Str = ipv4Str, hostname = hostname, ttl = ttl, }
        app.dnsResponses[key] = entry
    end
end


function printResult( app )
    local sorted = {}
    for _, stream in pairs(app.dnsResponses) do
        table.insert(sorted, stream)
    end
    table.sort(sorted, function(a, b)
        if a.ipv4Str < b.ipv4Str then return true end
        if a.ipv4Str > b.ipv4Str then return false end
        return a.hostname < b.hostname
    end)
    local dumpDurationSec = app.youngestEpochSec - app.oldestEpochSec
    local timeFmt = "!%Y-%m-%d_%H:%M:%SZ"
    out:write("\n")
    out:write(string.format("#  Subject  Hostname to IP addresses\n"))
    out:write(string.format("#    Begin  %s\n", os.date(timeFmt, math.floor(app.oldestEpochSec))))
    out:write(string.format("# Duration  %.3f seconds\n", dumpDurationSec))
    out:write("\n")
    --out:write("   .-- KiB per Second\n")
    --out:write("   |            .-- IP endpoints\n")
    --out:write("   |            |                          .-- TCP server port\n")
    --out:write("   |            |                          |       .-- TCP Payload (less is better)\n")
    --out:write("   |            |                          |       |\n")
    --out:write(".--+----.  .----+----------------------.  .+--.  .-+------------\n")
    for i, elem in ipairs(sorted) do
        local ipv4Str, hostname, ttl = elem.ipv4Str, elem.hostname, elem.ttl
        if ttl then
            out:write(string.format("%-14s %-30s # TTL=%ds", ipv4Str, hostname, ttl))
        else
            out:write(string.format("%-14s %-30s # ", ipv4Str, hostname))
        end
        out:write("\n")
    end
    out:write("\n")
end


main()


