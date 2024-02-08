
local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
local newShellcmd = SL.newShellcmd
--local newSqlite = SL.newSqlite
local objectSeal = SL.objectSeal
local parseJSON = SL.parseJSON
--local sleep = SL.posix.sleep
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
    --app.statePath = ":memory:"
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
    --elseif arg == "--state" then
    --    iA = iA + 1; arg = _ENV.arg[iA]
    --    if not arg then log:write("EINVAL: --state needs value\n")return end
    --    app.statePath = arg
    else
        log:write("EINVAL: ".. arg .."\n")return
    end
    goto nextArg
    ::verifyResult::
    if not app.backendHost then log:write("EINVAL: --backendHost missing\n")return end
    return 0
end


function doWhateverWithDevices( app )
    for k, dev in pairs(app.devices) do
        if dev.eddieName ~= "eddie00003" or dev.type == "LUNKWILL" then
            log:write("[DEBUG] Skip '".. dev.eddieName .."'->'".. dev.hostname .."'\n")
            goto nextDevice
        end
        log:write("\n")
        log:write(" hostname "..tostring(dev.hostname).."\n")
        log:write("eddieName "..tostring(dev.eddieName).."\n")
        log:write("     type "..tostring(dev.type).."\n")
        log:write(" lastSeen "..tostring(dev.lastSeen).."\n")
        assert(dev.type == "FOOK")
        local cmd = objectSeal{
            base = false,
            cmdLine = false,
        }
        local fookCmd = "echo fook-says-hi && hostname"
        local eddieCmd = "ssh"
            .." -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -p7022 isa@fook"
            .." \\\n    --"
            .." sh -c 'true && ".. fookCmd:gsub("'", "'\"'\"'") .."'"
        local localCmd = assert(os.getenv("SSH_EXE"), "environ.SSH_EXE missing")
            .." -oRemoteCommand=none -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -p7022 isa@eddie00003"
            .." \\\n    --"
            .." sh -c 'true && ".. eddieCmd:gsub("'", "'\"'\"'") .."'"
        do
            -- TODO get rid of use-tmp-file-as-script workaround
            local tmpPath = assert(os.getenv("TMP")) .."/b30589uj30oahujotehuj.sh"
            log:write("[DEBUG] tmpPath '".. tmpPath .."'\n")
            local tmpFile = assert(io.open(tmpPath, "wb"), "Failed to open '".. tmpPath .."'")
            tmpFile:write("#!/bin/sh\n".. localCmd .."\n")
            tmpFile:close()
            error("TODO_238hu38h")
        end
        cmd.cmdLine = localCmd
        local okMarker = "OK_".. math.random(1000000,9999999) .."q958zhug3ojhat"
        --cmd.cmdLine = cmd.cmdLine .." -- true"
        --    .." && echo hostname=$(hostname|sed s_.pnet.ch__)"
        --    .." && echo stage=$PAISA_ENV"
        --    .." && whoami"
        --    .." && echo ".. assert(okMarker) ..""
        log:write("[DEBUG] ".. cmd.cmdLine .."\n")
        cmd.base = newShellcmd{
            cls = cmd,
            cmdLine = cmd.cmdLine,
            onStdout = function( buf, cmd ) io.write(buf or"")end,
            --onStderr = function( buf, cmd )end,
        }
        cmd.base:start()
        cmd.base:closeSnk()
        local exit, signal = cmd.base:join(7)
        if exit ~= 0 or signal ~= nil then
            error(tostring(exit).." "..tostring(signal))
        end
        error("TODO_938thu")
        ::nextDevice::
    end
end


function sortDevicesMostRecentlySeenFirst( app )
    table.sort(app.devices, function(a, b) return a.lastSeen > b.lastSeen end)
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
    if req.rspCode ~= 200 then log:write("ERROR: Couldn't fetch devices\n")return end
    assert(not app.devices)
    app.devices = {}
    --io.write(req.rspBody)io.write("\n")
    for iD, device in pairs(parseJSON(req.rspBody).devices) do
        print("Wa", iD, device)
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
end


function run( app )
    fetchDevices(app)
    sortDevicesMostRecentlySeenFirst(app)
    doWhateverWithDevices(app)
    error("TODO_a8uaehjgae9o8it")
end


function main()
    local app = objectSeal{
        isHelp = false,
        backendHost = false,
        backendPort = false,
        sshPort = false,
        sshUser = false,
--        statePath = false,
--        stateDb = false,
        http = newHttpClient{},
        devices = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


startOrExecute(main)


