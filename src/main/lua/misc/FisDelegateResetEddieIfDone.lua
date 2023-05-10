
local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
local objectSeal = SL.objectSeal
local startOrExecute = SL.reactor.startOrExecute
local parseJSON = SL.parseJSON
local newShellcmd = SL.newShellcmd
SL = nil

local mod = {}
local inn, out, log = io.stdin, io.stdout, io.stderr


function mod.printHelp()
    io.stdout:write("  \n"
        .."  Options:\n"
        .."  \n"
        .."   --yolo\n"
        .."     SHUT UP And just DO IT! Caller is happy to take any risks.\n"
        .."  \n"
        .."\n\n")
end


function mod.parseArgs( app )
    app.isHelp = false
    local iA = 0
    local isYolo = false
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; return 0
        elseif arg == "--yolo" then
            isYolo = true
        else
            log:write("Bad arg: ".. arg .."\n")return-1
        end
    end
    if not isYolo then log:write("Bad args\n")return-1 end
    return 0
end


function mod.getStatus( app, eddieName )
    local sheep = objectSeal{
        base = false,
        app = app,
        rspStatus = false,
        rspBody = "",
    }
    local method = "GET"
    local path = mod.getStatusPathForEddie(app, eddieName)
    sheep.base = app.http:request{
        cls = sheep,
        host = app.houstonHost, port = app.houstonPort, method = method, url = path,
        onRspHdr = function( rsp, sheep )
            sheep.rspStatus = rsp.status
            if rsp.status ~= 200 then
                log:write("> ".. method .." ".. path .."\n")
                log:write("< ".. rsp.proto .." ".. sheep.rspStatus .." ".. rsp.phrase .."\n")
            end
        end,
        onRspChunk = function( buf, sheep )
            if sheep.rspStatus ~= 200 then
                log:write(buf or"\n")
            else
                sheep.rspBody = sheep.rspBody .. buf
            end
        end,
    }
    local ok, emsg = pcall(sheep.base.closeSnk, sheep.base)
    if not ok and emsg == "ENOMSG" then --[[scriptlee bug, should not happen at all]]
        return 200, ""
    end
    if not ok then error(emsg) end
    if sheep.rspStatus ~= 200 then error("TODO HTTP "..tostring(sheep.rspStatus)) end
    return sheep.rspStatus, sheep.rspBody
end


function mod.putStatus( app, eddieName, statusJsonStr )
    assert(type(statusJsonStr) == "string")
    assert(statusJsonStr:byte(1) == string.byte("{", 1))
    local goat = objectSeal{
        base = false,
        app = app,
        rspStatus = false,
    }
    local method, path = "PUT", mod.getStatusPathForEddie(app, eddieName)
    log:write(eddieName ..": ".. method .." ".. statusJsonStr .."\n")
    do -- Würgaround because scriptlee is too buggy
        local gagaFilePath = "C:/work/tmp/gaga.json"
        local gagaFile = io.open(gagaFilePath, "wb")
        gagaFile:write(statusJsonStr)
        gagaFile:close()
        local ok, how, num = os.execute("curl -sS -X".. method
            .." --data-binary \"@".. gagaFilePath .."\""
            .." \"http://".. app.houstonHost ..":".. app.houstonPort .. path .."\"")
        if not ok then error(how .." ".. tostring(num)) end
        os.remove(gagaFilePath)
    end
    -- TODO use  goat.base = app.http:request{
    -- TODO use      cls = goat,
    -- TODO use      host = app.houstonHost, port = app.houstonPort,
    -- TODO use      method = method, url = path,
    -- TODO use      hdrs = {
    -- TODO use          {"Content-Length", statusJsonStr:len()},
    -- TODO use      },
    -- TODO use      onRspHdr = function( rsp, goat )
    -- TODO use          goat.rspStatus = rsp.status
    -- TODO use          if rsp.status ~= 200 then
    -- TODO use              log:write("> ".. method .." ".. path .."\n")
    -- TODO use              log:write("< ".. rsp.proto .." ".. rsp.status .." ".. rsp.phrase .."\n")
    -- TODO use          end
    -- TODO use      end,
    -- TODO use      onRspChunk = function( buf, goat ) log:write(buf) end
    -- TODO use  }
    -- TODO use  goat.base:write(statusJsonStr)
    -- TODO use  goat.base:closeSnk()
    -- TODO use  if goat.rspStatus ~= 200 then
    -- TODO use      log:write("\n")
    -- TODO use      error("TODO bad response")
    -- TODO use  end
end


function mod.getStatusPathForEddie( app, eddieName )
    assert(eddieName:find("^eddie[0-9]+$"))
    return "/houston/data/lyricon/helper-state/fisInfoDelegate-PROD-Execute/scripthost/eddies/".. eddieName .."/status"
end


function mod.readNextEddieNameFromStdin( app )
    local eddieName = inn:read("l")
    if not eddieName then return nil end
    if eddieName:find("\r$") then eddieName = eddieName:sub(1, -2) end
    assert((string.find(eddieName, "^eddie[0-9]+$")), eddieName)
    return eddieName
end


function mod.run( app )
    while true do
        local eddieName = mod.readNextEddieNameFromStdin(app)
        if not eddieName then break end
        local code, body = mod.getStatus(app, eddieName)
        body = parseJSON(body)
        if body.status:value() ~= "DONE" then log:write(eddieName..": Keep status '".. body.status:value() .."'\n")goto nextEddie end
        assert(type(body.status:value()) == "string")
        assert(type(body.timestamp:value()) == "string")
        assert(type(body.message:value()) == "string")
        assert(#body == 3)
        mod.putStatus(app, eddieName, '{'
            ..  '"timestamp":"'.. body.timestamp:value() ..'",'
            ..  '"status":"ERROR_RETRY",'
            ..  '"message":"Definition broken (probably due to eagle update). Manually scheduled to fix it again"'
            ..'}')
        ::nextEddie::
    end
end


function mod.main()
    local app = objectSeal{
        isHelp = false,
        http = newHttpClient{},
        houstonHost = "127.0.0.1",
        houstonPort = 7013,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp() return end
    mod.run(app)
end


startOrExecute(nil, mod.main)
