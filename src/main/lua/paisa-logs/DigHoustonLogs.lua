#!/usr/bin/env lua
--[====================================================================[

  projDir='/c/path/to/proj/root'
  export LUA_PATH="${projDir:?}/src/main/lua/paisa-logs/?.lua"
  lua -W "${projDir:?}/src/main/lua/paisa-logs/DigHoustonLogs.lua"

  ]====================================================================]

local PaisaLogParser = require("PaisaLogParser")
local normalizeIsoDateTime = require("PaisaLogParser").normalizeIsoDateTime
local LOGDBG = function(msg)io.stderr:write(msg)end

local main, onLogEntry, isWorthToPrint, loadFilters, initFilters


function main()
    local that = {
        logPattern = "DATE STAGE SERVICE LEVEL FILE - MSG", -- Since 2021-09-24 on prod
        printRaw = true,
        filters = false,
    }
    loadFilters(that)
    initFilters(that)
    local parser = PaisaLogParser.newLogParser({
        cls = that,
        patternV1 = that.logPattern,
        onLogEntry = onLogEntry,
    })
    parser:tryParseLogs();
end


function loadFilters( that )
    assert(not that.filters)
    that.filters = {
        -- General: Append new rules AT END if not closely related to another one.

--        { action = "drop", beforeDate = "2024-10-18 03:00:00.000", },
--        { action = "drop", afterDate  = "2024-01-31 23:59:59.999", },


        -- { action = "keep", level = "WARN", file = "BlockedThreadChecker",
        --     msgPattern = " blocked for %d%d%d+", stackPattern = "%.twimba%." },
        -- { action = "drop" },

        { action = "drop", level = "TRACE" },
        { action = "drop", level = "DEBUG" },
        { action = "drop", level = "INFO" },
        --{ action = "drop", level = "WARN" },

        -- FUCK those damn nonsense spam logs!!!
        { action = "drop", file = "Forwarder" },
        { action = "drop", level = "ERROR", file = "HttpClientRequestImpl" },
        { action = "drop", level = "ERROR", file = "BisectClient" },

        -- Seen:  2024-04-10 prod.
        -- Reported 20240410 via "https://github.com/swisspost/vertx-redisques/pull/166"
        { action = "drop", file = "RedisQues", level = "WARN",
            msgPattern = "^Registration for queue .- has changed to .-$", },

        -- Reported:  SDCISA-13717
        -- Seen:  2024-01-05 prod, 2023-10-18 prod
        {   action = "drop", file = "LocalHttpServerResponse", level = "ERROR",
            msgPattern = "^non%-proper HttpServerResponse occured\r?\n"
                .."java.lang.IllegalStateException:"
                .." You must set the Content%-Length header to be the total size of the message body BEFORE sending any data if you are not using"
                .." HTTP chunked encoding.", },

        -- Reported:  <none>
        -- Seen:  2024-01-05 prod, 2023-10-18 prod
        { action = "drop", file = "ContextImpl", level = "ERROR",
            msgPattern = "Unhandled exception\n"
                .."java.lang.IllegalStateException: You must set the Content%-Length header to be the total size of the message body BEFORE sending"
                .." any data if you are not using HTTP chunked encoding.", },

        -- Seen: 2023-10-18
        -- Happens all the time as gateleens error reporting is broken-by-desing.
        { action = "drop", file = "Forwarder", level = "WARN",
            msgPattern = "^..... ................................ Problem to request /from%-houston/[0-9]+/eagle/nsync/v1/push/trillian%-phonebooks"
                .."%-affiliated%-planning%-area%-[0-9]+%-vehicles: io.netty.channel.ConnectTimeoutException: connection timed out:"
                .." eddie[0-9]+.pnet.ch/[0-9]+:7012", },
        -- Seen:  2023-10-18
        -- Nearly same as above but on ERROR level instead.
        { action = "drop", file = "Forwarder", level = "ERROR",
            msgPattern = "^%%%w+ %x+ http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d+.vehicles"
                .." The timeout period of 30000ms has been exceeded while executing POST /from.houston/%d+/eagle/nsync/v1/push/"
                .."trillian.phonebooks.affiliated.planning.area.%d+.vehicles for server eddie%d+:7012", },
        -- Seen:  2023-10-18 prod
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://localhost:9089/houston/vehicles/%d+/vehicle/backup/v1/executions/%d+/backup.zip The timeout period of 30000ms has been exceeded"
            .." while executing PUT /houston/vehicles/%d+/vehicle/backup/v1/executions/%d+/backup.zip for server localhost:9089", },
        -- Seen:  2023-10-18 prod
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://localhost:9089/houston/vehicles/%d+/vehicle/backup/v1/executions/%d+/backup.zip Timeout$" },

        -- Seen:  2024-04-10 prod, 2023-10-18 prod
        { action = "drop", file = "ConnectionBase", level = "ERROR", msgEquals = "Connection reset by peer", },

        -- Seen:  2024-04-10 prod, 2023-10-18 prod
        { action = "drop", file = "EventBusBridgeImpl", level = "ERROR", msgEquals = "SockJSSocket exception\nio.vertx.core.VertxException: Connection was closed", },

        -- Seen:  2024-04-10 prod, 2024-01-05 prod, 2023-10-18 prod
        -- Reported:  TODO link existing issue here
        { action = "drop", file = "HttpHeaderUtil", level = "ERROR",
            msgPattern = "Keep%-Alive%} values do not match timeout=42 != timeout=120 for request /googleplex/.*", },

        -- Seen:  2024-01-05 prod
        -- Reported:  <unknown>
        { action = "drop", file = "Utils", level = "ERROR",
            msgPattern = "^Exception occurred\njava.lang.Exception: %(TIMEOUT,%-1%) Timed out after waiting 30000%(ms%) for a reply. address: __vertx.reply.%d+, repliedAddress: nsync%-[re]+gister%-sync",
            stackPattern = "^"
            .."%s-at org.swisspush.nsync.NSyncHandler.lambda.onPutClientSyncBody.%d+"
            .."%(NSyncHandler.java:%d+%) ..nsync.-at io.vertx.core.impl.future.FutureImpl.%d+.onFailure%(FutureImpl.java:%d+%)"
            ..".-"
            .."Caused by: io.vertx.core.eventbus.ReplyException: Timed out after waiting 30000%(ms%) for a reply."
            .." address: __vertx.reply.%d+, repliedAddress: nsync%-[re]+gister%-sync"
            },

        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://eddie%d+:7012/from.houston/%d+/eagle/vending/accounting/v1/users/%d+/years/%d+/months/%d%d/account Connection was closed$", },
        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d+.vehicles Connection was closed$", },
        -- Seen  2024-01-10 prod
        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/query.index The timeout period of 30000ms has been exceeded while executing"
            .." POST /from.houston/%d+/eagle/nsync/v1/query-index for server eddie%d+:7012$", },
        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://eddie%d+:7012/from.houston/%d+/eagle/timetable/notification/v1/planningareas/%d+/notifications/%x+ Connection was closed$", },
        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+ http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d+.vehicles Connection reset by peer$", },

        -- Reported:  SDCISA-9574
        -- TODO rm when resolved
        -- Seen:  2021-09-17 2022-06-20, 2022-08-30 prod,
        { action = "drop", file = "Utils", level = "ERROR",
            msgPattern = "%(RECIPIENT_FAILURE,500%) Sync failed.\n{.+}", },

        -- TODO analyze
        -- Seen 2024-03-20 prod
        { action = "drop", file = "ContextImpl", level = "ERROR",
            msgPattern = "^Unhandled exception\njava.lang.IllegalStateException: Response head already sent", },

        -- Seen:  2024-04-10 prod.
        {   action = "drop", level = "ERROR", file = "HttpClientRequestImpl",
            msgEquals = "Connection reset by peer\njava.io.IOException: Connection reset by peer",
            stackPattern = "^"
            .."%s-at sun.nio.ch.FileDispatcherImpl.read0%(.-\n"
            .."%s-at sun.nio.ch.SocketDispatcher.read%(.-\n"
            .."%s-at sun.nio.ch.IOUtil.readIntoNativeBuffer%(.-\n"
            .."%s-at sun.nio.ch.IOUtil.read%(.-\n"
            .."%s-at sun.nio.ch.IOUtil.read%(.-\n"
            .."%s-at sun.nio.ch.SocketChannelImpl.read%(.-\n"
            .."%s-at io.netty.buffer.PooledByteBuf.setBytes%(.-\n"
            .."%s-at io.netty.buffer.AbstractByteBuf.writeBytes%(.-\n"
            .."%s-at io.netty.channel.socket.nio.NioSocketChannel.doReadBytes%(.-\n"
            .."%s-at io.netty.channel.nio.AbstractNioByteChannel.NioByteUnsafe.read%(.-\n"
            .."%s-at io.netty.channel.nio.NioEventLoop.processSelectedKey%(.-\n"
            .."%s-at io.netty.channel.nio.NioEventLoop.processSelectedKeysOptimized%(.-\n"
            .."%s-at io.netty.channel.nio.NioEventLoop.processSelectedKeys%(.-\n"
            .."%s-at io.netty.channel.nio.NioEventLoop.run%(.-\n"
            .."%s-at io.netty.util.concurrent.SingleThreadEventExecutor.%d+.run%(.-\n"
            .."%s-at io.netty.util.internal.ThreadExecutorMap.%d+.run%(.-\n"
            .."%s-at io.netty.util.concurrent.FastThreadLocalRunnable.run%(.-\n"
            .."%s-at java.lang.Thread.run%(.-", },

        -- Seen:  2024-04-10 prod.
        {   action = "drop", file = "ContextImpl", level = "ERROR",
            msgEquals = "Unhandled exception\njava.lang.IllegalStateException: null",
            stackPattern = "^"
            ..".-io.vertx.-%.HttpClientResponseImpl.checkEnded%(.-\n"
            ..".-io.vertx.-%.HttpClientResponseImpl.endHandler%(.-\n"
            ..".-gateleen.routing.Forwarder.-\n", },

        -- Seen:  2024-04-10 prod.
        -- TODO get rid of this silly base class.
        {   action = "drop", file = "ContextImpl", level = "ERROR",
            msgEquals = "Unhandled exception\njava.lang.UnsupportedOperationException: Do override this method to mock expected behaviour.", },

        -- Seen:  2024-04-10 prod.
        -- TODO get rid of this silly base class.
        {   action = "drop", file = "ContextImpl", level = "ERROR",
            msgEquals = "Unhandled exception\njava.lang.UnsupportedOperationException: null", },

    }
