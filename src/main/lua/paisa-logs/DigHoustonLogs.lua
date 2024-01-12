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

        { action = "drop", beforeDate = "2023-10-18 03:00:00.000", },
        { action = "drop", afterDate  = "2024-01-31 23:59:59.999", },

        { action = "drop", level = "TRACE" },
        { action = "drop", level = "DEBUG" },
        { action = "drop", level = "INFO" },
        { action = "drop", level = "WARN" },

--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "ContextImpl", level = "ERROR",
--            msgEquals = "Unhandled exception\njava.lang.NullPointerException: No null handler accepted",
--            stackPattern = "^"
--                .."\tat java.util.Objects.requireNonNull.Objects.java:246. ~..:..\n"
--                .."\tat io.vertx.core.impl.future.FutureImpl.onComplete.FutureImpl.java:132. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n"
--                .."\tat io.vertx.core.impl.future.PromiseImpl.onComplete.PromiseImpl.java:23. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n"
--                .."\tat io.vertx.core.file.impl.FileSystemImpl.delete.FileSystemImpl.java:290. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n"
--                .."\tat org.swisspush.reststorage.FilePutter.FileCleanupManager.deleteFile.FilePutter.java:218. ~.rest.storage.[0-9.]+.jar:..\n"
--                .."\tat org.swisspush.reststorage.FilePutter.FileCleanupManager.lambda.cleanupFile.0.FilePutter.java:192. ~.rest.storage.[0-9.]+.jar:..\n"
--                .."\tat io.vertx.core.impl.future.FutureImpl.3.onSuccess.FutureImpl.java:141. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n"
--        },
--
--        -- Seen:  2023-10-18 prod
--        -- TODO open PR to add some logging so we have a chance to find submarine.
--        { action = "drop", file = "ContextImpl", level = "ERROR",
--            msgEquals = "Unhandled exception\njava.lang.IllegalStateException: Response head already sent",
--            stackPattern = "^"
--                .."\tat io.vertx.core.http.impl.Http1xServerResponse.checkHeadWritten.Http1xServerResponse.java:684. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n"
--                .."\tat io.vertx.core.http.impl.Http1xServerResponse.setStatusCode.Http1xServerResponse.java:153. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n"
--                .."\tat org.swisspush.gateleen.routing.Forwarder.lambda.getAsyncHttpClientResponseHandler.7.Forwarder.java:430. ~.gateleen.routing.[0-9.]+.jar:..\n"
--                .."\tat io.vertx.core.impl.future.FutureImpl.3.onFailure.FutureImpl.java:153. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n",
--        },

        -- Reported:  SDCISA-13717
        -- Seen:  2024-01-05 prod, 2023-10-18 prod
        { action = "drop", file = "LocalHttpServerResponse", level = "ERROR",
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

--        -- Seen:  2023-10-18
--        -- Opened nsync PR 49 as a first counter measure.
--        { action = "drop", file = "ContextImpl", level = "ERROR", msgEquals = "Unhandled exception\njava.lang.NullPointerException: null",
--            stackStartsWith = "\tat org.swisspush.nsync.multiget.MultiGetServer.lambda$tryLaunchOneRequest$2(MultiGetServer.java:107) ~[nsync-0.6.0.jar:?]" },


        -- Bunch of nonsense !ERROR!s which happen all the time as eddies go offline.

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
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
--            .." http://localhost:9089/houston/vehicles/%d+/vehicle/backup/v1/executions/%d+/backup.zip The timeout period of 30000ms has been exceeded"
--            .." while executing PUT /houston/vehicles/%d+/vehicle/backup/v1/executions/%d+/backup.zip for server localhost:9089", },
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
--            .." http://localhost:9089/houston/vehicles/%d+/vehicle/backup/v1/executions/%d+/backup.zip Timeout$" },
--        -- Seen:  2023-10-18 prod
--        -- I guess this happens if an eddie tries to put his "backup.zip" via shaky connection.
--        { action = "drop", file = "FilePutter", level = "ERROR",
--            msgEquals = "Put file failed:\nio.vertx.core.VertxException: Connection was closed", },
        -- Seen:  2024-01-10 prod, 2023-10-18 prod
        -- There are a whole bunch of related errors behind this filter which AFAICT all relate to shaky eddie connections.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+ http://eddie%d+:7012/from.houston/%d+/eagle/[^ ]+"
            .." The timeout period of 30000ms has been exceeded while executing [DEGLOPSTU]+ /from.houston/%d+/eagle/[^ ]+ for server eddie%d+:7012$", },
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "Forwarder", level = "ERROR",
--            msgPattern = "^%%%w+ %x+ http://eddie%d+:7012/from.houston/%d+/eagle/[^ ]+ Connection was closed$", },
--
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "ConnectionBase", level = "ERROR", msgEquals = "Connection reset by peer", },
--
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "EventBusBridgeImpl", level = "ERROR", msgEquals = "SockJSSocket exception\nio.vertx.core.VertxException: Connection was closed", },

        -- Seen:  2024-01-05 prod, 2023-10-18 prod
        -- Reported:  TODO link existing issue here
        { action = "drop", file = "HttpHeaderUtil", level = "ERROR",
            msgPattern = "Keep%-Alive%} values do not match timeout=42 != timeout=120 for request /googleplex/.*", },

