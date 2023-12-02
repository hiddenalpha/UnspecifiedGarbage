--
-- Sources:
-- - [Authorize](https://learn.microsoft.com/en-us/graph/auth-v2-user?tabs=http)
-- - [Auth witout app register](https://techcommunity.microsoft.com/t5/teams-developer/authenticate-microsoft-graph-api-with-username-and-password/m-p/3940540)
--
-- TODO: scriptlee  0.0.5-83-gdffa272 seems to SEGFAULT constantly here. No
--       matter if we use socket or newHttpClient.
-- TODO: scriptlee  0.0.5-87-g946ebdc  crashes through assertion:
--       Assertion failed: cls->msg.connect.sck->vt->unwrap != NULL, file src/windoof/c/io/AsyncIO.c, line 421
-- 

local SL = require("scriptlee")
local newHttpClient = SL.newHttpClient
--local AF_INET = SL.posix.AF_INET
--local getaddrinfo = SL.posix.getaddrinfo
--local INADDR_ANY = SL.posix.INADDR_ANY
--local inaddrOfHostname = SL.posix.inaddrOfHostname
--local IPPROTO_TCP = SL.posix.IPPROTO_TCP
local objectSeal = SL.objectSeal
--local SOCK_STREAM = SL.posix.SOCK_STREAM
--local socket = SL.posix.socket
local startOrExecute = SL.reactor.startOrExecute
--for k,v in pairs(SL)do print("SL",k,v)end os.exit(1)
SL = nil

local authorizeToMsGraphApi, getAccessToken, getAuthHdr, httpUrlEncode, main, parseArgs, printHelp,
      run, getMyProfileForDebugging
local inn, out, log = io.stdin, io.stdout, io.stderr


function printHelp()
    out:write("  \n"
        .."  TODO write help page\n"
        .."  \n")
end


function parseArgs( app )
    if #_ENV.arg == 0 then log:write("EINVAL: Args missing\n")return-1 end
    local iA = 0
    local isYolo = false
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; return 0
        elseif arg == "--user" then
            iA = iA + 1; arg = _ENV.arg[iA]
            if not arg then log:write("EINVAL: --user needs value\n")return-1 end
            app.msUser = arg
        elseif arg == "--pass" then
            iA = iA + 1; arg = _ENV.arg[iA]
            if not arg then log:write("EINVAL: --pass needs value\n")return-1 end
            app.msPass = arg
        elseif arg == "--yolo" then
            isYolo = true
        else
            log:write("EINVAL: ".. arg .."\n") return-1
        end
    end
    if not isYolo then log:write("EINVAL: This app is only for insiders\n")return-1 end
    if not app.msUser then log:write("EINVAL: --user missing\n") return-1 end
    if not app.msPass then log:write("EINVAL: --pass missing\n") return-1 end
    return 0
end


function getMyProfileForDebugging( app )
    local http = app.http
    local authKey, authVal = getAuthHdr(app)
    local req = objectSeal{
        base = false,
        method = "GET",
        uri = "/v1.0/me",
        rspCode = false,
        rspBody = {},
    }
    req.base = http:request{
        cls = req,
        host = app.msGraphHost,
        port = app.msGraphPort,
        connectTimeoutMs = 3000,
        method = req.method,
        url = req.uri,
        hdrs = {
            { authKey, authVal },
        },
        --useHostHdr = ,
        --useTLS = true,
        onRspHdr = function( rsp, cls )
            cls.rspCode = rsp.status
            if rsp.status ~= 200 then
                log:write("> ".. req.method .." ".. req.uri .."\n> \n")
                log:write("< ".. rsp.proto .." ".. rsp.status .." ".. rsp.phrase .."\n")
                for _,h in ipairs(rsp.headers)do log:write("< "..h[1]..": "..h[2].."\n")end
                log:write("\n")
            end
        end,
        onRspChunk = function(buf, cls)
            if cls.rspCode ~= 200 then
                log:write("< ")
                log:write((buf:gsub("\n", "\n< ")))
                log:write("\n")
            else
                assert(type(buf) == "string")
                table.insert(cls.rspBody, buf)
            end
        end,
        onRspEnd = function(cls)
            if cls.rspCode ~= 200 then error("Request failed.") end
            cls.rspBody = table.concat(cls.rspBody)
            log:write("Response was:\n\n")
            log:write(cls.rspBody)
            log:write("\n\n")
        end,
    }
    req.base:closeSnk()
end


function authorizeToMsGraphApi( app )
    local http = app.http
    local req = objectSeal{
        base = false,
        method = "GET",
        host = (app.proxyHost or app.msLoginHost),
        port = (app.proxyPort or app.msLoginPort),
        uri = false,
        hdrs = {
            { "Content-Type", "application/x-www-form-urlencoded" },
        },

https://login.microsoftonline.com/common/oauth2/authorize?client_id=00000002-0000-0ff1-ce00-000000000000
    &redirect_uri=https%3a%2f%2foutlook.office.com%2fowa%2f
    &resource=00000002-0000-0ff1-ce00-000000000000
    &response_mode=form_post
    &response_type=code+id_token
    &scope=openid
    &msafed=1
    &msaredir=1
    &client-request-id=f0e17000-6e10-7300-ff1c-66476b9b0128
    &protectedtoken=true
    &claims=%7b%22id_token%22%3a%7b%22xms_cc%22%3a%7b%22values%22%3a%5b%22CP1%22%5d%7d%7d%7d
    &nonce=638362912925695104.0fb89afe-011d-41a1-93f4-e15a7cfa342d
    &state=Dcs5FoAgDABR0OdxItlYcpwoprX0-lL86SanlPZlWzKupN5kSGMjNq7NKqGeGNcwjweQaIKSE5iEwkPV-x0uyjOv9yjv5-UH

        rspProto = false, rspCode = false, rspPhrase = false,
        rspHdrs = false,
        rspBody = {},
    }
    req.uri = ((app.proxyHost)and("https://".. app.msLoginHost ..":".. app.msLoginPort)or"")
        .."/".. app.msTenant .."/oauth2/v2.0/token"
        .."?grant_type=password"
        .."&resource=".. httpUrlEncode(app, "https://graph.microsoft.com")
        .."&username=".. httpUrlEncode(app, app.msUser)
        .."&password=".. httpUrlEncode(app, app.msPass),

    local printRequest = function()
        log:write("  Peer  ".. req.host .."  ".. req.port .."\n")
        log:write("> ".. req.method .." ".. req.uri .." HTTP/1.1\n")
        for _, h in ipairs(req.hdrs) do log:write("> ".. h[1] ..": ".. h[2] .."\n") end
        log:write("> \n")
        log:write("> ".. req.reqBody:gsub("\r?\n", "\n> ") .."\n")
    end
    local printResponse = function()
        log:write("  Peer  ".. req.host .."  ".. req.port .."\n")
        log:write("< ".. req.rspProto .." ".. req.rspCode .." ".. req.rspPhrase .."\n")
        for _, h in ipairs(req.rspHdrs) do log:write("< ".. h[1] ..": ".. h[2] .."\n")end
        log:write("< \n")
        log:write("< ".. rspBody:gsub("\r?\n", "\n< ") .."\n")
    end
    local ok, ex = xpcall(function()
        req.base = http:request{
            cls = req,
            connectTimeoutMs = app.connectTimeoutMs,
            host = req.host,
            port = req.port,
            method = req.method,
            url = req.uri,
            hdrs = req.hdrs,
            onRspHdr = function( rsp, req )
                req.rspProto = rsp.proto
                req.rspCode = rsp.status
                req.rspPhrase = rsp.phrase
                req.rspHdrs = rsp.headers
            end,
            onRspChunk = function( buf, req ) table.insert(req.rspBody, buf) end,
            onRspEnd = function( req )
                local rspBody = table.concat(req.rspBody) req.rspBody = false
                if req.rspCode ~= 200 then
                    log:write("[ERROR] Request failed\n")
                    printRequest()
                    printResponse()
                    error("TODO_10aa11de804e733337e7c244298791c6")
                end
                log:write("< ".. req.rspProto .." ".. req.rspCode .." ".. req.rspPhrase .."\n")
                for _, h in ipairs(req.rspHdrs) do log:write("< ".. h[1] ..": ".. h[2] .."\n")end
                log:write("< \n")
                log:write("< ".. rspBody:gsub("\r?\n", "\n< ") .."\n")
                -- How to continue:
                --local token = rsp.bodyJson.access_token
                --local authHdr = { "Authorization", "Bearer ".. token, }
            end,
        }
    end, debug.traceback)
    if not ok then
        log:write("[ERROR] Problem with ".. req.host ..":".. req.port .."\n")
        printRequest()
        error(ex)
    end
    req.base:closeSnk()
end


function httpUrlEncode( app, str )
    local hexDigits, ret, beg, iRd = "0123456789ABCDEF", {}, 1, 0
    ::nextInputChar::
    iRd = iRd + 1
    local byt = str:byte(iRd)
    if not byt then
    elseif byt == 0x2D -- dash
        or byt == 0x2E -- dot
        or byt >= 0x30 and byt <= 0x39 -- 0-9
        or byt >= 0x40 and byt <= 0x5A -- A-Z
        or byt >= 0x60 and byt <= 0x7A -- a-z
        then
        goto nextInputChar
    end
    if beg < iRd then table.insert(ret, str:sub(beg, iRd-1)) end
    if not byt then return table.concat(ret) end
    table.insert(ret, "%")
    local hi = (byt & 0xF0) >> 4 +1
    local lo = (byt & 0x0F)      +1
    table.insert(ret, hexDigits:sub(hi, hi) .. hexDigits:sub(lo, lo))
    beg = iRd + 1
    goto nextInputChar
end


function getAccessToken( app )
    -- See "https://learn.microsoft.com/en-us/graph/auth-v2-user?tabs=http#3-request-an-access-token"
    local method = "POST"
    local uri = "/".. app.msTenant .."/oauth2/v2.0/token"
    local hdrs = {
        { "Host", "https://login.microsoftonline.com" },
        { "Content-Type", "application/x-www-form-urlencoded" },
    }
    local body = ""
        .."client_id=".. app.msAppId
        .."&scope=".. scope
        .."&code=".. code
        .."&redirect_uri=".. redirUri
        .."&grant_type=authorization_code"
end


-- @return 1 - HTTP header key
-- @return 2 - HTTP header value
function getAuthHdr( app )
    assert(app.msToken)
    return "Authorization", ("Bearer ".. app.msToken)
end


function run( app )
    app.http = newHttpClient{}
    authorizeToMsGraphApi(app)
    --getMyProfileForDebugging(app)
end


function main()
    local loginHost, loginPort, graphHost, graphPort, proxyHost, proxyPort
    local choice = 4
    if choice == 1 then
        loginHost = "login.microsoftonline.com"; loginPort = 443
        graphHost = "graph.microsoft.com"; graphPort = 443
        proxyHost = "127.0.0.1"; proxyPort = 3128
    elseif choice == 2 then
        loginHost = "127.0.0.1"; loginPort = 8081
        graphHost = "127.0.0.1"; graphPort = 8081
        proxyHost = false; proxyPort = false
    elseif choice == 3 then
        loginHost = "login.microsoftonline.com"; loginPort = 443
        graphHost = "127.0.0.1"; graphPort = 8081
        proxyHost = "127.0.0.1"; proxyPort = 3128
    elseif choice == 4 then
        loginHost = "login.microsoftonline.com"; loginPort = 443
        graphHost = "graph.microsoft.com"; graphPort = 443
        proxyHost = false; proxyPort = false
    else error("TODO_1700683244") end
    local app = objectSeal{
        isHelp = false,
        msLoginHost = loginHost, msLoginPort = loginPort,
        msGraphHost = graphHost, msGraphPort = graphPort,
        proxyHost = proxyHost, proxyPort = proxyPort,
        -- TODO take this from a failed api call, which has this in the rsp headers.
        msTenant = "common", -- TODO configurable
        -- TODO take this from a failed api call, which has this in the rsp headers.
        msAppId = "00000003-0000-0000-c000-000000000000",
        msPerms = "offline_access user.read mail.read",
        msToken = false,
        msUser = false,
        msPass = false,
        http = false,
        connectTimeoutMs = 3000,
        --sck = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


startOrExecute(main)

