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
local async = assert(require("scriptlee").reactor.async)
local inaddrOfHostname = require('scriptlee').posix.inaddrOfHostname
local newHttpClient = assert(require("scriptlee").newHttpClient)
local objectSeal = assert(require("scriptlee").objectSeal)
local sleep = assert(require("scriptlee").posix.sleep)
local socket = assert(require("scriptlee").posix.socket)
local startOrExecute = assert(require("scriptlee").reactor.startOrExecute)

local mod = {}
local stdinn, stdout, stdlog = io.stdin, io.stdout, io.stderr


function mod.newSocketMgr( app )
    local t = {
        numWorking = 0,
        socktsIdle = {},
    }
    local m = {
        openSock = function(t, opts)
            --stdlog:write("openSock()\n")
            assert(opts.useTLS == false)
            local host, port = opts.host, opts.port
            -- Limit max parallel connections
            while t.numWorking >= 4 do sleep(0.001) end
            t.numWorking = t.numWorking + 1
            local socktsForThisHost = t.socktsIdle[host.."\t"..port]
            local s = false
            if socktsForThisHost and #socktsForThisHost > 0 then
                s = table.remove(socktsForThisHost, #socktsForThisHost)
            end
            if not s then -- create a new one
                --stdlog:write("s = socket(...)\n")
                local inaddr = inaddrOfHostname(host)
                s = socket(AF_INET, SOCK_STREAM, 0)
                s:connect(host, port)
            else
                -- s is already set to an old socket ready-to-reuse
                --stdlog:write("s = getExisting()\n")
            end
            return objectSeal{
                base = assert(s),
                host = assert(host),
                port = assert(port),
                -- exposed API:
                write = function(t, buf, beg, len) t.base:write(buf, beg, len) end,
                flush = function(t) t.base:flush() end,
                read = function(t, a, b, c, d) return t.base:read() end,
            }
        end,
        releaseSock = function(t, s)
            --stdlog:write("releaseSock()\n")
            t.numWorking = t.numWorking - 1
            local socktsForThisHost = t.socktsIdle[s.host.."\t"..s.port]
            if not socktsForThisHost then
                socktsForThisHost = {}
                t.socktsIdle[s.host.."\t"..s.port] = socktsForThisHost
            end
            table.insert(socktsForThisHost, s.base)
        end,
        closeSock = function(t, s)
            stdlog:write("closeSock("..tostring(s.base)..")\n")
            s.base:close()
        end,
    }
    m.__index = m
    return setmetatable(t, m)
end


function mod.run( app )
    local httpClient = app.httpClient
    local method, url = "GET", "/houston/server/apps/rest-editor/app/css/editor.css"
    for i=1, 1024 do
        async(function( i )
            --stdlog:write(""..method.." "..url.."  (i "..i..")\n")
            httpClient:request{
                --cls = ,
                host = "127.0.0.1", port = 7012,
                --host = "127.0.0.1", port = 7013,
                method = method, url = url,
                --hdrs = ,
                --onRspHdr = function( rspHdr, cls )
                --    stdlog:write( rspHdr.proto .." ".. rspHdr.status .." ".. rspHdr.phrase .."\n")
                --end,
                --onRspChunk = ,
                --onRspEnd = function()
                --    stdlog:write("onRspEnd()\n")
                --end,
            }:closeSnk()
        end, i)
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

