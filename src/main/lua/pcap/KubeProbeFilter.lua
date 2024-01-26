--
-- Try to extract kube-probe related requests.
--

local newPcapParser = assert(require("pcapit").newPcapParser)
local newPcapDumper = assert(require("pcapit").newPcapDumper)

local out, log = io.stdout, io.stderr
local main, onPcapFrame, vapourizeUrlVariables


function onPcapFrame( app, it )
    local srcPort, dstPort = it:trspSrcPort(), it:trspDstPort()
    local userAgent, reqUri
    --
    if dstPort ~= 7012 and srcPort ~= 7012 then return end
    local trspPayload = it:trspPayload()
    local httpReqLinePart1, httpReqLinePart2, httpReqLinePart3 =
        trspPayload:match("^([A-Z/1.0]+) ([^ ]+) ([^ \r\n]+)\r?\n")
    if httpReqLinePart1 and not httpReqLinePart1:find("^HTTP/1.%d$") then -- assume HTTP request
        reqUri = httpReqLinePart2
        userAgent = trspPayload:match("\n[Uu][Ss][Ee][Rr]%-[Aa][Gg][Ee][Nn][Tt]:%s+([^\r\n]+)\r?\n");
        if userAgent then
            --if not userAgent:find("^kube%-probe/") then return end -- assume halfrunt
            --log:write("User-Agent: ".. userAgent .."\n")
        end
    elseif httpReqLinePart1 then -- assume HTTP response
        --out:write(trspPayload)
    end
    local srcIp, dstIp = it:netSrcIpStr(), it:netDstIpStr()
    local connKey = ((srcPort < dstPort)and(srcPort.."\0"..dstPort)or(dstPort.."\0"..srcPort))
        .."\0"..((srcIp < dstIp)and(srcIp.."\0"..dstIp)or(dstIp.."\0"..srcIp))
    local conn = app.connections[connKey]
    if not conn then conn = {isOfInterest=false, pkgs={}} app.connections[connKey] = conn end
    conn.isOfInterest = (conn.isOfInterest or reqUri == "/houston/server/info")
    if not conn.isOfInterest then
        if #conn.pkgs > 3 then -- Throw away all stuff except TCP handshake
            conn.pkgs = { conn.pkgs[1], conn.pkgs[2], conn.pkgs[3] }
        end
        local sec, usec = it:frameArrivalTime()
        --for k,v in pairs(getmetatable(it))do print("E",k,v)end
        local pkg = {
            sec = assert(sec), usec = assert(usec),
            caplen = it:frameCaplen(), len = it:frameLen(),
            tcpFlags = (conn.isOfInterest)and(it:tcpFlags())or false,
            srcPort = srcPort, dstPort = dstPort,
            trspPayload = trspPayload,
            rawFrame = it:rawFrame(),
        }
        table.insert(conn.pkgs, pkg)
    else
        -- Stop memory hogging. Write that stuff to output
        if #conn.pkgs > 0 then
            for _, pkg in ipairs(conn.pkgs) do
                --out:write(string.format("-- PKG 1  %d->%d  %d.%09d tcpFlg=0x%04X\n", pkg.srcPort, pkg.dstPort, pkg.sec, pkg.usec, pkg.tcpFlags or 0))
                --out:write(pkg.trspPayload)
                --out:write("\n")
                app.dumper:dump(pkg.sec, pkg.usec, pkg.caplen, pkg.len, pkg.rawFrame, 1, pkg.rawFrame:len())
            end
            conn.pkgs = {}
        end
        local tcpFlags = it:tcpFlags()
        local sec, usec = it:frameArrivalTime()
        local rawFrame = it:rawFrame()
        --out:write(string.format("-- PKG 2  %d->%d  %d.%09d tcpFlg=0x%04X, len=%d\n", srcPort, dstPort, sec, usec, tcpFlags or 0, trspPayload:len()))
        --out:write(trspPayload)
        --if trspPayload:byte(trspPayload:len()) ~= 0x0A then out:write("\n") end
        --out:write("\n")
        app.dumper:dump(sec, usec, it:frameCaplen(), it:frameLen(), rawFrame, 1, rawFrame:len())
    end
end


function main()
    local app = {
        parser = false,
        dumper = false,
        connections = {},
    }
    app.parser = newPcapParser{
        dumpFilePath = "-",
        onFrame = function(f)onPcapFrame(app, f)end,
    }
    app.dumper = newPcapDumper{
        dumpFilePath = "C:/work/tmp/KubeProbeFilter.out.pcap",
    }
    app.parser:resume()
end


main()


