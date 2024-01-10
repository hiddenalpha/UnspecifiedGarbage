
local newLogParser = require("PaisaLogParser").newLogParser

local inn, out, log = io.stdin, io.stdout, io.stderr

local main, printHelp, parseArgs, run, onLogEntry, printStats


function printHelp( app )
    io.stdout:write("  \n"
        .."  TODO write help page\n"
        .."  \n")
end


function parseArgs( app )
    local arg = _ENV.arg[1]
    if arg == "--help" then app.isHelp = true return 0 end
    if arg ~= "--yolo" then log:write("EINVAL\n")return end
    return 0
end


function onLogEntry( entry, app )
    local isTheEntryWeReSearching = false
        -- HOT!
        --or (entry.file == "ContextImpl" and entry.msg:find("IllegalStateException: null"))
        -- HOT!
        or (entry.file == "HttpHeaderUtil" and entry.msg:find("Keep.Alive. values do not match timeout.42 .. timeout.120 for request "))
        -- HOT!
        --or (entry.msg:find("timetable"))
        -- nope
        --or (entry.file == "ContextImpl" and entry.msg:find("IllegalStateException: You must set the Content%-Length header"))
        -- nope
        --or (entry.file == "LocalHttpServerResponse" and entry.msg:find("non-proper HttpServerResponse occured", 0, true))
        -- TODO
    local instantKey = entry.date
    local instant = app.instants[instantKey]
    if not instant then
        instant = {
            date = entry.date,
            count = 0,
        }
        app.instants[instantKey] = instant
    end
    if isTheEntryWeReSearching then
        instant.count = instant.count + 1
    end
end


function printStats( app )
    -- Arrange data
    local numGroups = 0
    local groupSet = {}
    local countMax = 1
    for date, instant in pairs(app.instants) do
        assert(date == instant.date)
        local key = date:sub(1, 15)
        local group = groupSet[key]
        if not group then
            numGroups = numGroups + 1
            group = { key = key, date = date, count = 0, }
            groupSet[key] = group
        end
        group.count = group.count + instant.count
        if countMax < group.count then countMax = group.count end
    end
    local groupArr = {}
    for _, group in pairs(groupSet) do
        table.insert(groupArr, group)
    end
    table.sort(groupArr, function( a, b )return a.key < b.key end)
    -- Plot
    out:write("\n")
    out:write(string.format("    Splitted into %9d groups\n", numGroups))
    out:write(string.format("       Peak value %9d num log entries\n", countMax))
    out:write("\n")
    local fullBar = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    for _, group in pairs(groupArr) do
        out:write(string.format("%s... |", group.key))
        local len = math.floor(group.count / countMax * fullBar:len())
        out:write(fullBar:sub(1, len))
        out:write("\n")
    end
end


function run( app )
    app.logParser = newLogParser{
        cls = app,
        patternV1 = "DATE STAGE SERVICE LEVEL FILE - MSG",
        onLogEntry = onLogEntry,
    }
    app.logParser:tryParseLogs()
    printStats(app)
end


function main()
    local app = {
        isHelp = false,
        logParser = false,
        instants = {},
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


main()