--        -- Seen:  2023-10-18 prod
--        -- Reported:  <unknown>
--        { action = "drop", file = "Utils", level = "ERROR",
--            msgPattern = "^Exception occurred\nio.vertx.core.eventbus.ReplyException: Sync failed.\n"
--                .."{\n"
--                ..'  "countIndexQueries" : 1,\n'
--                ..'  "countSentBytes" : 119,\n'
--                ..'  "countReceivedBytes" : 0,\n'
--                ..'  "countMultiGetRequests" : 0,\n'
--                ..'  "countPuts" : 0,\n'
--                ..'  "countDeletes" : 0,\n'
--                ..'  "durationSeconds" : 0.0,\n'
--                ..'  "iterationDepth" : 0\n'
--                .."}", },
--
--        -- Seen:  2023-10-18 prod
--        -- Reported:  <unknown>
--        { action = "drop", file = "ContextImpl", level = "ERROR", msgEquals = "Unhandled exception\njava.lang.UnsupportedOperationException: null",
--            stackPattern = "^"
--                .."\tat org.swisspush.gateleen.core.http.LocalHttpClientRequest.connection.LocalHttpClientRequest.java:754. ~.gateleen.core.[0-9.]+.jar:..\n"
--                .."\tat org.swisspush.gateleen.routing.Forwarder.1.lambda.handle.0.Forwarder.java:362. ~.gateleen.routing.[0-9.]+.jar:..\n"
--                .."\tat io.vertx.core.impl.AbstractContext.dispatch.AbstractContext.java:100. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n",
--        },

        -- Seen:  2024-01-05 prod, 2023-10-18 prod
        -- Reported:  <unknown>
        { action = "drop", file = "Utils", level = "ERROR",
            msgPattern = "^Exception occurred\nio.vertx.core.eventbus.ReplyException: Timed out after waiting 30000.ms. for a reply. address:"
                .." __vertx.reply.[0-9]+, repliedAddress: nsync.reregister.sync/slarti.vehicle.setup.sync.[0-9]+",
        },

        -- Seen:  2024-01-05 prod, 2023-10-18 prod
        -- Reported:  <unknown>
        { action = "drop", file = "Utils", level = "ERROR", msgPattern = "^Exception occurred\n"
            .."io.vertx.core.eventbus.ReplyException: Timed out after waiting 30000.ms. for a reply. address: __vertx.reply.[0-9]+, repliedAddress: nsync.register.sync" },