end


function initFilters( that )
    for iF = 1, #(that.filters) do
        local descr = that.filters[iF]
        local beforeDate = descr.beforeDate and normalizeIsoDateTime(descr.beforeDate)
        local afterDate = descr.afterDate and normalizeIsoDateTime(descr.afterDate)
        local file, level, msgPattern, msgEquals = descr.file, descr.level, descr.msgPattern, descr.msgEquals
        local rawPattern, stackPattern = descr.rawPattern, descr.stackPattern
        local stackStartsWith = descr.stackStartsWith
        local filter = { action = descr.action, matches = false, }
        local hasAnyCondition = (beforeDate or afterDate or file or level or msgPattern or rawPattern or stackPattern or stackStartsWith);
        if not hasAnyCondition then
            filter.matches = function( that, log ) --[[LOGDBG("match unconditionally\n")]] return true end
        else
            filter.matches = function( that, log )
                local match, mismatch = true, false
                if not log.date then log:debugPrint() end
                if level and level ~= log.level then --[[LOGDBG("level mismatch: \"".. level .."\" != \"".. log.level .."\"\n")]] return mismatch end
                if file and file ~= log.file then --[[LOGDBG("file mismatch: \"".. file .."\" != \"".. log.file .."\"\n")]] return mismatch end
                local logDate = normalizeIsoDateTime(log.date)
                local isBeforeDate = (not beforeDate or logDate <  beforeDate);
                local isAfterDate  = (not afterDate  or logDate >= afterDate);
                if not isBeforeDate then --[[LOGDBG("not before: \"".. tostring(beforeDate) .."\", \"".. logDate .."\"\n")]] return mismatch end
                if not isAfterDate  then --[[LOGDBG("not after:  \"".. tostring(afterDate) .."\", \"".. logDate .."\"\n")]] return mismatch end
                if msgEquals and log.msg ~= msgEquals then return mismatch end
                if stackStartsWith and log.stack and log.stack:sub(1, #stackStartsWith) ~= stackStartsWith then return mismatch end
                if msgPattern and not log.msg:find(msgPattern) then --[[LOGDBG("match: msgPattern\n")]] return mismatch end
                if stackPattern and log.stack and not log.stack:find(stackPattern) then return mismatch end
                if rawPattern and not log.raw:find(rawPattern) then return mismatch end
                --LOGDBG("DEFAULT match\n")
                return match
            end
        end
        that.filters[iF] = filter
    end
end


function onLogEntry( log, that )
    local isWorthIt = isWorthToPrint(that, log)
    if isWorthIt then
        if that.printRaw then
            print(log.raw)
        else
            log:debugPrint()
        end
    end
end


function isWorthToPrint( that, log )
    local pass, drop = true, false
    for iF = 1, #(that.filters) do
        local filter = that.filters[iF]
        if filter.matches(that, log) then
            if filter.action == "drop" then return drop end
            if filter.action == "keep" then return pass end
            error("Unknown filter.action: \"".. filter.action .."\"");
        end
    end
    return pass
end


main()

