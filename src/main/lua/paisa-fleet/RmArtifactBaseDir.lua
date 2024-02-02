
local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
local newShellcmd = SL.newShellcmd
local newSqlite = SL.newSqlite
local objectSeal = SL.objectSeal
local parseJSON = SL.parseJSON
local sleep = SL.posix.sleep
local startOrExecute = SL.reactor.startOrExecute
SL = nil
local log = io.stdout


function printHelp()
    io.write("\n"
        .."  WARN: This is experimental.\n"
        .."  \n"
        .."  Options:\n"
        .."      --backendHost <inaddr>  (eg \"localhost\")\n"
        .."      --backendPort <int>     (eg 80)\n"
        .."      --backendPath <str>     (eg \"/houston\")\n"
        .."      --sshPort <int>         (eg 22)\n"
        .."      --sshUser <str>         (eg \"eddieuser\")\n"
        .."      --state <path>          (eg \"path/to/state\")\n"
        .."  \n")
end


function parseArgs( app )
    app.backendPort = 80
    app.statePath = ":memory:"
    local iA = 0
    ::nextArg::
    iA = iA + 1
    local arg = _ENV.arg[iA]
    if not arg then
        goto verifyResult
    elseif arg == "--help" then
        app.isHelp = true return 0
    elseif arg == "--backendHost" then
        iA = iA + 1; arg = _ENV.arg[iA]
        if not arg then log:write("EINVAL: --backendHost needs value\n")return end
        app.backendHost = arg
    elseif arg == "--backendPort" then
        iA = iA + 1; arg = _ENV.arg[iA]
        if not arg then log:write("EINVAL: --backendPort needs value\n")return end
        app.backendHost = arg
    elseif arg == "--backendPath" then
        iA = iA + 1; arg = _ENV.arg[iA]
        if not arg then log:write("EINVAL: --backendPath needs value\n")return end
        app.backendPath = arg
    elseif arg == "--sshPort" then
        iA = iA + 1; arg = _ENV.arg[iA]
        if not arg then log:write("EINVAL: --sshPort needs value\n")return end
        app.sshPort = arg
    elseif arg == "--sshUser" then
        iA = iA + 1; arg = _ENV.arg[iA]
        if not arg then log:write("EINVAL: --sshUser needs value\n")return end
        app.sshUser = arg
    elseif arg == "--state" then
        iA = iA + 1; arg = _ENV.arg[iA]
        if not arg then log:write("EINVAL: --state needs value\n")return end
        app.statePath = arg
    end
    goto nextArg
    ::verifyResult::
    if not app.backendHost then log:write("EINVAL: --backendHost missing\n")return end
    if not app.backendPath then log:write("EINVAL: --backendPath missing\n")return end
    if app.backendPath:find("^C:.") then log:write("WARN: Path looks wrong: ".. app.backendPath.."\n") end
    return 0
end


function removeCompletedEddies( app )
    local db = getStateDb(app)
    local rs = db:prepare("SELECT eddieName FROM CompletedEddies;"):execute()
    local eddieNamesToRemoveSet = {}
    while rs:next() do
        assert(rs:type(1) == "TEXT", rs:type(1))
        assert(rs:name(1) == "eddieName", rs:name(1))
        local eddieName = rs:value(1)
        eddieNamesToRemoveSet[eddieName] = true
    end
    local oldEddies = app.eddies
    app.eddies = {}
    local numKeep, numDrop = 0, 0
    for _, eddie in pairs(oldEddies) do
        if not eddieNamesToRemoveSet[eddie.eddieName] then
            --log:write("[DEBUG] Keep '".. eddie.eddieName .."'\n")
            numKeep = numKeep + 1
            table.insert(app.eddies, eddie)
        else
            numDrop = numDrop + 1
            --log:write("[DEBUG] Drop '".. eddie.eddieName .."': Already done\n")
        end
    end
    log:write("[DEBUG] todo: ".. numKeep ..", done: ".. numDrop .."\n")
end


function markEddieDone( app, eddieName )
    assert(type(app) == "table")
    assert(type(eddieName) == "string")
    log:write("[DEBUG] markEddieDone(".. eddieName ..")\n")
    local db = getStateDb(app)
    local stmt = db:prepare("INSERT OR IGNORE INTO CompletedEddies(eddieName,doneAt)VALUES($eddieName, $now)")
    stmt:reset()
    stmt:bind("$eddieName", eddieName)
    stmt:bind("$now", os.date("!%Y-%m-%dT%H:%M:%S+00:00"))
    stmt:execute()
end


function getStateDb( app )
    if not app.stateDb then
        app.stateDb = newSqlite{ database = app.statePath }
        app.stateDb:prepare("CREATE TABLE IF NOT EXISTS CompletedEddies("
            .."  eddieName TEXT UNIQUE,"
            .."  doneAt TEXT);"):execute()
    end
    return app.stateDb
end


