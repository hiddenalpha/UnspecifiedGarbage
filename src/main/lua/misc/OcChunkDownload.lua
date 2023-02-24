
local SL = require("scriptlee")
local async = SL.reactor.async
local newShellcmd = SL.newShellcmd
local newTarParser = SL.newTarParser
local objectSeal = SL.objectSeal
local sleep = SL.posix.sleep
local startOrExecute = SL.reactor.startOrExecute
SL = nil

local src, dst, log = io.stdin, io.stdout, io.stderr
local mod = {}


function mod.printHelp()
    dst:write("\n"
        .."  Sometimes I need to produce data on remote systems that exceeds\n"
        .."  available disk quotas. This tool helps to circumvent this limitation.\n"
        .."\n"
        .."  We can produce our (too large) data to incremental files chunk by\n"
        .."  chunk on the remote. Then we can instruct this tool here, to\n"
        .."  periodically scan that directory for new chunks. Then the tool will\n"
        .."  download those chunk files to our local drive and delete it on remote\n"
        .."  so we can stay within quota limits on remote and can collect data\n"
        .."  until our local disk fills up.\n"
        .."\n"
        .."  WARN: This tool is not stable! Its doings MUST be moniored.\n"
        .."\n"
        .."  Options:\n"
        .."\n"
        .."    --scan-delay <int>  (default 60)\n"
        .."      How many seconds to wait before doing another scan.\n"
        .."\n"
        .."    --workdir <str>  (default \"/tmp\")\n"
        .."      Working directory to use on REMOTE.\n"
        .."\n"
        .."    -n --namespace <str>\n"
        .."      Openshift namespace to use.\n"
        .."\n"
        .."    --pod-pattern <str>\n"
        .."      Pattern to select the POD to connect to. For pattern syntax see:\n"
        .."      https://www.lua.org/manual/5.4/manual.html#6.4.1\n"
        .."\n"
        .."    --file-pattern <str>\n"
        .."      Pattern to decide if a file within workdir should be downloaded.\n"
        .."      For pattern syntax see:\n"
        .."      https://www.lua.org/manual/5.4/manual.html#6.4.1\n"
        .."\n"
        .."    --skip <int>  (default 3)\n"
        .."      Most of the time it's a bad idea to download that file which\n"
        .."      currently is in construction. Same counts for the just completed\n"
        .."      file, which then for example gets compressed to a 3rd file. So\n"
        .."      the default is to NOT touch the most recent three files to\n"
        .."      prevent corrupt files.\n"
        .."\n")
end


function mod.parseArgs( app )
    --if #_ENV.arg == 0 then log:write("Args missing. Try --help\n") return -1 end
    app.scanDelaySec = 60
    app.remoteWorkdir = "/tmp"
    app.skipNewestCnt = 3
    local iA = 0
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; return 0
        elseif arg == "--scan-delay" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg or not arg:gmatch("^%d+$") then
                log:write("Arg --scan-delay needs integer") return -1 end
            app.scanDelaySec = tonumber(arg)
        elseif arg == "--workdir" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --workdir needs value") return -1 end
            app.remoteWorkdir = arg
        elseif arg == "-n" or arg == "--namespace" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --namespace needs value\n") return -1 end
            app.ocNamespace = arg
        elseif arg == "--pod-pattern" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --pod-pattern needs value\n") return -1 end
            app.podPattern = arg
        elseif arg == "--file-pattern" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --file-pattern needs value\n") return -1 end
            app.filePattern = arg
        elseif arg == "--skip" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg:find("^%d+$") then log:write("Arg --skip needs integer\n") return -1 end
            app.skipNewestCnt = tonumber(arg)
        else
            log:write("Unexpected arg: ".. arg .."\n")
            return -1
        end
    end
    if not app.ocNamespace then log:write("Arg --namespace missing\n") return -1 end
    if not app.podPattern then log:write("Arg --pod-pattern missing\n") return -1 end
    if not app.filePattern then log:write("Arg --file-pattern missing\n") return -1 end
    return 0
end


-- @param pattrn
--      LuaPattern to identify the services. Eg: "nginx%-[0-9]"
-- @return
--      List<String> of matching pod names.
function mod.findPodNames( app, pattrn )
    local cmdLine = mod.getOcCmd(app).." get pods"
    local stdoutBuf = ""
    local ocGetPods = newShellcmd{
        cmd = cmdLine,
        onStdout = function( buf )
            if buf then stdoutBuf = stdoutBuf .. buf end
            if #stdoutBuf > 42000000 then error("Input surprisingly large") end
        end,
    }
    ocGetPods:start()
    ocGetPods:closeSnk()
    local exitCode, signal
    while true do
        local exit, signal = ocGetPods:join(5)
        if exit == 0 then break end
        if exit or signal then
            error("exit="..tostring(exit).."/signal="..tostring(signal)..": ".. cmdLine)
        end
        log:write("[INFO ] Waiting for pod listing ...\n")
    end
    local retval = {}
    for podName in stdoutBuf:gmatch("([^ ]+) [^\n]+\n") do
        if podName:find(pattrn) then
            table.insert(retval, podName)
        end
    end
    return retval
end


