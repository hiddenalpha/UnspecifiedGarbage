
local newHttpClient = require("scriptlee").newHttpClient
local objectSeal = require("scriptlee").objectSeal
local startOrExecute = require("scriptlee").reactor.startOrExecute

local inn, out, log = io.stdin, io.stdout, io.stderr
local mod = {}


function mod.printHelp()
    out:write("\n"
        .."  TODO write help page\n"
        .."  \n"
        .."  WARN experminental code in here!\n"
        .."\n"
        .."  Options:\n"
        .."\n"
        .."    --pomUrls <path>\n"
        .."        File with a LF separated list of pom.xml URLs to scan.\n"
        .."\n"
        .."\n")
end


function mod.parseArgs( app )
    local iA = 0
    while true do
        iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            mod.printHelp() return -1
        elseif arg == "--pomUrls" then
            iA = iA +1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --pomUrls needs value\n") return -1 end
            app.pomUrlsPath = arg;
        else
            log:write("Unexpected arg: ".. arg .."\n") return -1
        end
    end
    if not app.pomUrlsPath then log:write("Arg --pomUrls missing\n") return -1 end
    return 0
end


function mod.run( app )
    mod.loadPomUrlsFully(app)
    for iPomUrl, pomUrl in ipairs(app.pomUrls) do
        local host = pomUrl:match("http://([^:/]+).*")
        local port = pomUrl:match("http://[^:/]+:([%d]+).*") or 80
        local url = pomUrl:match("http://[^:/]+[:%d]*(/.*)$")
        local pomReq = objectSeal{ base=false, }
        pomReq.base = app.http:request{
            cls = pomReq,
            host = host, port = port,
            method = "GET", url = url,
            --hdrs = ,
            --useTLS = ,
            onRspHdr = function( hdr, pomReq )
                log:write(hdr.proto .." ".. hdr.status .." ".. hdr.phrase .."\n")
                for i,v in ipairs(hdr.headers) do print("H", "headers",v.key, v.val) end
            end,
            onRspChunk = function( buf, pomReq )
                if buf then log:write("onRspChunk(l="..buf:len()..")\n") end
            end,
            onRspEnd = function( pomReq )
                log:write("onRspEnd()\n")
            end,
        }
        pomReq.base:closeSnk()
    end
end


function mod.loadPomUrlsFully( app )
    local file = io.open(app.pomUrlsPath, "rb")
    if not file then error("Failed open("..tostring(app.pomUrlsPath)..")") end
    assert(not app.pomUrls)
    app.pomUrls = {}
    while true do
        local pomUrl = file:read("l")
        if not pomUrl then break end
        assert(pomUrl:find("^http://.*$"), pomUrl)
        table.insert(app.pomUrls, pomUrl)
    end
end


function mod.main()
    local app = objectSeal{
        http = newHttpClient{},
        pomUrlsPath = false,
        pomUrls = false,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(nil, mod.main)
