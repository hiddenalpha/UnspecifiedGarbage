--[====================================================================[

  projDir="C:\path\to\proj\root"
  export LUA_PATH="${projDir:?}/lib/?.lua"
  lua -W "${projDir:?}/bin/DigHoustonLogs.lua"

  ]====================================================================]

local PaisaLogParser = require("PaisaLogParser")
local mod = {}


function mod.main()
    local that = {}
    that.printRaw = true
    local parser = PaisaLogParser.newLogParser({
        cls = that,
        -- Since 2021-09-24 on prod
        patternV1 = "DATE STAGE SERVICE LEVEL FILE - MSG",
        onLogEntry = mod.onLogEntry,
    })
    parser:tryParseLogs();
end


function mod.onLogEntry( log, that )
    if not mod.isTimeRangeOk(that,log) then return end
    if not mod.isLevelOk(that,log) then return end
    if not mod.acceptedByMisc(that,log) then return end
    if     mod.isUselessNoise(that,log) then return end
    --if not mod.isNotYetReported(that,log) then return end
    mod.debugPrintLogEntry( that, log )
end


function mod.isTimeRangeOk( that, log )
    local pass, drop = true, false
    --if log.date < "2022-06-20 08:00:00,000" then return drop end
    --if log.date > "2022-06-20 08:30:00,000" then return drop end
    return pass
end


function mod.isLevelOk( that, log )
    local pass, drop = true, false
    --if log.level=="TRACE" then return drop end
    --if log.level=="DEBUG" then return drop end
    --if log.level=="INFO" then return drop end
    return pass
end