function loadEddies( app )
    local httpClient = newHttpClient{}
    local req = objectSeal{
        base = false,
        rspCode = false,
        rspBody = false,
        isDone = false,
    }
    req.base = httpClient:request{
        cls = req,
        host = app.backendHost, port = app.backendPort,
        method = "GET", url = app.backendPath .."/data/preflux/inventory",
        onRspHdr = function( rspHdr, req )
            req.rspCode = rspHdr.status
            if rspHdr.status ~= 200 then
                log:write(".-----------------------------------------\n")
                log:write("|  ".. rspHdr.proto .." ".. rspHdr.status .." ".. rspHdr.phrase .."\n")
                for i,h in ipairs(rspHdr.headers) do
                    log:write("|  ".. h[1] ..": ".. h[2] .."\n")
                end
                log:write("|  \n")
            end
        end,
        onRspChunk = function( buf, req )
            if req.rspCode ~= 200 then log:write("|  ".. buf:gsub("\n", "\n|  ")) return end
            if buf then
                if not req.rspBody then req.rspBody = buf
                else req.rspBody = req.rspBody .. buf end
            end
        end,
        onRspEnd = function( req )
            if req.rspCode ~= 200 then log:write("\n'-----------------------------------------\n") end
            req.isDone = true
        end,
    }
    req.base:closeSnk()
    assert(req.isDone)
    local prefluxInventory = parseJSON(req.rspBody)
    local eddies = {}
    for eddieName, detail in pairs(prefluxInventory.hosts) do
        table.insert(eddies, objectSeal{
            eddieName = eddieName,
            lastSeen = detail.lastSeen:value(),
        })
    end
    app.eddies = eddies
end


function makeWhateverWithEddies( app )
    local cmdLinePre = "ssh -oConnectTimeout=5"
    if app.sshPort then cmdLinePre = cmdLinePre .." -p".. app.sshPort end
    if app.sshUser then cmdLinePre = cmdLinePre .." \"-oUser=".. app.sshUser .."\"" end
    for k,eddie in pairs(app.eddies) do
        local eddieName = eddie.eddieName
        local isEddie = eddieName:find("^eddie%d%d%d%d%d$")
        local isTeddie = eddieName:find("^teddie%d%d$")
        local isVted = eddieName:find("^vted%d%d$")
        local isAws = eddieName:find("^10.117.%d+.%d+$")
        local isDevMachine = eddieName:find("^w00[a-z0-9][a-z0-9][a-z0-9]$")
        if isAws or isDevMachine or isVted then
            log:write("[DEBUG] Skip \"".. eddieName .."\"\n")
            goto nextEddie
        end
        assert(isEddie or isTeddie, eddieName or"nil")
        local okMarker = "OK_".. math.random(10000000, 99999999) .."wCAkgQQA2AJAzAIA"
        local cmdLine = cmdLinePre .." ".. eddieName
            -- report only
            --.." \"-oRemoteCommand=test -e /data/instances/default && ls -Ahl /data/instances/default\""
            -- DELETE them
            .." \"-oRemoteCommand=true"
            ..    " && if test -e /data/instances/default/\\${ARTIFACT_BASE_DIR}; then true"
            ..        " && find /data/instances/default/\\${ARTIFACT_BASE_DIR} -type d -mtime +420 -print -delete"
            ..        " ;fi"
            ..    " && echo ".. okMarker ..""
            ..    " \""
        log:write("\n[DEBUG] ".. cmdLine.."\n")
        log:write("[DEBUG] sleep ...\n")sleep(3)
        local isCmdDone, isSuccess = false, false
        local cmd = newShellcmd{
            cmdLine = cmdLine,
            onStdout = function( buf )
                if buf then
                    if buf:find("\n"..okMarker.."\n",0,true) then isSuccess = true end
                    io.stdout:write(buf)
                else isCmdDone = true end
            end,
        }
        cmd:start()
        cmd:closeSnk()
        local exitCode, signal = cmd:join(42)
        log:write("[DEBUG] code="..tostring(exitCode)..", signal="..tostring(signal).."\n")
        while not isCmdDone do sleep(0.042) end
        if not isSuccess then log:write("[WARN ] Failed on '"..eddieName.."'\n") goto nextEddie end
        markEddieDone(app, eddieName)
        ::nextEddie::
    end
end


function sortEddiesMostRecentlySeenFirst( app )
    table.sort(app.eddies, function(a, b) return a.lastSeen > b.lastSeen end)
end


function run( app )
    loadEddies(app)
    assert(app.eddies)
    removeCompletedEddies(app)
    sortEddiesMostRecentlySeenFirst(app)
    makeWhateverWithEddies(app)
end


function main()
    local app = objectSeal{
        isHelp = false,
        backendHost = false,
        backendPort = false,
        backendPath = false,
        sshPort = false,
        sshUser = false,
        statePath = false,
        stateDb = false,
        eddies = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


startOrExecute(main)

