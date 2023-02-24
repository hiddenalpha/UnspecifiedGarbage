
local SL = require("scriptlee")
local newShellcmd = SL.newShellcmd
local objectSeal = SL.objectSeal
local sleep = SL.posix.sleep
local startOrExecute = SL.reactor.startOrExecute
SL = nil

local log = io.stderr
local mod = {}


function mod.printHelp()
    io.stdout:write("\n"
        .."  TODO write help page\n"
        .."\n"
        --.."  Options:\n"
        --.."\n"
        .."\n")
end


function mod.parseArgs( app )
    local iA = 0
    local isDoit = false
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            mod.printHelp() return -1
        elseif arg == "--doit" then -- TODO rm
            isDoit = true
        else
            log:write("Unexpected arg: "..tostring(arg).."\n") return -1
        end
    end
    if not isDoit then log:write("Bad Args\n") return -1 end
    return 0
end


function mod.dockerPs( app, host )
    local cmdLine = 'ssh "'.. host ..'" -- sh -c "true && docker ps'
        -- TODO also exclude "up 1-3 Hours"
        ..' | egrep -v \'(^CONTAINER ID |  About a minute ago  |  [0-9]+ minutes ago  |  42 seconds ago  )\'"'
    log:write("[INFO ] ".. cmdLine .."\n")
    local cmd = newShellcmd{
        cmd = cmdLine,
        onStdout = function( buf ) if buf then io.stdout:write(buf) end end,
    }
    cmd:start()
    cmd:closeSnk()
    while true do
        local exit, signal = cmd:join(3000)
        if exit == 0 then break end
        if exit then log:write(" exitCode="..tostring(exit)) end
        if signal then log:write(" signal="..tostring(signal)) end
        if exit or signal then log:write(": ".. cmdLine .."\n") return -1 end
        log:write("Waiting for cmd: ".. cmdLine .."\n")
    end
end


function mod.run( app )
    for _,host in pairs{"teddie01", "teddie05", "teddie06"} do
        mod.dockerPs(app, host)
    end
end


function mod.main()
    local app = objectSeal{}
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(nil, mod.main)
