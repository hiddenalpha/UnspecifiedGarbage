--[====================================================================[

  Initially develope at 2022-11-22 to hunt some strange race condition
  in houston. There's an ArrayIndexOutOfBoundsException coming somewhere
  from within jdk
  at java.base/jdk.internal.math.FloatingDecimal.readJavaFormatString(FloatingDecimal.java:2054)
  but no idea yet why sometimes we see those exceptions while classpath
  resource requests.

  ]====================================================================]

local AF_INET = assert(require("scriptlee").posix.AF_INET)
local SOCK_STREAM = assert(require("scriptlee").posix.SOCK_STREAM)
local inaddrOfHostname = require('scriptlee').posix.inaddrOfHostname
local newHttpClient = assert(require("scriptlee").newHttpClient)
local objectSeal = assert(require("scriptlee").objectSeal)
local socket = assert(require("scriptlee").posix.socket)
local startOrExecute = assert(require("scriptlee").reactor.startOrExecute)

local mod = {}
local stdinn, stdout, stdlog = io.stdin, io.stdout, io.stderr


function mod.newSocketMgr( app )
    local t = {
        socktsIdle = {},
    }
    local m = {
        openSock = function(t, opts)
            assert(opts.useTLS == false)
            local host, port = opts.host, opts.port
            local socktsForThisHost = t.socktsIdle[host.."\t"..port]
            local s = false
            if socktsForThisHost and #socktsForThisHost > 0 then
                s = table.remove(socktsForThisHost, #socktsForThisHost)
            end
            if not s then -- create a new one
                local inaddr = inaddrOfHostname(host)
                s = socket(AF_INET, SOCK_STREAM, 0)
                s:connect(host, port)
            else
                -- s is already set to an old socket ready-to-reuse
            end
            return objectSeal{
                orig = assert(s),
                host = assert(host),
                port = assert(port),
                -- exposed API:
                write = function(t, buf, beg, len) t.orig:write(buf, beg, len) end,
                flush = function(t) t.orig:flush() end,
                read = function(t, a, b, c, d) return t.orig:read() end,
            }
        end,
        releaseSock = function(t, s)
            local socktsForThisHost = t.socktsIdle[s.host.."\t"..s.port]
            if not socktsForThisHost then
                socktsForThisHost = {}
                t.socktsIdle[s.host.."\t"..s.port] = socktsForThisHost
            end
            table.insert(socktsForThisHost, s.orig)
        end,
        --closeSock = function(t, s) s.orig:close() end,
    }
    m.__index = m
    return setmetatable(t, m)
end


function mod.run( app )
    local httpClient = app.httpClient
    for i=0, 3 do
        httpClient:request{
            --cls = ,
            host = "127.0.0.1", port = 7013,
            method = "GET", url = "/houston/server/apps/rest-editor/app/css/editor.css",
            --hdrs = ,
            --onRspHdr = ,
            --onRspChunk = ,
            onRspEnd = function() stdlog:write("onRspEnd()\n") end,
        }:closeSnk()
    end
end


function mod.main()
    local app = objectSeal{
        httpClient = newHttpClient{
            socketMgr = mod.newSocketMgr(app),
        },
    }
    mod.run(app)
end


startOrExecute(nil, mod.main)

