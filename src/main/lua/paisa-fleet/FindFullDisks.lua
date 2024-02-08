
local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
local newShellcmd = SL.newShellcmd
local newSqlite = SL.newSqlite
local objectSeal = SL.objectSeal
local parseJSON = SL.parseJSON
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
        .."      --sshPort <int>         (eg 22)\n"
        .."      --sshUser <str>         (eg \"eddieuser\")\n"
        .."      --state <path>          (eg \"path/to/state\")\n"
        .."  \n")
end


function parseArgs( app )
    app.backendPort = 80
    app.sshPort = 22
    app.sshUser = os.getenv("USERNAME") or false
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
    else
        log:write("EINVAL: ".. arg .."\n")return
    end
    goto nextArg
    ::verifyResult::
    if not app.backendHost then log:write("EINVAL: --backendHost missing\n")return end
    if not app.sshUser then log:write("EINVAL: --sshUser missing")return end
    return 0
end


function getStateDb(app)
    if not app.stateDb then
        local db = newSqlite{ database = assert(app.statePath) }
        -- TODO normalize scheme
        db:prepare("CREATE TABLE IF NOT EXISTS DeviceDfLog(\n"
            .."  id INTEGER PRIMARY KEY,\n"
            .."  \"when\" TEXT NOT NULL,\n" -- "https://xkcd.com/1179"
            .."  hostname TEXT NOT NULL,\n"
            .."  eddieName TEXT NOT NULL,\n"
            .."  rootPartitionUsedPercent INT,\n"
            .."  varLibDockerUsedPercent INT,\n"
            .."  varLogUsedPercent INT,\n"
            .."  dataUsedPercent INT,\n"
            .."  stderr TEXT NOT NULL,\n"
            .."  stdout TEXT NOT NULL)\n"
            ..";"):execute()
        app.stateDb = db
    end
    return app.stateDb
end


function storeDiskFullResult( app, hostname, eddieName, stderrBuf, stdoutBuf )
    assert(app and hostname and eddieName and stderrBuf and stdoutBuf);
    local rootPartitionUsedPercent = stdoutBuf:match("\n/[^ ]+ +%d+ +%d+ +%d+ +(%d+)%% /\n")
    local varLibDockerUsedPercent = stdoutBuf:match("\n[^ ]+ +%d+ +%d+ +%d+ +(%d+)%% /var/lib/docker\n")
    local dataUsedPercent = stdoutBuf:match("\n[^ ]+ +%d+ +%d+ +%d+ +(%d+)%% /data\n")
    local varLogUsedPercent = stdoutBuf:match("\n[^ ]+ +%d+ +%d+ +%d+ +(%d+)%% /var/log\n")
    local stmt = getStateDb(app):prepare("INSERT INTO DeviceDfLog("
        .."  \"when\", hostname, eddieName, stderr, stdout,"
        .."  rootPartitionUsedPercent, dataUsedPercent, varLibDockerUsedPercent, varLogUsedPercent, dataUsedPercent"
        ..")VALUES("
        .."  $when, $hostname, $eddieName, $stderr, $stdout,"
        .." $rootPartitionUsedPercent, $dataUsedPercent, $varLibDockerUsedPercent, $varLogUsedPercent, $dataUsedPercent);")
    stmt:bind("$when", os.date("!%Y-%m-%dT%H:%M:%SZ"))
    stmt:bind("$hostname", hostname)
    stmt:bind("$eddieName", eddieName)
    stmt:bind("$stderr", stderrBuf)
    stmt:bind("$stdout", stdoutBuf)
    stmt:bind("$rootPartitionUsedPercent", rootPartitionUsedPercent)
    stmt:bind("$varLibDockerUsedPercent", varLibDockerUsedPercent)
    stmt:bind("$varLogUsedPercent", varLogUsedPercent)
    stmt:bind("$dataUsedPercent", dataUsedPercent)
    stmt:execute()
end