--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "HttpClientRequestImpl", level = "ERROR",
--            msgEquals = "Connection was closed\nio.vertx.core.VertxException: Connection was closed", },
--
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "Forwarder", level = "ERROR",
--            msgPattern = "^..... ................................ http://bistr:8080/bistr/vending/accounting/v1/information/lastSessionEnd Connection was closed$", },
--
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "Forwarder", level = "ERROR",
--            msgPattern = "..... ................................ http://bob:8080/bob/vending/transaction/v1/systems/%d+/dates/[0-9-]+/transactions/%d+/start"
--                .." The timeout period of 30000ms has been exceeded while executing PUT /bob/vending/transaction/v1/systems/%d+/dates/[0-9-]+/transactions/%d+/start"
--                .." for server bob:8080", },
--
--        -- Seen:  2023-10-18 prod
--        { action = "drop", file = "ContextImpl", level = "ERROR", msgEquals = "Unhandled exception\njava.lang.IllegalStateException: null",
--            stackStartsWith = ""
--                .."\tat io.vertx.core.http.impl.HttpClientResponseImpl.checkEnded(HttpClientResponseImpl.java:150) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.http.impl.HttpClientResponseImpl.endHandler(HttpClientResponseImpl.java:172) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat org.swisspush.gateleen.routing.Forwarder.lambda$getAsyncHttpClientResponseHandler$7(Forwarder.java:476) ~[gateleen-routing-1.3.25.jar:?]\n"
--                .."\tat io.vertx.core.impl.future.FutureImpl$3.onSuccess(FutureImpl.java:141) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.impl.future.FutureBase.emitSuccess(FutureBase.java:60) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.impl.future.FutureImpl.addListener(FutureImpl.java:196) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.impl.future.PromiseImpl.addListener(PromiseImpl.java:23) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.impl.future.FutureImpl.onComplete(FutureImpl.java:164) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.impl.future.PromiseImpl.onComplete(PromiseImpl.java:23) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.http.impl.HttpClientRequestBase.response(HttpClientRequestBase.java:240) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat io.vertx.core.http.HttpClientRequest.send(HttpClientRequest.java:330) ~[vertx-core-4.2.1.jar:4.2.1]\n"
--                .."\tat org.swisspush.gateleen.routing.Forwarder$1.lambda$handle$1(Forwarder.java:377) ~[gateleen-routing-1.3.25.jar:?]\n"
--                .."\tat org.swisspush.gateleen.core.http.BufferBridge.lambda$pump$0(BufferBridge.java:43) ~[gateleen-core-1.3.25.jar:?]\n"
--                .."\tat io.vertx.core.impl.AbstractContext.dispatch(AbstractContext.java:100) ~[vertx-core-4.2.1.jar:4.2.1]\n",
--        },
--
--        -- Seen:  2023-10-18 prod
--        -- TODO Push issue to my backlog to fix this.
--        { action = "drop", file = "ContextImpl", level = "ERROR",
--            msgEquals = "Unhandled exception\njava.lang.UnsupportedOperationException: Do override this method to mock expected behaviour.",
--            stackPattern = "^"
--                .."\tat org.swisspush.gateleen.core.http.FastFailHttpServerResponse.drainHandler.FastFailHttpServerResponse.java:41. ~.gateleen.core.[0-9.]+.jar:..\n"
--                .."\tat org.swisspush.gateleen.core.http.FastFailHttpServerResponse.drainHandler.FastFailHttpServerResponse.java:24. ~.gateleen.core.[0-9.]+.jar:..\n"
--                .."\tat org.swisspush.gateleen.logging.LoggingWriteStream.drainHandler.LoggingWriteStream.java:73. ~.gateleen.logging.[0-9.]+.jar:..\n"
--                .."\tat io.vertx.core.streams.impl.PumpImpl.stop.PumpImpl.java:95. ~.vertx.core.[0-9.]+.jar:[0-9.]+]\n"
--                .."\tat io.vertx.core.streams.impl.PumpImpl.stop.PumpImpl.java:39. ~.vertx.core.[0-9.]+.jar:[0-9.]+]\n"
--                .."\tat org.swisspush.gateleen.routing.Forwarder.lambda$getAsyncHttpClientResponseHandler.4.Forwarder.java:494. ~.gateleen.routing.[0-9.]+.jar:..\n"
--                .."\tat org.swisspush.gateleen.routing.Forwarder.lambda$getAsyncHttpClientResponseHandler.5.Forwarder.java:503. ~.gateleen.routing.[0-9.]+.jar:..\n"
--                .."\tat io.vertx.core.impl.AbstractContext.dispatch.AbstractContext.java:100. ~.vertx.core.[0-9.]+.jar:[0-9.]+.\n",
--        },
--
--        { action = "drop", file = "Forwarder", level = "ERROR",
--            msgPattern = "^..... ................................ http://thought:8080/thought/vehicleoperation/recording/v1/events The timeout period of 60000ms has been exceeded while executing PUT /thought/vehicleoperation/recording/v1/events for server thought:8080$",
--        },
--
--        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
--        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
--            .." http://eddie%d+:7012/from.houston/%d+/eagle/vending/accounting/v1/users/%d+/years/%d+/months/%d%d/account Connection was closed$", },
--        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
--        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
--            .." http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d+.vehicles Connection was closed$", },
        -- Seen  2024-01-10 prod
        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/query.index The timeout period of 30000ms has been exceeded while executing"
            .." POST /from.houston/%d+/eagle/nsync/v1/query-index for server eddie%d+:7012$", },
        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+"
            .." http://eddie%d+:7012/from.houston/%d+/eagle/timetable/notification/v1/planningareas/%d+/notifications/%x+ Connection was closed$", },
