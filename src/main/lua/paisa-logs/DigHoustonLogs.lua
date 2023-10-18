#!/usr/bin/env lua
--[====================================================================[

  projDir='C:\path\to\proj\root'
  export LUA_PATH="${projDir:?}/src/main/lua/paisa-logs/?.lua"
  lua -W "${projDir:?}/src/main/lua/paisa-logs/DigHoustonLogs.lua"

  ]====================================================================]

local PaisaLogParser = require("PaisaLogParser")
local normalizeIsoDateTime = require("PaisaLogParser").normalizeIsoDateTime

local main, onLogEntry, isWorthToPrint, loadFilters, initFilters


local function main()
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


local function loadFilters( that )
    assert(not that.filters)
    that.filters = {

        { action = "drop", beforeDate = "2023-10-18 03:00:00.000" },
        { action = "drop", afterDate  = "2023-10-18 15:00:00.000" },

        { action = "drop", level = "TRACE" },
        { action = "drop", level = "DEBUG" },
        { action = "drop", level = "INFO" },

        ---- [SDCISA-9572] pag
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://[8acgilmnpsvwy]+:[78]080/[_aegilmopstwy]+/.+ Connection was closed", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "t.ch:7022/brox/from/vehicles/.+Connection refused: ", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = " http://%w+.pnet.ch:7022/brox/info Connection refused: %w+.pnet.ch/[%d.]+:7022" },

        ---- TODO Analyze
        ---- Observed  20014 times within 6 hrs (~1/sec) (2021-09-17_12:00 to 2021-09-17_18:00)
        ---- HINT: Eddie connections issues also have around 20000 occurrences. Maybe related?
        ---- Seen:  2021-09-17
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://eddie%d+:7012/from.houston/[^/]+/eagle/[^ ]+ Response already written. Not sure about the"
        --           .." state. Closing server connection for stability reason", },

        ---- TODO link or create issue
        ---- HINT:  Occurred 774 times within 6 hrs (~2x/min) (2021-09-17_12:00 to 2021-09-17_18:00)
        ---- Seen:  2022-06-20 prod
        --{ action = "drop", file = "Utils", level = "ERROR",
        --    msgPat = "Exception occurred\n%(TIMEOUT,%-1%) Timed out after waiting 30000%(ms%) for a reply. address:"
        --           .." __vertx.reply.+, repliedAddress: nsync%-register%-sync", },

        ---- TODO Analyze
        ---- HINT: Occurred 1538 times in 6 hrs (~ 1x per 15sec) (2021-09-17_12:00 to 2021-09-17_18:00)
        --{ action = "drop", file = "Forwarder", level = "WARN",
        --    msgPat = "Failed to '[^ ]+ /from%-houston/%d+/eagle/.+'\n.+VertxException: Connection was closed", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://eddie%d+:7012/from%-houston/%d+/eagle/.+ Connection was closed", },

        ---- TODO Analyze
        ---- Seen:  2021-09-17, ..., 2022-06-20
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://pag:8080/pag/user/information/v1/directory/sync/request Timeout", },

        ---- Seen  2021-10-25, 2022-08-30 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://[8acgilmnpsvwy]+:8080/[_aegilmopstwy]+/.+ Response already written. Not sure about the"
        --           .." state. Closing server connection for stability reason", },

        ---- TODO Analyze.
        ---- Seen  2021-09-17, 2022-06-20
        --{ action = "drop", file = "BisectClient", level = "WARN",
        --    msgPat = "statusCode=503 received for POST /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index", },
        ---- Seen  2022-06-20 prod
        --{ action = "drop", file = "BisectClient", level = "WARN",
        --    msgPat = "statusCode=504 received for POST /houston/routes/vehicles/%d+/eagle/nsync/v1/query%-index", },
        ---- TODO rm filter when fixed
        ---- Reported:  SDCISA-9573
        ---- Seen:  2022-08-30 prod,  2022-06-20,  2021-09-17
        --{ action = "drop", file = "BisectClient", level = "WARN",
        --    msgPat = "Index id=slarti%-vehicle%-setup%-sync%-%d+ rootPath=/houston/from/vehicles/%d+/vehicle/setup/v1 size=%d+ not %(nor no more%) ready. Aborting BisectClient", },

        ---- TODO Thought timeout? Can happen. But how often is ok?
        ---- HINT: Occurred 15 times in 6 hrs (avg 1x per 24min) (2021-09-17_12:00 to 2021-09-17_18:00)
        ---- Seen  2022-06-20, 2022-08-30 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://[aghilmostuwy]+:8080/[aghilmostuwy]+/vehicleoperation/recording/v1/.+ Timeout", },

        ---- Reported:  SDCISA-9574
        ---- TODO rm when resolved
        ---- Seen:  2021-09-17 2022-06-20, 2022-08-30 prod,
        --{ action = "drop", file = "Utils", level = "ERROR",
        --    msgPat = "Exception occurred\n%(RECIPIENT_FAILURE,500%) Sync failed.\n{.+}", },

        ---- TODO Analyze
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "http://preflux:8080/preflux/data/preflux/rollout/hosts/eddie%d+/instances/default/situation Timeout", },

        ---- TODO Analyze.
        ---- Seen  2022-08-30 prod, 2022-06-20,  2021-09-17
        --{ action = "drop", file = "RedisQues", level = "WARN",
        --    msgPat = "Registration for queue .+ has changed to null", },

        ---- Reported: SDCISA-10973
        ---- Seen:  2023-10-18 prod.
        --{ action = "drop", file = "HttpClientRequestImpl", level = "ERROR",
        --    msgPat = "The timeout period of 30000ms has been exceeded while executing PUT /houston/vehicles/[0-9]+"
        --           .."/vehicle/backup/v1/executions/[0-9]+/backup.zip for server localhost:9089", },

        ---- Reported:  TODO
        ---- Seen:  2023-10-18 prod.
        --{ action = "drop", file = "Utils", level = "ERROR",
        --    msgPat = "Exception occurred\nio.vertx.core.eventbus.ReplyException: Timed out after waiting 30000%(ms%) for"
        --           .." a reply. address: __vertx.reply.[0-9]+, repliedAddress: nsync%-re", },

        ---- Seen:  2023-10-18 prod
        --{ action = "drop", file = "HttpHeaderUtil", level = "ERROR",
        --    msgPat = "Keep%-Alive%} values do not match timeout=42 != timeout=120 for request /googleplex/internal/security/login_state", },

        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = "[%a-z0-9]+ [a-z0-9]+ http://eddie.....:7012/from%-houston/[^/]+/eagle/nsync/v1/push/trillian"
        --           .."%-phonebooks%-affiliated%-planning%-area%-[^-]+%-vehicles The timeout period of 30000ms has been"
        --           .." exceeded while executing POST /from%-houston/[0-9]+/eagle/nsync/v1/push/trillian%-phonebooks"
        --           .."%-affiliated%-planning%-area%-[^%-]+-vehicles for server eddie.....:7012", },

        ---- Reported: SDCISA-9578
        ---- TODO rm when fixed
        ---- Seen  2022-08-30 prod,  2022-06-20 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected"
        --           .." Connection reset by peer", },
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected"
        --           .." Connection was closed", },
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/navigation/location/v1/position/collected"
        --           .." Response already written. Not sure about the state. Closing server connection for stability reason", },

        ---- TODO analyze
        ---- Seen  2022-06-20 prod
        --{ action = "drop", file = "Forwarder", level = "ERROR",
        --    msgPat = " http://vhfspa1.pnet.ch:7022/brox/from/vehicles/[^/]+/timetable/private/v1/trip/state/%w+.xml Connection was closed", },

    }
