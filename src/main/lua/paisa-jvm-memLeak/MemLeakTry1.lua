
local inn, out, log = io.stdin, io.stdout, io.stderr
local main, parseArgs, printHelp, run, runAsPipe, runWithStdinFilelist


function printHelp()
    io.stdout:write("  \n"
        .."  Try to get some useful data out of a 'smap' dump.\n"
        .."  \n"
        .."  Options:\n"
        .."  \n"
        .."      --yolo\n"
        .."          WARN: Only use if you know what you do.\n"
        .."  \n"
        .."      --stdin-filelist\n"
        .."          Read LF separated file list form stdin.\n"
        .."  \n")
end


function parseArgs( app )
    if #_ENV.arg == 0 then log:write("EINVAL: Try --help\n") return end
    app.isHelp = false
    local isYolo = false
    local iA = 0
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; return 0
        elseif arg == "--yolo" then
            isYolo = true
        elseif arg == "--date" then
            iA = iA + 1
            app.dateStr = _ENV.arg[iA]
            if not app.dateStr then log:write("EINVAL: --date needs value\n") return end
        elseif arg == "--stdin-filelist" then
            app.isStdinFilelist = true
        else
            log:write("EINVAL: ".. arg .."\n") return
        end
    end
    return 0
end


function runAsPipe( app )
    local iLine = 0
    if #app.whitelist > 0 then
        log:write("[INFO ] Filtering enabled\n")
    end
    local isHdrWritten = false
    while true do
        iLine = iLine + 1
        local buf = inn:read("l")
        if iLine == 1 then goto nextLine end
        --log:write("BUF: ".. buf .."\n")
        local addr, sz, perm, note = buf:match("^([%w]+) +(%d+[A-Za-z]?) ([^ ]+) +(.*)$")
        if not sz and buf:find("^ +total +%d+[KMGTPE]$") then break end
        if not sz then log:write("BUF: '"..tostring(buf).."'\n")error("TODO_20231103111415") end
        if sz:find("K$") then sz = sz:gsub("K$", "") * 1024 end
        if #app.whitelist > 0 then
            if not whitelist[addr] then goto nextLine end
        end
        if not isHdrWritten then
            isHdrWritten = true
            out:write("c; Addr             ;         Size ; Perm  ; Note         ; arg.date\n")
        end
        out:write(string.format("r; %s ; %12d ; %s ; %-12s ; %s\n", addr, sz, perm, note, (app.dateStr or"")))
        ::nextLine::
    end
end


function debugPrintRecursive( out, obj, prefix, isSubCall )
    local typ = type(obj)
    if false then
    elseif typ == "string" then
        out:write("\"") out:write((obj:gsub("\n", "\\n"):gsub("\r", "\\r"))) out:write("\"")
    elseif typ == "number" then
        out:write(obj)
    elseif typ == "nil" then
        out:write("nil")
    elseif typ == "table" then
        local subPrefix = (prefix)and(prefix.."  ")or("  ")
        for k, v in pairs(obj) do
            out:write("\n") out:write(prefix or "")
            debugPrintRecursive(out, k, prefix, true) out:write(": ")
            debugPrintRecursive(out, v, subPrefix, true)
        end
    else
        error(tostring(typ))
    end
    if not isSubCall then out:write("\n")end
end


function runWithStdinFilelist( app )
    while true do
        local srcFilePath = inn:read("l")
        if not srcFilePath then break end
        --log:write("[DEBUG] src file \"".. srcFilePath .."\"\n")
        local srcFile = io.open(srcFilePath, "rb")
        if not srcFile then error("fopen(\""..tostring(srcFilePath).."\")") end
        collectData(app, srcFile, srcFilePath)
    end
    removeUnchanged(app)
    printResult(app)
end


function collectData( app, src, timestamp )
    assert(src)
    assert(timestamp)
    local iLine = 0
    while true do
        iLine = iLine + 1
        local buf = src:read("l")
        if iLine == 1 then goto nextLine end
        local addr, sz, perm, note = buf:match("^([%w]+) +(%d+[A-Za-z]?) ([^ ]+) +(.*)$")
        if not sz and buf:find("^ +total +%d+[A-Za-z]?\r?$") then break end
        if not sz then log:write("[ERROR] BUF: '"..tostring(buf).."'\n")error("TODO_20231103111415") end
        if sz:find("K$") then sz = sz:gsub("K$", "") * 1024 end
        local addrObj = app.addrs[addr]
        if not addrObj then
            addrObj = { measures = {} }
            app.addrs[addr] = addrObj
        end
        local measure = { ts = timestamp, sz = sz, }
        assert(not addrObj.measures[timestamp])
        addrObj.measures[timestamp] = measure
        ::nextLine::
    end
end


function removeUnchanged( app )
    local addrsWhichHaveChanged = {}
    local knownSizes = {}
    for addr, addrObj in pairs(app.addrs) do
        for ts, measure in pairs(addrObj.measures) do
            local knownSizeKey = assert(addr)
            local knownSize = knownSizes[knownSizeKey]
            if not knownSize then
                knownSize = measure.sz;
                knownSizes[knownSizeKey] = knownSize
            elseif knownSize ~= measure.sz then
                addrsWhichHaveChanged[addr] = true
            end
        end
    end
    local newAddrs = {}
    for addr, addrObj in pairs(app.addrs) do
        if addrsWhichHaveChanged[addr] then
            newAddrs[addr] = addrObj
        end
    end
    app.addrs = newAddrs
end


function printResult( app )
    -- arrange data
    local addrSet, tsSet, szByAddrAndTs = {}, {}, {}
    for addr, addrObj in pairs(app.addrs) do
        local measures = assert(addrObj.measures)
        addrSet[addr] = true
        for ts, measure in pairs(measures) do
            assert(ts == measure.ts)
            local sz = measure.sz
            tsSet[ts] = true
            szByAddrAndTs[addr.."\0"..ts] = sz
        end
    end
    local addrArr, tsArr = {}, {}
    for k,v in pairs(addrSet)do table.insert(addrArr, k) end
    for k,v in pairs(tsSet)do table.insert(tsArr, k) end
    table.sort(addrArr, function( a, b )return a < b end)
    table.sort(tsArr, function( a, b )return a < b end)
    --
    out:write("c;file")
    for _, addr in ipairs(addrArr) do out:write(";".. addr) end
    out:write("\n")
    for iTs, ts in ipairs(tsArr) do
        out:write("r;".. filterTsForOutput(app, ts))
        for iAddr, addr in ipairs(addrArr) do
            local sz = szByAddrAndTs[assert(addr).."\0"..assert(ts)]
            out:write(";".. sz)
        end
        out:write("\n")
    end
end


function filterTsForOutput( app, ts )
    local y, mnth, d, h, min, sec = ts:match("^houston%-prod%-pmap%-(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)(%d%d).txt$")
    return "".. os.time{ year=y, month=mnth, day=d, hour=h, min=min, sec=sec, }
end


function sortedFromMap( map, smallerPredicate )
    if not smallerPredicate then smallerPredicate = function(a,b)return a.key < b.key end end
    local arr = {}
    for k, v in pairs(map) do table.insert(arr, {key=k, val=v}) end
    table.sort(arr, smallerPredicate)
    return arr
end


function run( app )
    if app.isStdinFilelist then
        runWithStdinFilelist(app)
    else
        runAsPipe(app)
    end
end


function main()
    local app = {
        isHelp = false,
        isStdinFilelist = false,
        addrs = {},
        whitelist = {
            --["00000000DEADBEAF"] = true,
        }
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


main()