function mod.getLsOutputFromRemote( app )
    local cmdLine = mod.getOcCmd(app)
        ..' exec -i "'.. app.podName ..'" -- sh -c "cd \"'..(app.remoteWorkdir)..'\" && ls -A1'
    local ls = objectSeal{
        base = false,
        stdoutChunks = {}
    }
    ls.base = newShellcmd{
        cls = ls,
        cmd = cmdLine,
        onStdout = function( buf, ls )
            if buf then table.insert(ls.stdoutChunks, buf) end
        end,
    }
    ls.base:start()
    ls.base:closeSnk()
    while true do
        local exit, signal = ls.base:join(5)
        if exit == 0 then break end
        if exit or signal then
            error("exit="..tostring(exit)"/signal="..tostring(signal)..": ".. tostring(cmdLine))
        end
        log:write("[INFO ] Waiting for remote dir listing ...\n")
    end
    return (table.concat(ls.stdoutChunks))
end


function mod.extractFilesOfInterestFromLsOutput( app, lsStdout )
    assert(type(lsStdout) == "string")
    local dirEntries = {}
    for dirent in lsStdout:gmatch("([^\n]+)\n") do
        if dirent:find(app.filePattern) then
            table.insert(dirEntries, dirent)
        end
    end
    return dirEntries
end


-- WARN this deletes the remote file immediately after download.
function mod.downloadFile( app, filename )
    assert(not filename:find("/"), "Only files directly in workdir allowed")
    assert(not filename:find("[\"*$`]+"), "filename cannot contain dblquot, asterisk, dollar"
        .." or backtick: ".. filename)
    local tarConsumer = objectSeal{
        parser = false, fd = false, isDone = false,
    }
    tarConsumer.parser = newTarParser{
        cls = tarConsumer,
        onTarHeader = function( hdr, tarConsumer )
            assert(not tarConsumer.fd, "Only ONE entry in tar expected")
            assert(not hdr.filename:find("/"), "Unexpected slash in tar entry filename")
            tarConsumer.fd = io.open(hdr.filename, "wb")
        end,
        onBodyChunk = function( buf, tarConsumer )  tarConsumer.fd:write(buf)  end,
        onEnd = function( tarConsumer )
            tarConsumer.isDone = true
            if tarConsumer.fd then tarConsumer.fd:close()end
        end,
    }
    assert(not app.remoteWorkdir:find('["\']'), "workdir must not contain dblquote nor snglequote")
    local tarProducerCmdLine = mod.getOcCmd(app) ..' exec -i "'.. app.podName ..'" -- sh -c "'
            ..' cd \''..(app.remoteWorkdir) ..'\''
            ..' && tar c \''.. filename ..'\''
            ..' && rm \''.. filename ..'\''
            ..'"'
    local tarProducer = newShellcmd{
        cmd = tarProducerCmdLine,
        cls = tarConsumer,
        onStdout = function( buf, tarConsumer )
            if buf then tarConsumer.parser:write(buf)
            else tarConsumer.parser:closeSnk() end
        end,
    }
    tarProducer:start()
    tarProducer:closeSnk()
    while true do
        local exit, signal = tarProducer:join(5)
        if exit == 0 then break end
        if exit or signal then
            error("exit="..tostring(exit)..", signal="..tostring(signal)..": ".. tarProducerCmdLine)
        end
        log:write("[INFO ] Waiting for download to complete ...\n")
    end
    -- TODO replace by pthread_condition (aka newCond)
    while not tarConsumer.isDone do sleep(0.01) end
end


function mod.downloadReadyChunks( app )
    assert(not app.remoteWorkdir:find('"'), "Workdir cannot contain dblquotes")
    log:write("[INFO ] Scan ".. app.podName .." '".. app.remoteWorkdir .."'"
        .."  ("..(os.date("%Y-%m-%d_%H:%M:%S"))..")\n")
    local lsStdout = mod.getLsOutputFromRemote(app)
    local dirEntries = mod.extractFilesOfInterestFromLsOutput(app, lsStdout)
    -- drop latest 3 elems, bcause there can be "current", "previous",
    -- "inCompression" files which are half-done and NOT YET READY FOR US.
    table.sort(dirEntries)
    for i=1, app.skipNewestCnt do table.remove(dirEntries) end
    for _, filename in ipairs(dirEntries) do
        log:write("[INFO ] Downloading '".. filename .."'\n")
        mod.downloadFile(app, filename)
    end
    if #dirEntries > 0 then log:write("[INFO ] Downloads completed\n") end
end


function mod.evalPodname( app )
    local podNames = mod.findPodNames(app, app.podPattern)
    if #podNames ~= 1 then
        for _, v in ipairs(podNames) do log:write("[ERROR] podname match: "..v.."\n") end
        error("Expected to match ONE podName but got "..#podNames)
    end
    app.podName = assert(podNames[1])
end


function mod.run( app )
    mod.evalPodname(app)
    while true do
        mod.downloadReadyChunks(app)
        sleep(app.scanDelaySec)
    end
end


-- Assembles the "oc" command. Including global args like namespace etc.
function mod.getOcCmd( app )
    local cmd = "oc"
    if app.ocNamespace then cmd = cmd .." -n ".. app.ocNamespace end
    return cmd
end


function mod.main()
    local app = objectSeal{
        isHelp = false,
        ocNamespace = false,
        scanDelaySec = false,
        podPattern = false,
        filePattern = false,
        filePattern = false,
        podName = false,
        remoteWorkdir = false,
        skipNewestCnt = false,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp() return end
    mod.run(app)
end


startOrExecute(nil, mod.main)