end


local function initFilters( that )
    for iF = 1, #(that.filters) do
        local descr = that.filters[iF]
        local beforeDate, afterDate = descr.beforeDate, descr.afterDate
        local file, level, msgPat = descr.file, descr.level, descr.msgPat
        local filter = { action = descr.action, matches = false, }
        filter.matches = function( that, log )
            if file and file ~= log.file then return false end
            if level and level ~= log.level then return false end
            local logDate = normalizeIsoDateTime(log.date)
            if logDate <  beforeDate then return false end
            if logDate >= afterDate then return false end
            if msgPat and not log.msg:find(msgPat) then return false end
            return true
        end
        that.filters[iF] = filter
    end
end


local function onLogEntry( log, that )
    if isWorthToPrint(that, log) then
        if that.printRaw then
            print(log.raw)
        else
            log:debugPrint()
        end
    end
end


local function isWorthToPrint( that, log )
    local pass, drop = true, false
    -- Time range
    local begDate, endDate = that.begDate, that.endDate
    if begDate or endDate then
        local date = normalizeIsoDateTime(log.date)
        if begDate and date <= begDate then return drop end
        if endDate and date >  endDate then return drop end
    end
    -- log level
    local skipLevels = that.skipLevels
    if skipLevels and skipLevels[log.level:upper()] then return drop end
    -- dynamic filters
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