function doWhateverWithDevices( app )
    for k, dev in pairs(app.devices) do
        log:write("[INFO ] Inspecting '".. dev.hostname .."' (@ ".. dev.eddieName ..") ...\n")
        local fookCmd = "true"
            .." && HOSTNAME=$(hostname|sed 's_.isa.localdomain__')"
            .." && STAGE=$PAISA_ENV"
            .." && printf \"remoteHostname=$HOSTNAME, remoteStage=$STAGE\\n\""
            -- on some machine, df failed with "Stale file handle" But I want to continue
            -- with next device regardless of such errors.
            .." && df || true"
        local eddieCmd = "true"
            .." && HOSTNAME=$(hostname|sed 's_.pnet.ch__')"
            .." && STAGE=$PAISA_ENV"
            .." && printf \"remoteEddieName=$HOSTNAME, remoteStage=$STAGE\\n\""
            .." && if test \"${HOSTNAME}\" != \"".. dev.eddieName .."\"; then true"
            .."     && echo wrong host. Want ".. dev.eddieName .." found $HOSTNAME && false"
            .."     ;fi"
            .." && ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
            .." -p".. app.sshPort .." ".. app.sshUser .."@".. ((dev.type == "FOOK")and"fook"or dev.hostname)
            .." \\\n    --"
            .." sh -c 'true && ".. fookCmd:gsub("'", "'\"'\"'") .."'"
        local localCmd = assert(os.getenv("SSH_EXE"), "environ.SSH_EXE missing")
            .." -oRemoteCommand=none -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
            .." -p".. app.sshPort .." ".. app.sshUser .."@".. dev.eddieName ..""
            .." \\\n    --"
            .." sh -c 'true && ".. eddieCmd:gsub("'", "'\"'\"'") .."'"
        -- TODO get rid of this ugly use-tmp-file-as-script workaround
        local tmpPath = assert(os.getenv("TMP"), "environ.TMP missing"):gsub("\\", "/") .."/b30589uj30oahujotehuj.sh"
        --log:write("[DEBUG] tmpPath '".. tmpPath .."'\n")
        local tmpFile = assert(io.open(tmpPath, "wb"), "Failed to open '".. tmpPath .."'")
        tmpFile:write("#!/bin/sh\n".. localCmd .."\n")
        tmpFile:close()
        --log:write("[DEBUG] tmpPath ".. tmpPath .."\n")
        -- EndOf kludge
        local cmd = objectSeal{
            base = false,
            stdoutBuf = {},
            stderrBuf = {},
        }
        cmd.base = newShellcmd{
            cls = cmd,
            cmdLine = "sh \"".. tmpPath .."\"",
            onStdout = function( buf, cmd ) table.insert(cmd.stdoutBuf, buf or"") end,
            onStderr = function( buf, cmd ) table.insert(cmd.stderrBuf, buf or"") end,
        }
        cmd.base:start()
        cmd.base:closeSnk()
        local exit, signal = cmd.base:join(17)
        cmd.stderrBuf = table.concat(cmd.stderrBuf)
        cmd.stdoutBuf = table.concat(cmd.stdoutBuf)
        if exit == 255 and signal ==  nil then
            log:write("[DEBUG] fd2: ".. cmd.stderrBuf:gsub("\n", "\n[DEBUG] fd2: "):gsub("\n%[DEBUG%] fd2: $", "") .."\n")
            goto nextDevice
        end
        log:write("[DEBUG] fd1: ".. cmd.stdoutBuf:gsub("\n", "\n[DEBUG] fd1: "):gsub("\n%[DEBUG%] fd1: $", "") .."\n")
        storeDiskFullResult(app, dev.hostname, dev.eddieName, cmd.stderrBuf, cmd.stdoutBuf)
        if exit ~= 0 or signal ~= nil then
            error("exit=".. tostring(exit)..", signal="..tostring(signal))
        end
        ::nextDevice::
    end
end


function sortDevicesMostRecentlySeenFirst( app )
    table.sort(app.devices, function(a, b) return a.lastSeen > b.lastSeen end)
end


