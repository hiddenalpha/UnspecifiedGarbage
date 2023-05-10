
local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
local objectSeal = SL.objectSeal
local parseJSON = SL.parseJSON
local startOrExecute = SL.reactor.startOrExecute
SL = nil

local mod = {}
local inn, out, log = io.stdin, io.stdout, io.stderr


function mod.printHelp(app)
    io.stdout:write("  \n"
        .."  \n"
        .."  Fetches FleetHelper status and writes it as a CSV to stdout.\n"
        .."  \n"
        .."  Options:\n"
        .."  \n"
        .."    --helperPath <str>\n"
        .."      Name of the FleetHelper to download from.\n"
        --.."  \n"
        --.."    --yolo\n"
        --.."      Shut up, and just execute! Caller is happy to take any risk.\n"
        .."  \n")
end


function mod.parseArgs(app)
    local iA = 0
    app.helperPath = false
    --local isYolo = false
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; return 0
        elseif arg == "--helperPath" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --helperPath needs value\n")return-1 end
            app.helperPath = arg
        --elseif arg == "--yolo" then
        --    isYolo = true
        end
    end
    --if not isYolo then log:write("Bad args\n")return-1 end
    if not app.helperPath then log:write("Arg --helperPath missing\n")return-1 end
    return 0
end


function mod.getEddieList( app )
    local egg = objectSeal{
        httpRequest = false,
        app = app,
        path = app.helperPathPartOne .. app.helperPath .. app.helperPathPartThree,
        rspStatus = false,
        rspBody = "",
    }
    egg.httpRequest = app.http:request{
        cls = egg,
        host = app.houstonHost, port = app.houstonPort,
        method = "GET", url = egg.path,
        onRspHdr = function( rsp, egg )
            local app = egg.app
            egg.rspStatus = rsp.status
            if rsp.status ~= 200 then
                log:write("> GET ".. egg.path .."\n")
                error(rsp.proto .." ".. rsp.status .." ".. rsp.phrase .."\n")
            end
        end,
        onRspChunk = function( buf, egg )
            if egg.rspStatus ~= 200 then return end
            egg.rspBody = egg.rspBody .. buf
        end,
    }
    egg.httpRequest:closeSnk()
    local json = parseJSON(egg.rspBody)
    local eddieNames = {}
    for iE,eddieNode in ipairs(json.eddies) do
        local eddieName = string.match(eddieNode:value(), "^(t?eddie[0-9]+)/$")
        table.insert(eddieNames, eddieName)
    end
    return eddieNames
end


function mod.getEddieStatus( app, eddieName )
    local fue = objectSeal{
        httpRequest = false,
        app = app,
        path = app.helperPathPartOne .. app.helperPath .. app.helperPathPartThree
            .."/".. eddieName .."/status",
        rspStatus = false,
        rspBody = "",
    }
    fue.httpRequest = app.http:request{
        cls = fue,
        host = app.houstonHost, port = app.houstonPort,
        method = "GET", url = fue.path,
        onRspHdr = function( rsp, fue )
            local app = fue.app
            fue.rspStatus = rsp.status
            if rsp.status ~= 200 then
                log:write("> GET ".. fue.path .."\n")
                error(rsp.proto .." ".. rsp.status .." ".. rsp.phrase .."\n")
            end
        end,
        onRspChunk = function( buf, fue )
            if fue.rspStatus ~= 200 then log:write(buf) return end
            fue.rspBody = fue.rspBody .. buf
        end,
        onRspEnd = function( fue ) if fue.rspStatus ~= 200 then log:write("\n") end end,
    }
    fue.httpRequest:closeSnk()
    return fue.rspBody
end


function mod.run( app )
    local eddieNames = mod.getEddieList(app)
    for iE,eddieName in ipairs(eddieNames) do
        local json = mod.getEddieStatus(app, eddieName)
        assert(type(json) == "string")
        json = parseJSON(json)
        local timestamp, status, message = json.timestamp:value(), json.status:value(), json.message:value()
        assert(not string.find(eddieName, "[;\r\n]"), eddieName)
        assert(not string.find(timestamp, "[;\r\n]"), timestamp)
        assert(not string.find(status, "[;\r\n]"), status)
        out:write("r;".. eddieName ..";".. timestamp ..";".. status ..";\"".. message:gsub('"','""') .."\"\n")
    end
end


function mod.main()
    local app = objectSeal{
        isHelp = false,
        houstonHost = "127.0.0.1",
        houstonPort = 7013,
        helperPathPartOne = "/houston/data/lyricon/helper-state",
        helperPath = false,
        helperPathPartThree = "/scripthost/eddies",
        http = newHttpClient{},
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp() return end
    mod.run(app)
end


startOrExecute(nil, mod.main)