--        -- WELL_KNOWN: I guess happens when vehicle looses connection. Seen 2023-10-18 prod.
--        { action = "drop", file = "Forwarder", level = "ERROR", msgPattern = "^%%%w+ %x+ http://eddie%d+:7012/from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d+.vehicles Connection reset by peer$", },

        ---- TODO Thought timeout? Can happen. But how often is ok?
        ---- HINT: Occurred 15 times in 6 hrs (avg 1x per 24min) (2021-09-17_12:00 to 2021-09-17_18:00)
        ---- Seen  2022-06-20, 2022-08-30 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://[aghilmostuwy]+:8080/[aghilmostuwy]+/vehicleoperation/recording/v1/.+ Timeout", },

        ---- [SDCISA-9572] pag
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://[8acgilmnpsvwy]+:[78]080/[_aegilmopstwy]+/.+ Connection was closed", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "t.ch:7022/brox/from/vehicles/.+Connection refused: ", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = " http://%w+.pnet.ch:7022/brox/info Connection refused: %w+.pnet.ch/[%d.]+:7022" },

        ---- TODO Analyze
        ---- Observed  20014 times within 6 hrs (~1/sec) (2021-09-17_12:00 to 2021-09-17_18:00)
        ---- HINT: Eddie connections issues also have around 20000 occurrences. Maybe related?
        ---- Seen:  2021-09-17
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://eddie%d+:7012/from.houston/[^/]+/eagle/[^ ]+ Response already written. Not sure about the"
        --           .." state. Closing server connection for stability reason", },

        ---- TODO Analyze
        ---- HINT: Occurred 1538 times in 6 hrs (~ 1x per 15sec) (2021-09-17_12:00 to 2021-09-17_18:00)
        --{ action = "drop", file = "Forwarder", level = "WARN",
        --    msgPattern = "Failed to '[^ ]+ /from%-houston/%d+/eagle/.+'\n.+VertxException: Connection was closed", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://eddie%d+:7012/from%-houston/%d+/eagle/.+ Connection was closed", },

        ---- TODO Analyze
        ---- Seen:  2021-09-17, ..., 2022-06-20
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://pag:8080/pag/user/information/v1/directory/sync/request Timeout", },

        ---- Seen  2021-10-25, 2022-08-30 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://[8acgilmnpsvwy]+:8080/[_aegilmopstwy]+/.+ Response already written. Not sure about the"
        --           .." state. Closing server connection for stability reason", },

        ---- TODO Analyze.
        ---- Seen  2021-09-17, 2022-06-20
        --{ action = "drop", file = "BisectClient", level = "WARN",
        --    msgPattern = "statusCode=503 received for POST /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index", },
        ---- Seen  2022-06-20 prod
        --{ action = "drop", file = "BisectClient", level = "WARN",
        --    msgPattern = "statusCode=504 received for POST /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index", },
        ---- TODO rm filter when fixed
        ---- Reported:  SDCISA-9573
        ---- Seen:  2022-08-30 prod,  2022-06-20,  2021-09-17
        --{ action = "drop", file = "BisectClient", level = "WARN",
        --    msgPattern = "Index id=slarti%-vehicle%-setup%-sync%-%d+ rootPath=/houston/from/vehicles/%d+/vehicle/setup/v1 size=%d+ not %(nor no more%) ready. Aborting BisectClient", },

        ---- Reported:  SDCISA-9574
        ---- TODO rm when resolved
        ---- Seen:  2021-09-17 2022-06-20, 2022-08-30 prod,
        --{ action = "drop", file = "Utils", level = "ERROR",
        --    msgPattern = "Exception occurred\n%(RECIPIENT_FAILURE,500%) Sync failed.\n{.+}", },

        ---- TODO Analyze
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "http://preflux:8080/preflux/data/preflux/rollout/hosts/eddie%d+/instances/default/situation Timeout", },

        ---- TODO Analyze.
        ---- Seen  2022-08-30 prod, 2022-06-20,  2021-09-17
        --{ action = "drop", file = "RedisQues", level = "WARN",
        --    msgPattern = "Registration for queue .+ has changed to null", },