-- Don't want to visit just seen devices over and over again. So drop devices
-- we've recently seen from our devices-to-visit list.
function dropDevicesRecentlySeen( app )
    -- Collect recently seen devices.
    local devicesToRemove = {}
    local st = getStateDb(app):prepare("SELECT hostname FROM DeviceDfLog WHERE \"when\" > $tresholdDate")
    st:bind("$tresholdDate", os.date("!%Y-%m-%dT%H:%M:%SZ", os.time()-42*3600))
    local rs = st:execute()
    while rs:next() do
        local hostname = rs:value(1)
        devicesToRemove[hostname] = true
    end
    -- Remove selected devices
    local numKeep, numDrop = 0, 0
    local iD = 0 while true do iD = iD + 1
        local device = app.devices[iD]
        if not device then break end
        if devicesToRemove[device.hostname] then
            --log:write("[DEBUG] Drop '".. device.hostname .."' (".. device.eddieName ..")\n")
            numDrop = numDrop + 1
            app.devices[iD] = app.devices[#app.devices]
            app.devices[#app.devices] = nil
            iD = iD - 1
        else
            --log:write("[DEBUG] Keep '".. device.hostname .."' (".. device.eddieName ..")\n")
            numKeep = numKeep + 1
        end
    end
    log:write("[INFO ] Of "..(numKeep+numDrop).." devices from state visit ".. numKeep
        .." and skip ".. numDrop .." (bcause seen recently)\n")
end


function fetchDevices( app )
    local req = objectSeal{
        base = false,
        method = "GET",
        uri = "/houston/vehicle/inventory/v1/info/devices",
        rspCode = false,
        rspBody = false,
        isDone = false,
    }
    req.base = app.http:request{
        cls = req, connectTimeoutMs = 3000,
        host = app.backendHost, port = app.backendPort,
        method = req.method, url = req.uri,
        onRspHdr = function( rspHdr, req )
            req.rspCode = rspHdr.status
            if rspHdr.status ~= 200 then
                log:write(".-----------------------------------------\n")
                log:write("| ".. req.method .." ".. req.uri .."\n")
                log:write("| Host: ".. app.backendHost ..":".. app.backendPort .."\n")
                log:write("+-----------------------------------------\n")
                log:write("|  ".. rspHdr.proto .." ".. rspHdr.status .." ".. rspHdr.phrase .."\n")
                for i,h in ipairs(rspHdr.headers) do log:write("|  ".. h[1] ..": ".. h[2] .."\n") end
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
    if req.rspCode ~= 200 then log:write("ERROR: Couldn't fetch devices\n")return end
    assert(not app.devices)
    app.devices = {}
    log:write("[DEBUG] rspBody.len is ".. req.rspBody:len() .."\n")
    --io.write(req.rspBody)io.write("\n")
    for iD, device in pairs(parseJSON(req.rspBody).devices) do
        --print("Wa", iD, device)
        --for k,v in pairs(device)do print("W",k,v)end
        -- TODO how to access 'device.type'?
        local hostname               , eddieName               , lastSeen
            = device.hostname:value(), device.eddieName:value(), device.lastSeen:value()
        local typ
        if false then
        elseif hostname:find("^eddie%d%d%d%d%d$") then
            typ = "EDDIE"
        elseif hostname:find("^fook%-[a-z0-9]+$") then
            typ = "FOOK"
        elseif hostname:find("^lunkwill%-[a-z0-9]+$") then
            typ = "LUNKWILL"
        elseif hostname:find("^fook$") then
            log:write("[WARN ] WTF?!? '"..hostname.."'\n")
            typ = false
        else error("TODO_359zh8i3wjho "..hostname) end
        table.insert(app.devices, objectSeal{
            hostname = hostname,
            eddieName = eddieName,
            type = typ,
            lastSeen = lastSeen,
        })
    end
    log:write("[INFO ] Fetched ".. #app.devices .." devices.\n")
end


function run( app )
    fetchDevices(app)
    dropDevicesRecentlySeen(app)
    --sortDevicesMostRecentlySeenFirst(app)
    doWhateverWithDevices(app)
end


function main()
    local app = objectSeal{
        isHelp = false,
        backendHost = false,
        backendPort = false,
        sshPort = false,
        sshUser = false,
        statePath = false,
        stateDb = false,
        http = newHttpClient{},
        devices = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


startOrExecute(main)