-- All other crap which is neither categorized nor analyzed.
function mod.acceptedByMisc( that, log )
    local pass, drop = true, false

    -- This is when position from naviation have problems.
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("t.ch:7022/brox/from/vehicles/.+Connection refused: ")
        then return drop end

    -- This is when brox is offline
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find(" http://%w+.pnet.ch:7022/brox/info Connection refused: %w+.pnet.ch/[%d.]+:7022")
        then return drop end

    -- [SDCISA-8231] (closed)
    -- Seen  2022-03-10 PROD
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("http://flanian:8080/flanian/vending/twint/v1/pos/register Problem with backend: You must set the Content%-Length header to be the total size of the message body BEFORE sending any data if you are not using HTTP chunked encoding.")
    --    then return drop end
    --if log.file=="Forwarder" and log.level=="WARN"
    --    and log.raw:find("Failed to read upstream response for 'POST /flanian/vending/twint/v1/pos/register'.+java.lang.IllegalStateException: You must set the Content%-Length header to be the total size of the message body BEFORE sending any data if you are not using HTTP chunked encoding.")
    --    then return drop end

    -- [SDCISA-8233]
    -- Seen  2022-03-10 PROD
    --if log.file=="Forwarder" and log.level=="WARN"
    --    and log.msg:find("Failed to 'GET /'")
    --    and log.raw:find("io.netty.channel.ConnectTimeoutException: connection timed out: rms.post.wlan%-partner.com")
    --    then return drop end

    -- This is when lord is offline
    -- Seen 2022-06-20
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find(" http://%w+.pnet.ch:7023/lord/from/vehicles/%d+/vehicle/v1/profile/contact Connection refused: %w+.pnet.ch/[%d.]+:7023")
    --    then return drop end

    -- TODO Analyze
    -- Observed  20014 times within 6 hrs (~1/sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    -- HINT: Eddie connections issues also have around 20000 occurrences. Maybe related?
    -- LastSeen 2021-09-17
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie%d+:7012/from.houston/[^/]+/eagle/[^ ]+ Response already written. Not sure about the state. Closing server connection for stability reason")
        then return drop end

    -- TODO link or create issue
    -- HINT: Occurred 774 times within 6 hrs (~2x/min) (2021-09-17_12:00 to 2021-09-17_18:00)
    -- Seen  2022-06-20 prod
    if log.file=="Utils" and log.level=="ERROR"
        and log.msg:find("Exception occurred\n%(TIMEOUT,%-1%) Timed out after waiting 30000%(ms%) for a reply. address: __vertx.reply.+, repliedAddress: nsync%-register%-sync")
        then return drop end

    -- [SDCISA-9571]
    -- TODO remove this filter
    if log.file=="BisectClient" and log.level=="WARN"
        and log.msg:find("statusCode=503 received for POST /houston/routes/vehicles//eagle/nsync/v1/query-index",0,true)
        then return drop end

    -- TODO Open issues for vehicle putting stuff without vehicleId header
    -- NOT seen  2022-08-30 prod
    --if log.file=="Forwarder" and log.level=="WARN"
    --    and log.msg:find("Problem invoking Header functions: unresolvable '{x-vehicleid}' in expression 'garkbit-vending-data-for-vehicle-{x-vehicleid}'",0,true)
    --    then return drop end
    --if log.file=="Forwarder" and log.level=="WARN"
    --    and log.msg:find("Problem invoking Header functions: unresolvable '{x-vehicleid}' in expression 'garkbit-vending-transaction-data-for-vehicle-{x-vehicleid}'",0,true)
    --    then return drop end

    -- TODO Analyze
    -- HINT: Occurred 1538 times in 6 hrs (~ 1x per 15sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("Failed to '[^ ]+ /from%-houston/%d+/eagle/.+'\n.+VertxException: Connection was closed")
        then return drop end
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie%d+:7012/from%-houston/%d+/eagle/.+ Connection was closed")
        then return drop end

    -- TODO Analyze
    -- FirstSeen 2021-09-17
    -- LastSeen  2022-06-20
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://pag:8080/pag/user/information/v1/directory/sync/request Timeout")
        then return drop end

    -- [SDCISA-9572] pag
    -- TODO drop this filter
    local hosts = "[8acgilmnpsvwy]+" -- (pag|milliways|vlcn8v)
    local ctxts = "[_aegilmopstwy]+" -- (pag|milliways|osm_tiles)
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://"..hosts..":[78]080/"..ctxts.."/.+ Connection was closed")
        then return drop end
    -- Seen  2022-08-30 prod,  2021-10-25
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://"..hosts..":8080/"..ctxts.."/.+ Response already written. Not sure about the state. Closing server connection for stability reason")
        then return drop end

    -- TODO Analyze. Why do OSM tiles timeout?
    -- Seen 2022-06-20 prod, 2021-09-17
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and (  log.msg:find("http://vlcn8v:7080/osm_tiles/%d+/%d+/%d+.png Timeout") -- 2022-06-20
    --        or log.msg:find("http://vlcn8v:7080/osm_tiles/%d+/%d+/%d+.png' Timeout") -- new
    --    )
    --    then return drop end

    -- TODO Analyze.
    -- Seen  2022-06-20, 2021-09-17
    if log.file=="BisectClient" and log.level=="WARN"
        and log.msg:find("statusCode=503 received for POST /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index")
        then return drop end
    -- Seen  2022-06-20 PROD
    if log.file=="BisectClient" and log.level=="WARN"
        and log.msg:find("statusCode=504 received for POST /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index")
        then return drop end

    -- TODO rm filter when fixed
    -- [SDCISA-9573]
    -- Seen  2022-08-30 prod,  2022-06-20,  2021-09-17
    if log.file=="BisectClient" and log.level=="WARN"
        and log.msg:find("Index id=slarti%-vehicle%-setup%-sync%-%d+ rootPath=/houston/from/vehicles/%d+/vehicle/setup/v1 size=%d+ not %(nor no more%) ready. Aborting BisectClient")
        then return drop end

    -- [SDCISA-9574]
    -- TODO rm when resolved
    -- Seen  2022-08-30 prod,  2022-06-20, 2021-09-17
    if log.file=="Utils" and log.level=="ERROR"
        and log.msg:find("Exception occurred\n%(RECIPIENT_FAILURE,500%) Sync failed.\n{.+}")
        then return drop end

    -- TODO Thought timeout? Can happen. But how often is ok?
    local host = "[aghilmostuwy]+" -- (milliways|thought)
    -- HINT: Occurred 15 times in 6 hrs (avg 1x per 24min) (2021-09-17_12:00 to 2021-09-17_18:00)
    -- Seen  2022-08-30 prod,  2022-06-20
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://"..host..":8080/"..host.."/vehicleoperation/recording/v1/.+ Timeout")
        then return drop end

    -- TODO Analyze
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://preflux:8080/preflux/data/preflux/rollout/hosts/eddie%d+/instances/default/situation Timeout")
        then return drop end

    -- TODO Analyze. Why can preflux not handle that?
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("http://preflux:8080/preflux/from/vehicles/%d+/system/status/v1/system/info Timeout")
    --    then return drop end

    -- I guess can happen if backend service not available.
    -- Seen 2021-10-25
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("[^ ]+ [^ ]+ http://[^:]+:8080/[^/]+/info Timeout")
    --    then return drop end

    -- TODO Analyze.
    -- Seen  2022-08-30 prod, 2022-06-20,  2021-09-17
    if log.file=="RedisQues" and log.level=="WARN"
        and log.msg:find("Registration for queue .+ has changed to null")
        then return drop end

    -- TODO Why do we have DNS problems within backend itself?
    -- Seen  2021-09-17
    --if log.file=="Forwarder" and log.level=="WARN"
    --    and log.msg:find("Failed to '[^ ]+ /.+'\n.+SearchDomainUnknownHostException: Search domain query failed. Original hostname: '[^']+' failed to resolve '[^.]+.isa%-houston.svc.cluster.local'")
    --    and log.raw:find("Caused by: .+DnsNameResolverTimeoutException: .+ query timed out after 5000 milliseconds")
    --    then return drop end
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("http://[^:]+:[78]080/[^ ]+ Search domain query failed. Original hostname: '[^']+' failed to resolve '[^.]+.isa%-houston.svc.cluster.local'")
    --    then return drop end

    -- TODO Analyze
    -- HINT: Occurred 3 times in 6 hrs (2021-09-17_12:00 to 2021-09-17_18:00)
    -- Seen 2022-06-20
    --if log.file=="ContextImpl" and log.level=="ERROR"
    --    and log.msg:find("Unhandled exception\njava.lang.UnsupportedOperationException: Do override this method to mock expected behaviour.")
    --    then return drop end

    -- [SDCISA-7189]
    -- Seen  2021-10-21 PROD
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("^[^ ]+ [^ ]+ [^ ]+ Problem with backend: null$")
    --    then return drop end
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and ( log.msg:find("^[^ ]+ [^ ]+ http://rms.post.wlan%-partner.com:80/ Timeout$")
    --        or log.msg:find("^[^ ]+ [^ ]+ http://rms.post.wlan%-partner.com:80/ connection timed out: rms.post.wlan%-partner.com/[^ ]+$")
    --        or log.msg:find("^[^ ]+ [^ ]+ http://rms.post.wlan%-partner.com:80/ Response already written. Not sure about the state. Closing server connection for stability reason$")
    --    ) then return drop end

    -- [SDCISA-7189]
    -- Seen  2022-06-20, 2021-10-21
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    --and ( log.msg:find("^%%[^ ]{4} [^ ]{32} http://localhost:9089/houston/vehicles/[^/]+/vehicle/backup/v1/executions/[^/]+/backup.zip Timeout%s*$")
    --    and ( log.msg:find("^%%[^ ]+ [^ ]+ http://localhost:9089/houston/vehicles/[^/]+/vehicle/backup/v1/executions/[^/]+/backup.zip Timeout%s*$")
    --        or log.msg:find("^%%[^ ]+ [^ ]+ http://localhost:9089/houston/vehicles/[^/]+/vehicle/backup/v1/executions/[^/]+/backup.zip Connection was closed$")
    --        or log.msg:find("^%%[^ ]+ [^ ]+ http://localhost:9089/houston/vehicles/[^/]+/vehicle/backup/v1/executions/[^/]+/backup.zip Response already written. Not sure about the state. Closing server connection for stability reason$")
    --    )
    --    then return drop end
    ---- Seen  2022-06-20
    --if log.file=="FilePutter" and log.level=="ERROR"
    --    and log.msg:find("^Put file failed:\nio.vertx.core.VertxException: Connection was closed$")
    --    then return drop end
    ---- Seen  2022-06-20
    --if log.file=="EventEmitter" and log.level=="ERROR"
    --    and log.msg:find("Exception thrown in event handler.",0,true)
    --    and log.raw:find("java.lang.IllegalStateException: Response is closed\n"
    --        .."\tat io.vertx.core.http.impl.HttpServerResponseImpl.checkValid(HttpServerResponseImpl.java:564)\n"
    --        .."\tat io.vertx.core.http.impl.HttpServerResponseImpl.end(HttpServerResponseImpl.java:324)\n"
    --        .."\tat io.vertx.core.http.impl.HttpServerResponseImpl.end(HttpServerResponseImpl.java:313)\n"
    --        .."\tat org.swisspush.reststorage.RestStorageHandler.respondWith(RestStorageHandler.java:699)\n"
    --        .."\tat org.swisspush.reststorage.RestStorageHandler.lambda$putResource_storeContentsOfDocumentResource$3(RestStorageHandler.java:477)\n"
    --        ,90,true)
    --    then return drop end

    -- Seen  2022-06-20 prod,  2021-10-21 prod
    -- TODO: link (or create) issue
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("^%%[^ ]+ [^ ]+ http://preflux:8080/preflux/preflux/executeTask/host/[^/]+/instance/default/task/DOCKER_PULL .+$")
    --    and (  log.msg:find("/DOCKER_PULL Timeout",120,true)
    --        or log.msg:find("/DOCKER_PULL Connection was closed",120,true)
    --    )
    --    then return drop end

    -- [SDCISA-9578]
    -- TODO rm when fixed
    -- Seen  2022-08-30 prod,  2022-06-20 prod
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find(" http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected .+$")
        and ( false
            or log.msg:find(" Connection reset by peer",100,true)
            or log.msg:find(" Connection was closed",100,true)
            or log.msg:find(" Response already written. Not sure about the state. Closing server connection for stability reason",100,true)
        )
        then return drop end

    -- TODO analyze
    -- Seen  2022-06-20 prod
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find(" http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/timetable/private/v1/trip/state/%w+.xml Connection was closed")
        then return drop end

    -- Seen  2021-10-25
    -- TODO Analyze?
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("[^ ]+ [^ ]+ http://halfrunt:8080/halfrunt/common/metric/v1/vehicles/%d+ Timeout")
    --    then return drop end

    -- Not analyzed yet.
    -- Seen  2021-10-25
    -- NOT Seen  2022-08-30
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("[^ ]+ [^ ]+ http://eddie%d+.pnet.ch:7012/from.houston/%d+/eagle/nsync/v1/push/trillian.phonebooks.affiliated.planning.area.%d.vehicles ")
    --    and (  log.msg:find(" Connection reset by peer",120,true)
    --        or log.msg:find(" Connection was closed",120,true)
    --    )
    --    then return drop end

    -- Gopfrtechu isch ds e schiissig närvegi mäudig!
    -- Seen  2022-06-20 prod, 2021-10-25
    --if log.file=="Forwarder" and log.level=="ERROR"
    --    and log.msg:find("Response already written. Not sure about the state. Closing server connection for stability reason",0,true)
    --    then return drop end

    -- NOT Seen  2022-08-30
    --if (log.file=="Forwarder"and log.level=="WARN")or(log.file=="LocalHttpServerResponse"and log.level=="ERROR")
    --    and log.msg:find("non-proper HttpServerResponse occured",0,0)
    --    --and log.raw:find("java.lang.IllegalStateException: You must set the Content-Length header to be the total size of the message body BEFORE sending any data if you are not using HTTP chunked encoding.\n\tat org.swisspush.gateleen.core.http.LocalHttpServerResponse.write(LocalHttpServerResponse.java:205")
    --    then return drop end

    -- Tyro bullshit. Nothing we could do as tyro is EndOfLife. We have to await his removal.
    -- Seen 2022-06-20
    if log.file=="SlicedLoop" and log.level=="WARN"
        and log.msg:find("Task i=%d+ blocked event%-loop for %d+.%d+ ms.")
        and log.msg:find("SlicedLoop.EventLoopHogException: /houston/deployment/playbook/v1/.expand=4")
        then return drop end

    -- TODO analyze
    -- Seen  2022-06-20
    if log.file=="SlicedLoop" and log.level=="WARN"
        and log.msg:find("Task i=%d+ blocked event%-loop for %d+.%d+ ms.")
        and log.msg:find("SlicedLoop.EventLoopHogException: /houston/from/vehicles/%d+/vehiclelink/status/v1/passengercounting/doors.expand=2")
        then return drop end

    -- TODO analyze
    -- Seen  2022-06-20
    if log.file=="SlicedLoop" and log.level=="WARN"
        and log.msg:find("Task i=%d+ blocked event%-loop for %d+.%d+ ms.")
        and log.msg:find("SlicedLoop.EventLoopHogException: /houston/timetable/notification/v1/planningareas.expand=3")
        then return drop end

    -- TODO analyze
    -- Seen  2022-06-20 prod
    if log.file=="SlicedLoop" and log.level=="WARN"
        and log.msg:find("Task i=%d+ blocked event%-loop for %d+.%d+ ms.")
        and log.msg:find("SlicedLoop.EventLoopHogException: /houston/vehicles/%d+/vehicle/backup/v1/executions.expand=2")
        then return drop end

    -- TODO analyze
    -- Seen  2022-08-30 prod
    if log.file=="SlicedLoop" and log.level=="WARN"
        and log.msg:find("Task i=%d+ blocked event%-loop for %d+.%d+ ms.+EventLoopHogException.+"
            .."/houston/timetable/disruption/v1/areas%?expand=3")
        then return drop end

    -- TODO analyze
    -- Seen  2022-06-20 prod
    --if log.file=="RecursiveRootHandlerBase" and log.level=="ERROR"
    --    and log.msg:find("Error in result of sub resource 'listeners' Message: Failed to decode: Unrecognized token 'Forbidden': was expecting %(JSON String, Number, Array, Object or token 'null', 'true' or 'false'%)")
    --    then return drop end

    -- TODO create issue
    -- Seen  2022-08-30 prod,  2022-06-20 prod
    if log.file=="ConnectionBase" and log.level=="ERROR"
        and log.msg:find("invalid version format: {")
        then return drop end

    -- TODO Analyze
    -- Seen  2022-08-30 prod
    if log.file=="NSyncVerticle" and log.level=="ERROR"
        and log.msg:find("Response%-Exception occurred while placing hook for Index"
            .." id=[^ ]+"
            .." rootPath=/houston/[cnosty]+/vehicles/%d+/[^ ]+ size=%d+.+VertxException.+ Connection was closed")
        then return drop end

    -- TODO Analyze
    -- Seen  2022-08-30 prod
    if log.file=="HandlerRegistration" and log.level=="ERROR"
        and log.msg:find("Failed to handleMessage. address: __vertx.reply.%d+.+IllegalStateException:"
            .." Response is closed")
        then return drop end

    -- Yet another bullshit msg
    -- Seen  2022-08-30 prod
    if log.file=="ContextImpl" and log.level=="ERROR"
        and log.msg:find("Unhandled exception.+IllegalStateException: Response is closed")
        then return drop end

    return pass
end


-- Reject all the stuff which I consider to be useless noise.
function mod.isUselessNoise( that, log )
    local pass, drop = false, true

    -- Looks pretty useless as provided ways too few details
    -- HINT: Occurred 4 times in 6 hrs (2021-09-17_12:00 to 2021-09-17_18:00)
    -- Seen  2022-08-30 prod,  2022-06-20
    if log.file=="ConnectionBase" and log.level=="ERROR"
        and log.msg:find("Connection reset by peer",0,true)
        then return drop end

    -- Connection timeout because eddie offline
    -- HINT: (EachOfTheThree) Occurred ~20000 times in 6 hrs (avg 1x per 1sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("Failed to '[^ ]+ /from%-houston/.+ConnectTimeoutException: connection timed out: eddie")
        then return drop end
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie.+:7012/from.houston/.+/eagle/.+connection timed out: eddie.+")
        then return drop end
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie[0-9]+:7012/from.houston/.+/eagle/.+ Timeout")
        then return drop end
    if log.file=="Forwarder" and log.level=="WARN"
        then return drop end

    -- Connection reset/refused because eddie offline
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("Failed to '[^ ]+ /from%-houston/%d+/eagle/.+'\n.+AnnotatedConnectException: Connection refused: eddie%d+.+:7012")
        then return drop end
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie%d+:7012/from%-houston/%d+/eagle/.+ Connection refused: eddie%d+.+:7012")
        then return drop end
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("Failed to '[^ ]+ /from%-houston/%d+/eagle/.+'\njava.io.IOException: Connection reset by peer")
        then return drop end
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie%d+:7012/from%-houston/%d+/eagle/.+ Connection reset by peer")
        then return drop end

    -- Yet another EddieNotReachable (!!FATAL!!) error ...
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find(" Connection refused: eddie",0,true)
        then return drop end

    -- Connection Close because eddie offline
    if log.file=="BisectClient" and log.level=="ERROR"
        and log.msg:find("Exception occurred for POST%-request /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index\n.+VertxException: Connection was closed")
        then return drop end

    -- DNS crap for offline eddies
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("http://eddie%d+:7012/from%-houston/%d+/eagle/.+\n.+ Search domain query failed. Original hostname: 'eddie%d+' failed to resolve 'eddie%d+%.isa%-houston%.svc%.cluster%.local'")
        then return drop end
    -- HINT: Occurred 8219 times in 6 hrs (avg 1x per 2.5sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie%d+:7012/from%-houston/%d+/eagle/.+ Search domain query failed. Original hostname: 'eddie%d+' failed to resolve 'eddie%d+")
        then return drop end
    -- HINT: Occurred 781 times in 6 hrs (avg _x per _sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("Failed to '[^ ]+ /from.houston/%d+/eagle/.+\n.+SearchDomainUnknownHostException: Search domain query failed. Original hostname: 'eddie%d+' failed to resolve 'eddie%d+")
        and log.raw:find("Caused by: .+DnsNameResolverTimeoutException: .+ query timed out after 5000 milliseconds")
        then return drop end
    -- Seen  2022-06-20 prod, 2021-10-25
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find(" http://%w+:7012/from%-houston/%d+/eagle/nsync/v1/push/.+ Search domain query failed. Original hostname: 'eddie[^']+' failed to resolve 'eddie[%w.-]+'")
        then return drop end
    -- Occurred 1 times in 6 hrs (avg _x per _sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("Failed to '[^ ]+ /from%-houston/%d+/eagle/.+'\n.+UnknownHostException: failed to resolve 'eddie%d+' after %d+ queries")
        then return drop end
    -- Occurred 1 times in 6 hrs (avg _x per _sec) (2021-09-17_12:00 to 2021-09-17_18:00)
    -- Seen  2022-06-20 prod
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://eddie%d+:7012/from%-houston/%d+/eagle/[^ ]+ failed to resolve 'eddie%d+' after %d+ queries")
        then return drop end

    -- Some Strange connection limit for Trin
    if log.file=="Forwarder" and log.level=="ERROR"
        and log.msg:find("http://trin:8080/trin/from/vehicles/%d+/[^ ]+ Connection pool reached max wait queue size of")
        then return drop end
    if log.file=="Forwarder" and log.level=="WARN"
        and log.msg:find("^Failed to 'PUT /trin/from/vehicles/[^ ]+'%s+io.vertx.core.http.ConnectionPoolTooBusyException: Connection pool reached max wait queue size of %d+")
        then return drop end

    -- No idea what this msg should tell us. Has no details at all.
    -- Seen  2022-08-30 prod
    if log.file=="HttpClientRequestImpl" and log.level=="ERROR"
        and log.msg:find("VertxException: Connection was closed", 0, true)
        then return drop end

    return pass
end


function mod.debugPrintLogEntry( that, log )
    if that.printRaw then
        print( log.raw );
    else
        log:debugPrint()
    end
end


mod.main()

