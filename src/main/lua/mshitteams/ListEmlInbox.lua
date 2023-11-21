--
-- Sources:
-- - [Authorize](https://learn.microsoft.com/en-us/graph/auth-v2-user?tabs=http)
--
-- TODO: scriptlee  0.0.5-83-gdffa272 seems to SEGFAULT constantly here. No
--       matter if we use socket or newHttpClient.
--

local SL = require("scriptlee")
local AF_INET = SL.posix.AF_INET
local getaddrinfo = SL.posix.getaddrinfo
local INADDR_ANY = SL.posix.INADDR_ANY
local inaddrOfHostname = SL.posix.inaddrOfHostname
local IPPROTO_TCP = SL.posix.IPPROTO_TCP
local objectSeal = SL.objectSeal
local SOCK_STREAM = SL.posix.SOCK_STREAM
local socket = SL.posix.socket
local startOrExecute = SL.reactor.startOrExecute
--for k,v in pairs(SL)do print("SL",k,v)end os.exit(1)
SL = nil

local authorizeToMsGraphApi, getAccessToken, getAuthHdr, httpUrlEncode, main, parseArgs, printHelp,
      run, getMyProfileForDebugging
local inn, out, log = io.stdin, io.stdout, io.stderr


function printHelp()
    out:write("  \n"
        .."  Options:\n"
        .."  \n"
        .."\n\n")
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
        elseif arg == "--yolo" then
            isYolo = true
        else
            log:write("EINVAL: ".. arg .."\n") return-1
        end
    end
    if not isYolo then log:write("EINVAL\n")return-1 end
    return 0
end


function getMyProfileForDebugging( app )
    local sck = app.sck
    local authKey, authVal = getAuthHdr(app)
    local req = objectSeal{
        base = false,
    }
    sck:write("GET /v1.0/me HTTP/1.1\r\n"
        .."".. authKey ..": ".. authVal .."\r\n"
        .."\r\n")
    sck:flush()
    local buf = sck:read()
    log:write("buf is '"..tostring(buf).."'\n")
end


function authorizeToMsGraphApi( app )
    -- See "https://learn.microsoft.com/en-us/graph/auth-v2-user?tabs=http"
    local redirUri = "https%3A%2F%2Flogin.microsoftonline.com%2Fcommon%2Foauth2%2Fnativeclient"
    local scope = "offline_access%20user.read%20mail.read"
    local stateDict = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local state = {}
    for i=1, 16 do
        local rnd = math.random(1, #stateDict)
        state[i] = chars:sub(rnd, rnd)
    end
    state = table.concat(state)
    local method = "GET"
    local url = "https://login.microsoftonline.com/".. app.msTenant .."/oauth2/v2.0/authorize"
        .."?client_id=".. app.msAppId
        .."&response_type=code"
        .."&redirect_uri=".. redirUri
        .."&response_mode=query"
        .."&scope=".. httpUrlEncode(app.msPerms)
        .."&state=".. state
end


function httpUrlEncode( app, str )
    local hexDigits, ret, beg, iRd = "0123456789ABCDEF", {}, 1, 0
    ::nextInputChar::
    iRd = iRd + 1
    local byt = str:byte(iRd)
    if not byt then
    elseif byt == 0x2D -- dash
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
    return "Authorization", ("Bearer ".. app.msBearerToken)
end


function initHttpClient( app )
    local sck = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    sck:connect(app.msGraphHost, app.msGraphPort, app.connectTimeoutMs)
    app.sck = sck
end


function run( app )
    initHttpClient(app)
    getMyProfileForDebugging(app)
end


function main()
    local app = objectSeal{
        isHelp = false,
        msGraphHost = "127.0.0.1",
        msGraphPort = 8080,
        msTenant = "TODO_1700563786",
        msAppId = "TODO_1700563821",
        msPerms = "offline_access user.read mail.read",
        msBearerToken = "TODO_1700575589",
        connectTimeoutMs = 3000,
        sck = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


startOrExecute(main)

