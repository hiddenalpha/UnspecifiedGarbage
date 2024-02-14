
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
        .."      \n"
        .."      --exportLatestStatus\n"
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
    elseif arg == "--exportLatestStatus" then
        app.exportLatestStatus = true
    else
        log:write("EINVAL: ".. arg .."\n")return
    end
    goto nextArg
    ::verifyResult::
    if app.exportLatestStatus then
        if not app.statePath then log:write("EINVAL: --state missing\n")return end
    else
        if not app.backendHost then log:write("EINVAL: --backendHost missing\n")return end
        if not app.backendPath then log:write("EINVAL: --backendPath missing\n")return end
        if app.backendPath:find("^C:.") then log:write("[WARN ] MSYS_NO_PATHCONV=1 likely missing? ".. app.backendPath.."\n") end
    end
    return 0
end


function removeCompletedEddies( app )
    local db = getStateDb(app)
    local rs = db:prepare("SELECT eddieName FROM Eddie"
        .."  JOIN EddieLog ON Eddie.id = eddieId"
        .."  WHERE status = \"OK\";"):execute()
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


function setEddieStatus( app, statusStr, eddieName, stderrStr, stdoutStr )
    assert(type(app) == "table")
    assert(type(eddieName) == "string")
    assert(statusStr == "OK" or statusStr == "ERROR")
    log:write("[DEBUG] setEddieStatus(".. eddieName ..", ".. statusStr ..")\n")
    local db = getStateDb(app)
    local stmt = db:prepare("INSERT INTO Eddie(eddieName)VALUES($eddieName);")
    stmt:bind("$eddieName", eddieName)
    local ok, emsg = xpcall(function()
        stmt:execute()
    end, debug.traceback)
    if not ok and not emsg:find("UNIQUE constraint failed: Eddie.eddieName") then
        error(emsg)
    end
    local stmt = db:prepare("INSERT INTO EddieLog('when',eddieId,status,stderr,stdout)"
        .."VALUES($when, (SELECT rowid FROM Eddie WHERE eddieName = $eddieName), $status, $stderr, $stdout)")
    stmt:reset()
    stmt:bind("$when", os.date("!%Y-%m-%dT%H:%M:%S+00:00"))
    stmt:bind("$eddieName", eddieName)
    stmt:bind("$status", statusStr)
    stmt:bind("$stderr", stderrStr)
    stmt:bind("$stdout", stdoutStr)
    stmt:execute()
end


function getStateDb( app )
    if not app.stateDb then
        app.stateDb = newSqlite{ database = app.statePath }
        app.stateDb:prepare("CREATE TABLE IF NOT EXISTS Eddie(\n"
            .."  id INTEGER PRIMARY KEY,\n"
            .."  eddieName TEXT UNIQUE NOT NULL)\n"
            ..";"):execute()
        app.stateDb:prepare("CREATE TABLE IF NOT EXISTS EddieLog(\n"
            .."  id INTEGER PRIMARY KEY,\n"
            .."  'when' TEXT NOT NULL,\n"
            .."  eddieId INT NOT NULL,\n"
            .."  status TEXT, -- OneOf OK, ERROR\n"
            .."  stderr TEXT NOT NULL,\n"
            .."  stdout TEXT NOT NULL)\n"
            ..";\n"):execute()
    end
    return app.stateDb
end


