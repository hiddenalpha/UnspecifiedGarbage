--[====================================================================[

  Initially created to list processed eddies with MasterdataCleanup
  FleetHelper around november 2022.

  Did work with  scriptlee  0.0.5-23-gc70b3c1-G

  ]====================================================================]


local newTarParser = require("scriptlee").newTarParser
local objectSeal = require("scriptlee").objectSeal
local startOrExecute = require("scriptlee").reactor.startOrExecute

local mod = {}
local stdinn, stdout, stdlog = io.stdin, io.stdout, io.stderr


function mod.printHelp()
    stdout:write("\n"
        .."  ThrowAway script to extract needed data from tar and throw it into\n"
        .."  a CSV.\n"
        .."\n"
        .."  Options:\n"
        .."\n"
        .."    --risky\n"
        .."      WARN: only use this if you know what you're doing.\n"
        .."\n")
end


function mod.parseArgs( app )
    local iA = 0
    local isRisky = false
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then break end
        if arg == "--help" then
            mod.printHelp() return -1
        elseif arg == "--risky" then
            isRisky = true
        else
            stdlog:write("Unexpected arg: "..arg.."\n") return-1
        end
    end
    if not isRisky then stdlog:write("Bad Args\n")return-1 end
    return 0
end


function mod.onTarHeader( hdr, app )
    local filename = hdr.filename
    app.currentFileName = hdr.filename
    --stdlog:write("tarENTRY: '".. hdr.filename .."'\n")
    local isFile = (hdr.link == 0x30)
    local isDir  = (hdr.link == 0x35)
    if not isFile and not isDir then error("Unexpected type "..tostring(hdr.link)) end
    local eddieName = filename:match("scripthost/eddies/([^/]+)/status$")
    app.eddieName = eddieName or false
    app.fileIsRelevant = (app.eddieName)
end


function mod.onTarBody( buf, app )
    if not app.fileIsRelevant then return end
    local eddieName = app.eddieName
    local isDone = buf:find('"status" *: *"DONE"')
    local isErro = not isDone and buf:find('"status" *: *"')
    if (isDone or isErro) and not app.isOutHdrWritten then
        app.isOutHdrWritten = true
        stdout:write("h\tCreated\t"..os.date("!%Y-%m-%d %H:%M:%S UTC").."\n")
        stdout:write("c\tstatus\teddieName\n")
    end
    if isDone then stdout:write("r\tDONE\t"..(eddieName).."\n") end
    if isErro then stdout:write("r\tERROR\t"..(eddieName).."\n") end
end


function mod.run( app )
    assert(not app.tarParser);
    app.tarParser = newTarParser{
        cls = app,
        onTarHeader = assert(mod.onTarHeader),
        onBodyChunk = assert(mod.onTarBody),
        --onEnd = assert(mod.onTarEnd),
    }
    while true do
        local buf = stdinn:read(65536)
        if not buf then break end
        app.tarParser:write(buf)
    end
    app.tarParser:closeSnk()
    stdout:write("t\tstatus\tOK\n")
end


function mod.main()
    local app = objectSeal{
        tarParser = false,
        currentFileName = false,
        isOutHdrWritten = false,
        fileIsRelevant = false,
        eddieName = false,
    }
    if mod.parseArgs() ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(nil, mod.main)
