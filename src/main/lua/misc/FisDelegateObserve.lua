
local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
local newShellcmd = SL.newShellcmd
local objectSeal = SL.objectSeal
local parseJSON = SL.parseJSON
local sleep = SL.posix.sleep
local startOrExecute = SL.reactor.startOrExecute
--for k,v in pairs(SL)do print("SL",k,v)end os.exit(1)
SL = nil

local mod = {}
local inn, out, log = io.stdin, io.stdout, io.stderr


function mod.printHelp()
    out:write("  \n"
        .."  Options:\n"
        .."  \n"
        .."    --stdin\n"
        .."      Read LF separated list of eddie names from stin.\n"
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
        elseif arg == "--stdin" then
            isStdinn = true
        else
            log:write("Unknown arg: ".. arg .."\n") return-1
        end
    end
    if not isStdinn then log:write("Bad args\n")return-1 end
    return 0
end


function mod.getDefinition( app, eddieName )
    local eddie = objectSeal{
        base = false,
        app = app,
        request = false,
        rspStatus = false,
        rspBody = "",
    }
    local ok, emsg = pcall(function()
        mod.assertHostIsCorrect(app, eddieName)
        eddie.request = app.http:request{
            cls = eddie,
            host = eddieName,  port = 7012,
            method = "GET", url = "/eagle/server/admin/v1/delegates/to-houston-forward-hooks/definition",
            onRspHdr = function( hdr, eddie )
                eddie.rspStatus = hdr.status
                if eddie.rspStatus ~= 200 then
                    log:write(eddieName ..": HTTP ".. eddie.rspStatus .."\n")
                end
            end,
            onRspChunk = function( buf, eddie )
                if eddie.rspStatus ~= 200 then
                    log:write(buf and buf or "\n")
                else
                    eddie.rspBody = eddie.rspBody .. (buf and buf or"")
                end
            end,
            onRspEnd = function( eddie ) end,
        }
    end)
    if not ok then
        -- Make message more userfriendly
        if emsg:find("^EAI_NONAME getaddrinfo()") or emsg:find("ETIMEDOUT connect%(\"") then
            emsg = "Offline" end
        return emsg
    end
    eddie.request:closeSnk()
    if eddie.rspStatus ~= 200 then
        return (eddie.emsg or "ERROR")
    end
    return nil, eddie.rspBody
end


function mod.assertHostIsCorrect( app, eddieName )
    local eddie = objectSeal{
        base = false,
        app = app,
        request = false,
        rspStatus = false,
        rspBody = "",
    }
    local url = "/eagle/server/info"
    eddie.request = app.http:request{
        cls = eddie,
        host = eddieName,  port = 7012, method = "GET", url = url,
        onRspHdr = function( hdr, eddie )
            eddie.rspStatus = hdr.status
            if eddie.rspStatus ~= 200 then
                log:write(eddieName ..": HTTP ".. eddie.rspStatus .."\n")
            end
        end,
        onRspChunk = function( buf, eddie )
            if eddie.rspStatus ~= 200 then
                log:write(buf and buf or "\n")
            else
                eddie.rspBody = eddie.rspBody .. (buf and buf or"")
            end
        end,
        onRspEnd = function( eddie )
            if eddie.rspStatus ~= 200 then error("HTTP "..tostring(eddie.rspStatus).." "..url) end
            local rspBody = parseJSON(eddie.rspBody)
            local reportedHost = rspBody.host:value()
            if reportedHost ~= eddieName then
                error("Asked DNS for ".. eddieName .." but he gave us ".. reportedHost .."")
            end
            local reportedEnv = rspBody.environment:value()
            if not app.allowedEnvs[reportedEnv:upper()] then
                error("Refuse to work on PAISA_ENV '".. reportedEnv .."'")
            end
        end,
    }
    eddie.request:closeSnk()
end


function mod.getMismatchAsStr( app, definitionJson )
    local requestFound = false
    local emsg = nil
    for iReq,req in pairs(definitionJson.requests)do
        if  req.method:value() ~= "PUT"
            or not req.uri:value():find("^/eagle/fis/information/v1/trip/registration/_hooks/listeners/http/to%-houston%-forward%-hooks$")
            then goto nextEntry end
        if req.headers[1][1]:value() ~= "x-log" or req.headers[1][2]:value() ~= "trace"
            then emsg = "Missing Header   'x-log: trace'\n"; break end
        if req.headers[2] then
            emsg = "Unexpected header   "..tostring(req.headers[2][1])..": "..tostring(req.headers[2][2]).."\n"; break end
        if req.payload.destination:value() ~= "/eagle/to-houston-urgent/fis/information/v1/trip/registration" then
            emsg = "Unexpected payload.destination: "..tostring(req.payload.destination).."\n"; break end
        if req.payload.methods[1]:value() ~= "PUT" then
            emsg = "Unexpected  payload.methods[1]: '"..tostring(req.payload.methods[1]:value()).."'" break end
        if req.payload.methods[2] then
            emsg = "Unexpected  payload.methods[2]: '"..tostring(req.payload.methods[2]:value()).."'" break end
        requestFound = true
        ::nextEntry::
    end
    if not emsg and not requestFound then emsg = "Needs Work" end
    return emsg
end


function mod.onEddie( app, eddieName )
    local emsg, definition = mod.getDefinition(app, eddieName)
    local nowStr = os.date("!%Y-%m-%dT%H:%M:%SZ")
    if emsg then
        out:write("r;".. eddieName ..";".. nowStr ..";".. emsg .."\n")
        out:flush()
        goto nextEddie
    end
    local ok, emsg = pcall(function()
        definition = parseJSON(definition)
    end)
    if not ok then
        log:write(eddieName ..": ".. emsg .."\nJSON:\n".. definition .."\n")
    end
    emsg = mod.getMismatchAsStr(app, definition)
    if not emsg then emsg = "OK" end
    out:write("r;".. eddieName ..";".. nowStr ..";".. emsg .."\n")
    out:flush()
    --sleep(0.1) -- TODO why is this here?
    ::nextEddie::
end


function mod.run( app )
    while true do
        local eddieName = inn:read("l")
        if not eddieName then break end
        eddieName = eddieName:gsub("\r$", "")
        if not eddieName:find("^eddie[0-9]+$") then error("Strange eddieName: ".. eddieName) end
        mod.onEddie(app, eddieName)
    end
end


function mod.main()
    local app = objectSeal{
        isHelp = false,
        http = newHttpClient{},
        allowedEnvs = {
            --PROD = true,
            --INT = true,
        },
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp() return end
    mod.run(app)
end


startOrExecute(mod.main)