function loadEddies( app )
    local httpClient = newHttpClient{}
    local req = objectSeal{
        base = false,
        method = "GET",
        path = app.backendPath .."/data/preflux/inventory",
        rspCode = false,
        rspBody = false,
        isDone = false,
    }
    req.base = httpClient:request{
        cls = req,
        host = app.backendHost, port = app.backendPort,
        method = req.method, url = req.path,
        onRspHdr = function( rspHdr, req )
            req.rspCode = rspHdr.status
            if rspHdr.status ~= 200 then
                log:write(".-----------------------------------------\n")
                log:write("| ".. req.method .." ".. req.path .."\n")
                log:write("| Host: ".. app.backendHost ..":".. app.backendPort .."\n")
                log:write("+-----------------------------------------\n")
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
    if req.rspCode ~= 200 then log:write("ERROR: Couldn't load eddies\n")return end
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
    local ssh = "C:/Users/fankhauseand/.opt/gitPortable-2.27.0-x64/usr/bin/ssh.exe"
    local cmdLinePre = ssh .." -oConnectTimeout=3 -oRemoteCommand=none"
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
            .." -- \"true"
            ..    " && if test \"".. eddieName .."\" != \"$(hostname|sed 's,.pnet.ch$,,'); then true\""
            ..        " && echo WrongHost expected=".. eddieName .." actual=$(hostname|sed 's,.pnet.ch$,,') && false"
            ..        " ;fi"
            ..    " && echo hostname=$(hostname|sed 's,.pnet.ch,,')"
            ..    " && echo stage=${PAISA_ENV:?}"
            ..    " && echo Scan /data/instances/default/??ARTIFACT_BASE_DIR?"
            --[[report only]]
            --..    " && test -e /data/instances/default/??ARTIFACT_BASE_DIR? && ls -Ahl /data/instances/default/??ARTIFACT_BASE_DIR?"
            --[[Find un-/affected eddies]]
            ..    " && if test -e /data/instances/default/??ARTIFACT_BASE_DIR?; then true"
            ..        " ;else true"
            ..        " && echo ".. okMarker
            ..        " ;fi"
            --[[DELETE them]]
            --..    " && if test -e /data/instances/default/??ARTIFACT_BASE_DIR?; then true"
            --..        " && find /data/instances/default/??ARTIFACT_BASE_DIR? -type d -mtime +420 -print -delete"
            --..        " ;fi"
            --..    " && echo ".. okMarker ..""
            --[[]]
            ..    " \""
        log:write("\n")
        log:write("[INFO ] Try ".. eddieName .." ...\n")
        log:write("[DEBUG] ".. cmdLine.."\n")
        --log:write("[DEBUG] sleep ...\n")sleep(3)
        local isStdioDone, isSuccess, stderrStr, stdoutStr = false, false, "", ""
        local cmd = newShellcmd{
            cmdLine = cmdLine,
            onStdout = function( buf )
                if buf then
                    if buf:find("\n"..okMarker.."\n",0,true) then isSuccess = true end
                    stdoutStr = stdoutStr .. buf
                    io.stdout:write(buf)
                else isStdioDone = true end
            end,
            onStderr = function( buf )
                stderrStr = buf and stderrStr .. buf or stderrStr
                io.stderr:write(buf or"")
            end,
        }
        cmd:start()
        cmd:closeSnk()
        local exitCode, signal = cmd:join(42)
        if exitCode ~= 0 and signal ~= nil then
            log:write("[WARN ] code="..tostring(exitCode)..", signal="..tostring(signal).."\n")
        end
        while not isStdioDone do sleep(0.042) end
        -- Analyze outcome
        if not isSuccess then
            setEddieStatus(app, "ERROR", eddieName, stderrStr, stdoutStr)
            goto nextEddie
        end
        setEddieStatus(app, "OK", eddieName, stderrStr, stdoutStr)
        ::nextEddie::
    end
end


function sortEddiesMostRecentlySeenFirst( app )
    table.sort(app.eddies, function(a, b) return a.lastSeen > b.lastSeen end)
end


function quoteCsvVal( v )
    local typ = type(v)
    if false then
    elseif typ == "string" then
        if v:find("[\"\r\n]",0,false) then
            v = '"'.. v:gsub('"', '""') ..'"'
        end
    else error("TODO_a928rzuga98oirh "..typ)end
    return v
end


function exportLatestStatus( app )
    local snk = io.stdout
    local db = getStateDb(app)
    local stmt = db:prepare("SELECT \"when\",eddieName,status,stderr,stdout FROM EddieLog"
        .." JOIN Eddie ON Eddie.id = eddieId"
        .." ORDER BY eddieId,[when]"
        .." ;")
    rs = stmt:execute()
    snk:write("c;when;eddieName;status;stderr;stdout\n")
    local prevWhen, prevEddieName, prevStatus, prevStderr, prevStdout
    local qt = quoteCsvVal
    while rs:next() do
        local when       , eddieName  , status     , stderr     , stdout
            = rs:value(1), rs:value(2), rs:value(3), rs:value(4), rs:value(5)
          --log:write("[DEBUG] "..tostring(when).."  "..tostring(eddieName).."  "..tostring(status).."\n")
        assert(when and eddieName and status and stderr and stdout)
        if eddieName == prevEddieName then
            if not prevWhen or when > prevWhen then
                --log:write("[DEBUG] ".. when .."  ".. eddieName .."  take\n")
                goto assignPrevThenNextEntry
            else
                --log:write("[DEBUG] ".. when .."  ".. eddieName .."  obsolete\n")
                goto nextEntry
            end
        elseif prevEddieName then
            --log:write("[DEBUG] ".. when .."  ".. eddieName .."  Eddie complete\n")
            snk:write("r;".. qt(when) ..";".. qt(eddieName) ..";".. qt(status) ..";".. qt(stderr) ..";".. qt(stdout) .."\n")
        else
            --log:write("[DEBUG] ".. when .."  ".. eddieName .."  Another eddie\n")
            goto assignPrevThenNextEntry
        end
        ::assignPrevThenNextEntry::
        --[[]] prevWhen, prevEddieName, prevStatus, prevStderr, prevStdout
            =  when    , eddieName    , status    , stderr    , stdout
        ::nextEntry::
    end
    snk:write("t;status;OK\n")
end


function run( app )
    if app.exportLatestStatus then
        exportLatestStatus(app)
        return
    end
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
        exportLatestStatus = false,
        eddies = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


startOrExecute(main)

