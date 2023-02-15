
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


function mod.run( app )
    local cmd = newShellcmd{
        cmd = "printf 'guguseli\n'",
    }
    cmd:start()
    cmd:closeSnk()
    while true do
        local exit, signal = cmd:join(1000)
        log:write("exit:   "..tostring(exit).."\n")
        log:write("signal: "..tostring(signal).."\n")
        sleep(1)
    end
    log:write("TODO not impl yet\n")
end


function mod.main()
    local app = objectSeal{}
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(nil, mod.main)