--        -- Reported: SDCISA-10973
--        -- Seen:  2023-10-18 prod.
--        { action = "drop", file = "HttpClientRequestImpl", level = "ERROR",
--            msgPattern = "The timeout period of 30000ms has been exceeded while executing PUT /houston/vehicles/[0-9]+"
--                   .."/vehicle/backup/v1/executions/[0-9]+/backup.zip for server localhost:9089", },

        -- Seen  2024-01-10 prod
        { action = "drop", file = "HttpClientRequestImpl", level = "ERROR",
            msgPattern = "The timeout period of 30000ms has been exceeded while executing POST /from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d+.vehicles for server eddie%d+:7012" },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = "[%a-z0-9]+ [a-z0-9]+ http://eddie.....:7012/from%-houston/[^/]+/eagle/nsync/v1/push/trillian"
        --           .."%-phonebooks%-affiliated%-planning%-area%-[^-]+%-vehicles The timeout period of 30000ms has been"
        --           .." exceeded while executing POST /from%-houston/[0-9]+/eagle/nsync/v1/push/trillian%-phonebooks"
        --           .."%-affiliated%-planning%-area%-[^%-]+-vehicles for server eddie.....:7012", },

        ---- Reported: SDCISA-9578
        ---- TODO rm when fixed
        ---- Seen  2022-08-30 prod,  2022-06-20 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected"
        --           .." Connection reset by peer", },
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected"
        --           .." Connection was closed", },
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected"
        --           .." Response already written. Not sure about the state. Closing server connection for stability reason", },

        ---- TODO analyze
        ---- Seen  2022-06-20 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPattern = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/timetable/private/v1/trip/state/%w+.xml Connection was closed", },

    }
end


function initFilters( that )
    for iF = 1, #(that.filters) do
        local descr = that.filters[iF]
        local beforeDate = descr.beforeDate and normalizeIsoDateTime(descr.beforeDate)
        local afterDate = descr.afterDate and normalizeIsoDateTime(descr.afterDate)
        local file, level, msgPattern = descr.file, descr.level, descr.msgPattern
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

