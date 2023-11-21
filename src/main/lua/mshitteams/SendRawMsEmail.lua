
local SL = require("scriptlee")
--local newHttpClient = SL.newHttpClient
--local newShellcmd = SL.newShellcmd
--local objectSeal = SL.objectSeal
--local parseJSON = SL.parseJSON
--local sleep = SL.posix.sleep
--local newCond = SL.posix.newCond
--local async = SL.reactor.async
--local startOrExecute = SL.reactor.startOrExecute
--for k,v in pairs(SL)do print("SL",k,v)end os.exit(1)
SL = nil

local mod = {}
local inn, out, log = io.stdin, io.stdout, io.stderr


function mod.printHelp()
    out:write("  \n"
        .."  Options:\n"
        .."  \n"
        .."\n\n")
end


function mod.parseArgs( app )
    local isStdinn = false
    local iA = 0
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; return 0
        else
            log:write("Unknown arg: ".. arg .."\n") return-1
        end
    end
    if not isStdinn then log:write("Bad args\n")return-1 end
    return 0
end


function mod.run( app )
    error("TODO_20230608125925")
end


function mod.main()
    local app = objectSeal{
        isHelp = false,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp() return end
    mod.run(app)
end


startOrExecute(mod.main)

