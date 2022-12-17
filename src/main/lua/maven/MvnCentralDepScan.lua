--[====================================================================[

  Initially written using scriptlee 0.0.5-46-G .

  ]====================================================================]

local AF_INET = require('scriptlee').posix.AF_INET
local AF_INET6 = require('scriptlee').posix.AF_INET6
local IPPROTO_TCP = require('scriptlee').posix.IPPROTO_TCP
local SOCK_STREAM = require('scriptlee').posix.SOCK_STREAM
--local async = require("scriptlee").reactor.async
local inaddrOfHostname = require('scriptlee').posix.inaddrOfHostname
--local newCond = require("scriptlee").posix.newCond  -- cannot use. Too buggy :(
local newHttpClient = require("scriptlee").newHttpClient
local newSqlite = require("scriptlee").newSqlite
local newTlsClient = assert(require("scriptlee").newTlsClient)
local newXmlParser = require("scriptlee").newXmlParser
local objectSeal = require("scriptlee").objectSeal
local sleep = require("scriptlee").posix.sleep
local socket = require('scriptlee').posix.socket
local startOrExecute = require("scriptlee").reactor.startOrExecute

local out, log = io.stdout, io.stderr
local mod = {}


function mod.printHelp()
    out:write("\n"
        .."  Collecting dependency information by scanning maven poms\n"
        .."\n"
        .."  Options:\n"
        .."\n"
        .."    --example\n"
        .."      WARN: only use if you know what you're doing!\n"
        .."\n"
        .."    --state <path>\n"
        .."      Data file to use for the action.\n"
        .."\n"
        .."    --asCsv <what>\n"
        .."      Prints requested data to stdout. <what> can be one of \"parents\"\n"
        .."      or \"deps\".\n"
        .."\n"
        .."    --nullvalue <str>  (default is an empty string)\n"
        .."      The string to use for NULL values in CSV exports.\n"
        .."\n"
        .."  Example  \"Export parents\"\n"
        .."\n"
        .."    --state foo --asCsv parents > parents.csv\n"
        .."\n"
        .."  Example  \"Export dependencies\"\n"
        .."\n"
        .."    --state foo --asCsv deps > dependencies.csv\n"
        .."\n")
end


function mod.parseArgs( app )
    local iA = 0
    app.isExample = false
    app.statePath = false
    app.nullvalue = ""
    while true do
        iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--help" then
            mod.printHelp() return -1
        elseif arg == "--example" then
            app.isExample = true
        elseif arg == "--state" then
            iA = iA + 1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --sqliteOut needs value\n")return-1 end
            app.statePath = arg
        elseif arg == "--asCsv" then
            iA = iA +1
            arg = _ENV.arg[iA]
            if arg ~= "parents" and arg ~= "deps" then
                log:write("Illegal value for --asCsv: "..tostring(arg).."\n")return-1 end
            app.asCsv = arg
        elseif arg == "--nullvalue" then
            iA = iA +1
            arg = _ENV.arg[iA]
            if not arg then log:write("Arg --nullvalue needs value\n")return-1 end
            app.nullvalue = arg
        else
            log:write("Unexpected arg: "..tostring(arg).."\n")return -1
        end
    end
    if not app.statePath then log:write("Arg --state missing\n") return -1 end
    if not app.isExample and not app.asCsv then log:write("Bad Args\n") return -1 end
    return 0
end


function mod.newMvnArtifact()
    return objectSeal{
        dbId = false,
        parentGroupId = false,
        parentArtifactId = false,
        parentVersion = false,
        groupId = false,
        artifactId = false,
        version = false,
    }
end


function mod.newMvnDependency()
    return objectSeal{
        dbId = false,
        groupId = false,
        artifactId = false,
        version = false,
    }
end


function mod.newPomUrlSrc( app )
    local t = objectSeal{
        fileWithLfSeparatedUrls = "tmp/isa-poms.list.short",
        fd = false,
    }
    local m = {
        nextPomUrl = function( t )
            if not t.fd then
                t.fd = io.open(t.fileWithLfSeparatedUrls, "rb")
                if not t.fd then error("fopen("..tostring(t.fileWithLfSeparatedUrls)..")") end
            end
            local line = t.fd:read("l") -- lowerCase means TrimEol
            if not line then io.close(t.fd) t.fd = false end
            return line
        end,
        __index = false,
    }
    m.__index = m
    return setmetatable(t, m)
end


function mod.processXmlValue( pomParser )
    local app = pomParser.app
    local xpath = ""
    for i, stackElem in ipairs(pomParser.xmlElemStack) do
        xpath = xpath .."/".. stackElem.tag
    end
    --log:write(xpath .."\n")
    local mvnArtifact = pomParser.mvnArtifact
    if false then
    elseif xpath == "/project/parent/artifactId" then
        mvnArtifact.parentArtifactId = pomParser.currentValue
    elseif xpath == "/project/parent/groupId" then
        mvnArtifact.parentGroupId = pomParser.currentValue
    elseif xpath == "/project/parent/version" then
        mvnArtifact.parentVersion = pomParser.currentValue
    elseif xpath == "/project/groupId" then
        mvnArtifact.groupId = pomParser.currentValue
    elseif xpath == "/project/artifactId" then
        mvnArtifact.artifactId = pomParser.currentValue
    elseif xpath == "/project/version" then
        mvnArtifact.version = pomParser.currentValue
    elseif xpath == "/project/dependencies/dependency/groupId" then
        if not pomParser.mvnDependency then pomParser.mvnDependency = mod.newMvnDependency() end
        pomParser.mvnDependency.groupId = pomParser.currentValue
    elseif xpath == "/project/dependencies/dependency/artifactId" then
        if not pomParser.mvnDependency then pomParser.mvnDependency = mod.newMvnDependency() end
        pomParser.mvnDependency.artifactId = pomParser.currentValue
    elseif xpath == "/project/dependencies/dependency/version" then
        if not pomParser.mvnDependency then pomParser.mvnDependency = mod.newMvnDependency() end
        pomParser.mvnDependency.version = pomParser.currentValue
    elseif xpath == "/project/dependencies/dependency" then
        assert(pomParser.mvnDependency)
        local mvnArtifact = pomParser.mvnArtifact
        local mvnDependency = pomParser.mvnDependency
        pomParser.mvnDependency = false
        local deps = app.mvnDepsByArtifact[mvnArtifact]
        if not deps then deps = {} app.mvnDepsByArtifact[mvnArtifact] = deps end
        table.insert(deps, assert(mvnDependency))
    elseif xpath == "/project/dependencyManagement/dependencies/dependency/groupId" then
        if not pomParser.mvnMngdDependency then pomParser.mvnMngdDependency = mod.newMvnDependency() end
        pomParser.mvnMngdDependency.groupId = pomParser.currentValue
    elseif xpath == "/project/dependencyManagement/dependencies/dependency/artifactId" then
        if not pomParser.mvnMngdDependency then pomParser.mvnMngdDependency = mod.newMvnDependency() end
        pomParser.mvnMngdDependency.artifactId = pomParser.currentValue
    elseif xpath == "/project/dependencyManagement/dependencies/dependency/version" then
        if not pomParser.mvnMngdDependency then pomParser.mvnMngdDependency = mod.newMvnDependency() end
        pomParser.mvnMngdDependency.version = pomParser.currentValue
    elseif xpath == "/project/dependencyManagement/dependencies/dependency" then
        assert(pomParser.mvnMngdDependency)
        local mvnArtifact = pomParser.mvnArtifact
        local mvnMngdDependency = pomParser.mvnMngdDependency
        pomParser.mvnMngdDependency = false
        local mngdDeps = app.mvnMngdDepsByArtifact[mvnArtifact]
        if not mngdDeps then mngdDeps = {} app.mvnMngdDepsByArtifact[mvnArtifact] = mngdDeps end
        table.insert(mngdDeps, assert(mvnMngdDependency))
    elseif xpath:find("^/project/properties/[^/]+$") then
        local propKey = xpath:match("^/project/properties/([^/]+)$")
        local propVal = pomParser.currentValue or ""
        local mvnProps = app.mvnPropsByArtifact[mvnArtifact]
        if not mvnProps then mvnProps = {} app.mvnPropsByArtifact[mvnArtifact] = mvnProps end
        table.insert(mvnProps, objectSeal{
            key = assert(propKey),
            val = assert(propVal),
        })
    end
end


function mod.getMvnArtifactKey( mvnArtifact )
    assert(mvnArtifact.artifactId)
    assert(mvnArtifact.groupId)
    assert(mvnArtifact.version)
    return       mvnArtifact.groupId
        .."\t".. mvnArtifact.artifactId
        .."\t".. mvnArtifact.version
end


function mod.onGetPomRspHdr( msg, req )
    if msg.status ~= 200 then
        log:write("< "..tostring(msg.proto) .." "..tostring(msg.status).." "..tostring(msg.phrase).."\n")
        for i, h in ipairs(msg.headers) do
            log:write("< ".. h.key ..": ".. h.val .."\n")
        end
        log:write("< \n")
        error("Unexpected HTTP ".. tostring(msg.status))
    end
    assert(not req.pomParser)
    req.pomParser = objectSeal{
        write = function( t, buf ) t.base:write(buf) end,
        closeSnk = function( t, buf ) t.base:closeSnk() end,
    }
    req.pomParser.base = newXmlParser{
        cls = req.pomParser,
        onElementBeg = function( tag, pomParser )
            table.insert(pomParser.xmlElemStack, { tag = tag, })
            pomParser.currentValue = false
        end,
        onElementEnd = function( tag, pomParser )
            mod.processXmlValue(pomParser)
            local elem = table.remove(pomParser.xmlElemStack)
            assert(elem.tag == tag);
        end,
        onChunk = function( buf, pomParser )
            if pomParser.currentValue then
                pomParser.currentValue = pomParser.currentValue .. buf
            else
                pomParser.currentValue = buf
            end
        end,
        onEnd = function( pomParser )
            assert(#pomParser.xmlElemStack == 0)
            local req = pomParser.req
            local app = req.app
            local mvnArtifact = pomParser.mvnArtifact
            pomParser.mvnArtifact = false
            if not mvnArtifact.groupId then mvnArtifact.groupId = mvnArtifact.parentGroupId end
            if not mvnArtifact.version then mvnArtifact.version = mvnArtifact.parentVersion end
            local key = mod.getMvnArtifactKey(mvnArtifact)
            if app.mvnArtifacts[key] then
                local old = app.mvnArtifacts[key]
                local oId = mod.getMvnArtifactKey(old)
                local nId = mod.getMvnArtifactKey(mvnArtifact)
                if oId ~= nId then
                    print("Already exists BUT DIFFERS:")
                    for k,v in pairs(old) do print("O",k,v) end
                    print()
                    for k,v in pairs(mvnArtifact) do print("N",k,v) end
                    error("TODO_20221215150040")
                else
                    log:write("Already known. ReUse "..tostring(oId).."\n")
                end
            else
                app.mvnArtifacts[key] = mvnArtifact
            end
        end,
    }
end


function mod.resolveDependencyVersionsFromDepsMgmnt( app )
    local mvnArtifacts = app.mvnArtifacts
    local mvnDepsByArtifact = app.mvnDepsByArtifact
    local mvnMngdDepsByArtifact = app.mvnMngdDepsByArtifact
    local funcs = {}
    function funcs.resolveForDependency( mvnArtifact, mvnDependency )
        if mvnDependency.version then return end
        local mngdDeps = mvnMngdDepsByArtifact[mvnArtifact]
        if not mngdDeps then return end
        for _, mngdDep in pairs(mngdDeps) do
            if  mvnDependency.groupId == mngdDep.groupId
            and mvnDependency.artifactId == mngdDep.artifactId
            then
                mvnDependency.version = assert(mngdDep.version);
                break
            end
        end
        local hasParent = (mvnArtifact.parentArtifactId)
        if not mvnDependency.version and hasParent then
            -- Cannot resolve. Delegate to parent.
            local parent = mvnArtifacts[mod.getMvnArtifactKey{
                groupId = mvnArtifact.parentGroupId,
                artifactId = mvnArtifact.parentArtifactId,
                version = mvnArtifact.parentVersion,
            }];
            if parent then
                funcs.resolveForDependency(parent, mvnDependency)
            end
        end
    end
    function funcs.resolveForArtifact( mvnArtifact )
        local mvnDeps = mvnDepsByArtifact[mvnArtifact]
        if not mvnDeps then return end
        if not mvnMngdDepsByArtifact[mvnArtifact] then return end
        for _, mvnDependency in pairs(mvnDeps) do
            funcs.resolveForDependency(mvnArtifact, mvnDependency)
        end
    end
    for _, mvnArtifact in pairs(mvnArtifacts) do
        funcs.resolveForArtifact(mvnArtifact)
    end
end


function mod.resolveProperties( app )
    local mvnArtifacts = app.mvnArtifacts
    local mvnPropsByArtifact = app.mvnPropsByArtifact
    local mvnDepsByArtifact = app.mvnDepsByArtifact
    local mvnMngdDepsByArtifact = app.mvnMngdDepsByArtifact
    local getPropKey = function( str )
        if not str then return nil end
        return str:match("^%$%{([^}]+)%}$")
    end
    for _, mvnArtifact in pairs(mvnArtifacts) do
        local set = nil
        local depsToEnrich = {}
        set = mvnDepsByArtifact[mvnArtifact]
        if set then for _, d in pairs(set) do
            table.insert(depsToEnrich, d) end end
        set = mvnMngdDepsByArtifact[mvnArtifact]
        if set then for _, d in pairs(set) do
            table.insert(depsToEnrich, d) end end
        for _, mvnDependency in pairs(depsToEnrich) do
            local propKey = getPropKey(mvnDependency.version)
            if propKey then
                local propVal = mod.getPropValThroughParentChain(app, mvnArtifact, propKey)
                if propVal then
                    mvnDependency.version = propVal
                end
            end
        end
        local mngdDeps = mvnMngdDepsByArtifact[mvnArtifact]
    end
end


function mod.getPropValThroughParentChain( app, mvnArtifact, propKey, none )
    assert(app and mvnArtifact and propKey and not none);
    local mvnArtifacts = app.mvnArtifacts
    local mvnProps = app.mvnPropsByArtifact[mvnArtifact]
    local propVal, parent
    if mvnProps then
        for _, mvnProp in ipairs(mvnProps) do
            if propKey == mvnProp.key then
                return mvnProp.val
            end
        end
    end
    if propKey == "project.version" then
        return mvnArtifact.version
    end
    if propKey == "project.groupId" then
        return mvnArtifact.groupId
    end
    -- no luck in current artifact. Delegate to parent (if any)
    if  mvnArtifact.parentGroupId
    and mvnArtifact.parentArtifactId
    and mvnArtifact.parentVersion
    then
        parent = mvnArtifacts[mod.getMvnArtifactKey{
            groupId = mvnArtifact.parentGroupId,
            artifactId = mvnArtifact.parentArtifactId,
            version = mvnArtifact.parentVersion,
        }]
    end
    if not parent then
        log:write("[INFO ] Cannot resolve ${"..propKey.."}\n")
        return nil
    end
    return mod.getPropValThroughParentChain(app, parent, propKey)
end


function mod.printStuffAtEnd( app )
    local mvnArtifacts = {}
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        table.insert(mvnArtifacts, mvnArtifact)
    end
    table.sort(mvnArtifacts, function( a, b )
        local na, nb = (a.groupId or""), (b.groupId or"")
        if na ~= nb then return na < nb end
        na, nb = (a.artifactId or""), (b.artifactId or"")
        if na ~= nb then return na < nb end
        na, nb = (a.version or""), (b.version or"")
        if na ~= nb then return na < nb end
        return false
    end)
    for _, mvnArtifact in ipairs(mvnArtifacts) do
        log:write("ARTIFACT  "..tostring(mvnArtifact.groupId)
            .."  "..tostring(mvnArtifact.artifactId)
            .."  "..tostring(mvnArtifact.version).."\n")
        log:write("  PARENT  ".. tostring(mvnArtifact.parentGroupId)
            .."  ".. tostring(mvnArtifact.parentArtifactId)
            .."  ".. tostring(mvnArtifact.parentVersion) .."\n")
        local deps = app.mvnDepsByArtifact[mvnArtifact]
        local mvnProps = app.mvnPropsByArtifact[mvnArtifact]
        --if mvnProps then for _, mvnProp in pairs(mvnProps) do
        --    log:write("  PROP  ".. mvnProp.key .."=".. mvnProp.val .."\n")
        --end end
        if deps then for _, mvnDependency in pairs(deps) do
            log:write("  DEP  ".. mvnDependency.artifactId .."  "..tostring(mvnDependency.version).."\n")
        end end
    end
end


function mod.loadFromSqliteFile( app )
    local db = mod.dbGetInstance(app)
    local queryStr = "SELECT id, str FROM String"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    local strings = app.stringIdByStr
    -- Load stings
    local rs = stmt:execute()
    while rs:next() do
        local stringKey, stringVal
        for iCol=1, rs:numCols() do
            local colName = rs:name(iCol)
            if colName == "id" then
                assert(rs:type(iCol) == "INTEGER")
                stringKey = rs:value(iCol)
            elseif colName == "str" then
                assert(rs:type(iCol) == "TEXT")
                stringVal = rs:value(iCol)
            else
                error("Unexpected col String."..tostring(rs:name(iCol)))
            end
        end
        assert(stringKey)
        assert(stringVal)
        app.stringIdByStr[stringKey] = stringVal
    end
    -- Load Artifacts
    local stmtMvnArtifacts = db:prepare(""
        .." SELECT id, groupId, artifactId, version, parentGroupId, parentArtifactId, parentVersion"
        .." FROM MvnArtifact")
    local mvnArtifactsByDbId = {}
    local rs = stmtMvnArtifacts:execute()
    assert(not app.mvnArtifacts)
    app.mvnArtifacts = {}
    while rs:next() do
        local mvnArtif = mod.newMvnArtifact()
        for iCol=1, rs:numCols() do
            local colName = rs:name(iCol)
            if colName == "id" then
                mvnArtif.dbId = rs:value(iCol)
            else
                mvnArtif[colName] = (strings[rs:value(iCol)] or false)
            end
        end
        app.mvnArtifacts[mod.getMvnArtifactKey(mvnArtif)] = mvnArtif;
        assert(type(mvnArtif.dbId) == "number", mvnArtif.dbId)
        mvnArtifactsByDbId[mvnArtif.dbId] = mvnArtif
    end
    -- Load Dependencies
    local stmtMvnDeps = db:prepare(""
        .." SELECT id, mvnArtifactId, needsMvnArtifactId"
        .." FROM MvnDependency")
    local rs = stmtMvnDeps:execute()
    while rs:next() do
        local mvnDep = mod.newMvnDependency()
        local mvnArtifId, mvnDepId
        for iCol=1, rs:numCols() do
            local colName = rs:name(iCol)
            if colName == "id" then
                mvnDep.dbId = assert(rs:value(iCol))
            elseif colName == "mvnArtifactId" then
                mvnArtifId = assert(rs:value(iCol))
            elseif colName == "needsMvnArtifactId" then
                mvnDepId = assert(rs:value(iCol))
            else
                error("TODO_20221215134407 ".. colName)
            end
        end
        local artif = mvnArtifactsByDbId[mvnArtifId]
        local dep = mvnArtifactsByDbId[mvnDepId]
        assert(type(dep) == "table")
        local deps = app.mvnDepsByArtifact[artif]
        if not deps then deps = {} app.mvnDepsByArtifact[artif] = deps end
        table.insert(deps, dep)
    end
end


function mod.dbInsertMvnArtifact( app, mvnArtifact )
    if mvnArtifact.dbId then warn("MvnArtifact already has dbId="..tostring(mvnArtifact.dbId)) end
    local db = mod.dbGetInstance(app)
    local queryStr = "INSERT INTO MvnArtifact"
        .."    groupId,  artifactId,  version,  parentGroupId,  parentArtifactId,  parentVersion"
        .." VALUES"
        .."   :groupId, :artifactId, :version, :parentGroupId, :parentArtifactId, :parentVersion"
        .." "
    local stmt = app.preparedStmts[queryStr]
    if not stmt then
        stmt = db:prepare(queryStr)
        app.preparedStmts[queryStr] = stmt
    end
    stmt:reset()
    mod.bindMvnArtifactAll(app, stmt, mvnArtifact)
    stmt:execute()
    if db:lastInsertRowid() ~= 0 then
        return db:lastInsertRowid()
    end
    local queryStr = "SELECT id FROM MvnArtifact"
        .." WHERE artifactId = :artifactId"
        .." AND groupId = :groupId"
        .." AND version = :version"
        .." AND parentGroupId = :parentGroupId"
        .." AND parentArtifactId = :parentArtifactId"
        .." AND parentVersion = :parentVersion"
    local stmt = app.preparedStmts[queryStr]
    stmt:reset()
    mod.bindMvnArtifactAll(app, stmt, mvnArtifact)
    local rs = stmt:execute()
    if not rs:next() then error("TODO_20221215172430") end
    mvnArtifact.dbId = assert(rs:value(1))
    if rs:next() then error("TODO_20221215172435") end
end


function mod.dbBindMvnArtifactAll( app, stmt, mvnArtifact )
    stmt:bind(":groupId", mvnArtifact.groupId)
    stmt:bind(":artifactId", mvnArtifact.artifactId)
    stmt:bind(":version", mvnArtifact.version)
    stmt:bind(":parentGroupId", mvnArtifact.parentGroupId)
    stmt:bind(":parentArtifactId", mvnArtifact.parentArtifactId)
    stmt:bind(":parentVersion", mvnArtifact.parentVersion)
end


function mod.storeAsSqliteFile( app )
    local stmt
    local db = mod.dbGetInstance(app)
    local mvnArtifactIds = {}
    local mvnArtifactIdsByArtif = {}
    local strings = {}
    mod.dbInitTables(app)
    local queryStr = "INSERT INTO MvnArtifact"
        .."   ('groupId', 'artifactId', 'version', 'parentGroupId', 'parentArtifactId', 'parentVersion')"
        .." VALUES"
        .."   (:groupId , :artifactId , :version , :parentGroupId , :parentArtifactId , :parentVersion )"
        .." ON CONFLICT DO NOTHING"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    local insertMvnArtifact = function(a)
        if a.dbId then
            log:write("[WARN ] MvnArtifact "..tostring(a.dbId).." probably already exists. Insert it again\n")
        end
        assert(a.groupId and a.artifactId and a.version)
        if a.parentGroupId then assert(a.parentArtifactId and a.parentVersion)
        else assert(not a.parentArtifactId and not a.parentVersion) end
        stmt:reset()
        stmt:bind(":groupId", mod.dbGetOrNewString(app, a.groupId))
        stmt:bind(":artifactId", mod.dbGetOrNewString(app, a.artifactId))
        stmt:bind(":version", mod.dbGetOrNewString(app, a.version))
        stmt:bind(":parentGroupId", mod.dbGetOrNewString(app, a.parentGroupId))
        stmt:bind(":parentArtifactId", mod.dbGetOrNewString(app, a.parentArtifactId))
        stmt:bind(":parentVersion", mod.dbGetOrNewString(app, a.parentVersion))
        stmt:execute()
        local dbId = db:lastInsertRowid()
        if dbId == 0 then
            -- Seems as entry already exists. So need to query its id separately.
            local stmt = db:prepare("SELECT id FROM MvnArtifact"
                .." WHERE groupId = :groupId AND artifactId = :artifactId AND version = :version"
                .." AND parentGroupId = :parentGroupId AND parentArtifactId = :parentArtifactId AND parentVersion = :parentVersion")
            stmt:reset()
            stmt:bind(":groupId", mod.dbGetOrNewString(app, a.groupId))
            stmt:bind(":artifactId", mod.dbGetOrNewString(app, a.artifactId))
            stmt:bind(":version", mod.dbGetOrNewString(app, a.version))
            stmt:bind(":parentGroupId", mod.dbGetOrNewString(app, a.parentGroupId))
            stmt:bind(":parentArtifactId", mod.dbGetOrNewString(app, a.parentArtifactId))
            stmt:bind(":parentVersion", mod.dbGetOrNewString(app, a.parentVersion))
            local rs = stmt:execute()
            dbId = rs:value(1)
            assert(dbId)
        end
        mvnArtifactIds[a] = dbId -- TODO MUST be byString
        local bucket = mvnArtifactIdsByArtif[assert(a.artifactId)]
        if not bucket then bucket = {} mvnArtifactIdsByArtif[a.artifactId] = bucket end
        table.insert(bucket, { dbId = dbId, mvnArtifact = a, })
        return dbId
    end
    -- Store new artifacts
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        insertMvnArtifact(mvnArtifact)
        if mvnArtifact.parentArtifactId then
        end
    end
    -- Store dependencies
    local queryStr = "INSERT INTO MvnDependency"
        .."    ( mvnArtifactId,  needsMvnArtifactId)"
        .."  VALUES"
        .."    ( :mvnArtifactId, :needsMvnArtifactId)"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        local mvnDeps = app.mvnDepsByArtifact[mvnArtifact]
        for _, mvnDep in pairs(mvnDeps or {}) do
            assert(mvnDep.groupId and mvnDep.artifactId)
            local bucket = mvnArtifactIdsByArtif[mvnDep.artifactId]
            local depId = nil
            for _,a in pairs(bucket or {}) do
                if  mvnDep.groupId == a.mvnArtifact.groupId
                and mvnDep.artifactId == a.mvnArtifact.artifactId
                and mvnDep.version == a.mvnArtifact.version then
                    depId = assert(a.dbId)
                end
            end
            if not depId then -- Artifact not stored yet. Do now.
                if not mvnDep.version then
                    -- TODO mvnDep.version CAN be missing. Eg via depMgnt of
                    --      unknown parent or similar
                    mvnDep.version = "TODO_40ba845c5a1bd8"
                end
                depId = insertMvnArtifact({
                    groupId = mvnDep.groupId,
                    artifactId = mvnDep.artifactId,
                    version = mvnDep.version,
                })
            end
            stmt:reset()
            stmt:bind(":mvnArtifactId", assert(mvnArtifactIds[mvnArtifact]))
            stmt:bind(":needsMvnArtifactId", assert(depId, mvnDep.artifactId))
            stmt:execute()
        end
    end
end


-- returns dbId of the (new or existing) string
function mod.dbGetOrNewString( app, str )
    local db = mod.dbGetInstance(app)
    local tryCnt = 0
    --log:write("[DEBUG] Searching String ID for '"..tostring(str).."'\n")
    if not str then return nil end
::startOver::
    -- Ask inMemory cache
    local stringId = app.stringIdByStr[str]
    if stringId then
        --log:write("[DEBUG] Using String ".. stringId .." for '"..str.."'\n")
        return stringId
    end
    -- Ask DB
    local queryStr = "SELECT id FROM String WHERE str = :str"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    stmt:reset()
    stmt:bind(":str", str)
    local rs = stmt:execute()
    if rs:next() then -- DB has an entry :)
        stringId = assert(rs:value(1))
        if rs:next() then log:write("[WARN ] DB string duplication: '"..tostring(str).."'\n") end
        --log:write("[DEBUG] Using OLD String ".. stringId .."\n")
        app.stringIdByStr[str] = stringId
        return stringId
    end
    stmt:close() app.preparedStmts[queryStr] = nil -- TODO WTF?!?
    --log:write("[DEBUG] None in DB yet. Make sure it exists\n")
    local queryStr = "INSERT INTO String (str)VALUES(:str) ON CONFLICT DO NOTHING"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    stmt:reset()
    stmt:bind(":str", str)
    stmt:execute()
    stmt:close() app.preparedStmts[queryStr] = nil -- TODO WTF?!?
    --log:write("[DEBUG] Then try again\n")
    if tryCnt > 3 then error("TODO_20221215185428 fixme") end
    tryCnt = tryCnt +1
    goto startOver -- recursion stinks
end


function mod.dbInitTables( app )
    local db = mod.dbGetInstance(app)
    db:prepare("CREATE TABLE IF NOT EXISTS String ("
        .." id INTEGER PRIMARY KEY,"
        .." str TEXT UNIQUE)"
    ):execute()
    db:prepare("CREATE TABLE IF NOT EXISTS MvnArtifact ("
        .." id INTEGER PRIMARY KEY,"
        .." groupId INT,"
        .." artifactId INT,"
        .." version INT,"
        .." parentGroupId INT,"
        .." parentArtifactId INT,"
        .." parentVersion INT)"
    ):execute()
    db:prepare("CREATE TABLE IF NOT EXISTS MvnDependency ("
        .." id INTEGER PRIMARY KEY,"
        .." mvnArtifactId INT,"
        .." needsMvnArtifactId INT)"
    ):execute()
    --db:prepare("CREATE TABLE IF NOT EXISTS MvnProperty ("
    --    .." id INTEGER PRIMARY KEY,"
    --    .." keyStringId INT,"
    --    .." valStringId INT)"
    --):execute()
end


function mod.dbGetInstance( app )
    local db = app.sqlite
    if not db then
        db = newSqlite{ database = app.statePath, }
        db:enhancePerf()
        app.sqlite = db
    end
    return db
end


function mod.newSocketMgr()
    local hosts = {}
    -- TOO_BUGGY  local numConnActive, numConnActiveLimit = 0, 4
    -- TOO_BUGGY  local numConnActiveCond = newCond()
    local openSock = function( t, opts )
        for k, v in pairs(opts) do
            if false then
            elseif k=='host' or k=='port' or k=='useTLS' then
            else
                error('Unknown option: '..tostring(k))
            end
        end
        local inaddr = inaddrOfHostname(opts.host)
        local af
        if inaddr:find('^%d+.%d+.%d+.%d+$') then af = AF_INET else af = AF_INET6 end
        if false then
            log:write("opts.useTLS "..tostring(opts.useTLS).." (Override to TRUE ...)\n")
            opts.useTLS = true -- TODO remove as soon fixed scriptlee is available.
        else
            log:write("opts.useTLS is "..tostring(opts.useTLS).." (keep as-is)\n")
        end
        local key = inaddr.."\t"..opts.port.."\t"..tostring(opts.useTLS)
        --log:write("KEY wr '"..key.."'\n")
        local existing = hosts[key]
        -- TOO_BUGGY  numConnActive = numConnActive +1
        if existing then
            return table.remove(existing)
        else
            -- TOO_BUGGY  while numConnActive > numConnActiveLimit do
            -- TOO_BUGGY      log:write("numConnActive is "..numConnActive..". Waiting ...\n")
            -- TOO_BUGGY      numConnActiveCond:waitForever()
            -- TOO_BUGGY  end
            -- TOO_BUGGY  log:write("numConnActive is ".. numConnActive ..". Go\n")
            local sock = socket(af, SOCK_STREAM, IPPROTO_TCP)
            sock:connect(inaddr, opts.port)
            if opts.useTLS then
                local sockUnderTls = sock
                sock = newTlsClient{
                    cls = assert(sockUnderTls),
                    peerHostname = assert(opts.host),
                    onVerify = function( tlsIssues, sockUnderTls )
                        if tlsIssues.CERT_NOT_TRUSTED then
                            warn("TLS ignore CERT_NOT_TRUSTED");
                            tlsIssues.CERT_NOT_TRUSTED = false
                        end
                    end,
                    send = function( buf, sockUnderTls )
                        local ret = sockUnderTls:write(buf)
                        sockUnderTls:flush() -- TODO Why is this flush needed?
                        return ret
                    end,
                    recv = function( sockUnderTls ) return sockUnderTls:read() end,
                    flush = function( sockUnderTls ) sockUnderTls:flush() end,
                    closeSnk = function( sockUnderTls ) sockUnderTls:closeSnk() end,
                }
                assert(not getmetatable(sock).release)
                getmetatable(sock).release = function( t ) sockUnderTls:release() end;
            end
            return {
                _sock = assert(sock),
                _host = assert(inaddr),
                _port = assert(opts.port),
                _useTLS = opts.useTLS;
                write = function(t, ...) return sock:write(...)end,
                read = function(t, ...) return sock:read(...)end,
                flush = function(t, ...) return sock:flush(...)end,
            }
        end
        error("unreachable")
    end
    local releaseSock = function( t, sockWrapr )
        t:closeSock(sockWrapr) return -- TODO rm as soon fixed scriptlee available (aka >46)
--        -- keep-alive (TODO only if header says so)
--        local key = sockWrapr._host.."\t"..sockWrapr._port.."\t"..tostring(sockWrapr._useTLS)
--        local host = hosts[key]
--        if not host then host = {} hosts[key] = host end
--        table.insert(host, sockWrapr)
    end
    return{
        openSock = openSock,
        releaseSock = releaseSock,
        closeSock = function(t, sockWrapr)
            sockWrapr._sock:release()
            -- TOO_BUGGY  numConnActive = numConnActive -1
            -- TOO_BUGGY  log:write("numConnActive -1. Is now ".. numConnActive ..". Broadcast.\n")
            -- TOO_BUGGY  numConnActiveCond:broadcast()
        end,
    }
end


function mod.printCsvParents( app )
    local db = mod.dbGetInstance(app)
    local queryStr = "" -- Query
        .." SELECT DISTINCT"
        .."   GroupId.str,"
        .."   ArtifactId.str,"
        .."   Version.str,"
        .."   ParentGid.str,"
        .."   ParentAid.str,"
        .."   ParentVersion.str"
        .." FROM MvnArtifact AS A"
        .." JOIN String GroupId ON GroupId.id = A.groupId"
        .." JOIN String ArtifactId ON ArtifactId.id = A.artifactId"
        .." JOIN String Version ON Version.id = A.version"
        .." LEFT JOIN String ParentGid ON ParentGid.id = A.parentGroupId"
        .." LEFT JOIN String ParentAid ON ParentAid.id = A.parentArtifactId"
        .." LEFT JOIN String ParentVersion ON ParentVersion.id = A.parentVersion"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    stmt:reset()
    local rs = stmt:execute()
    out:write("h;Created;"..mod.escapeCsvValue(os.date("%Y-%m-%d %H:%m:%S")).."\n")
    out:write("c;GID;AID;Version;ParentGID;ParentAID;ParentVersion\n")
    while rs:next() do
        out:write("r;") out:write(mod.escapeCsvValue(rs:value(1) or app.nullvalue))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(2) or app.nullvalue))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(3) or app.nullvalue))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(4) or app.nullvalue))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(5) or app.nullvalue))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(6) or app.nullvalue))
        out:write("\n")
    end
    out:write("t;status;OK\n")
end


function mod.printCsvDependencies( app )
    local db = mod.dbGetInstance(app)
    local queryStr = "" -- Query
        .." SELECT DISTINCT"
        .."   GroupId.str,"
        .."   ArtifactId.str,"
        .."   Version.str,"
        .."   DepGid.str,"
        .."   DepAid.str,"
        .."   DepVersion.str"
        .." FROM MvnArtifact AS A"
        .." JOIN MvnDependency AS Dep ON Dep.mvnArtifactId = A.id"
        .." JOIN MvnArtifact AS D ON Dep.needsMvnArtifactId = D.id"
        .." JOIN String GroupId ON GroupId.id = A.groupId"
        .." JOIN String ArtifactId ON ArtifactId.id = A.artifactId"
        .." JOIN String Version ON Version.id = A.version"
        .." JOIN String DepGid ON DepGid.id = D.groupId"
        .." JOIN String DepAid ON DepAid.id = D.artifactId"
        .." JOIN String DepVersion ON DepVersion.id = D.version"
    local stmt = app.preparedStmts[queryStr]
    if not stmt then stmt = db:prepare(queryStr) app.preparedStmts[queryStr] = stmt end
    stmt:reset()
    local rs = stmt:execute()
    out:write("h;Created;"..mod.escapeCsvValue(os.date("%Y-%m-%d %H:%m:%S")).."\n")
    out:write("c;GID;AID;Version;DepGID;DepAID;DepVersion\n")
    while rs:next() do
        local nilVal = "NULL"
        out:write("r;") out:write(mod.escapeCsvValue(rs:value(1) or nilVal))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(2) or nilVal))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(3) or nilVal))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(4) or nilVal))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(5) or nilVal))
        out:write(";") out:write(mod.escapeCsvValue(rs:value(6) or nilVal))
        out:write("\n")
    end
    out:write("t;status;OK\n")
end


function mod.escapeCsvValue( str )
    local typ = type(str)
    if typ == "string" then
        if str:find("[;\r\n\"]") then
            str = '"'.. str:gsub('"', '""') ..'"' end
    else
        error("TODO_20221215181624 "..tostring(typ))
    end
    return str
end


function mod.enrichFromCbacks( app, opts )
    local writeNextPomTo = assert(opts.writeNextPomTo)
    local onParentPomMissing = assert(opts.onParentPomMissing)
    opts = nil
    local pomsToLoad = {
        { aid = "preflux-web", gid = "ch.post.it.paisa.preflux", version = "00.00.01.02-SNAPSHOT", },
        --{ aid = "preflux", gid = "ch.post.it.paisa.preflux", version = "00.00.01.02-SNAPSHOT", },
    }
    while #pomsToLoad > 0 do
        local pomParser = false
        local ok = writeNextPomTo(objectSeal{
            write = function( t, buf, beg, len )
                if not pomParser then
                    pomParser = objectSeal{
                        app = app,
                        base = false,
                        xmlElemStack = {},
                        currentValue = false,
                        mvnArtifact = mod.newMvnArtifact(),
                        mvnDependency = false, -- the one we're currently parsing
                        mvnMngdDependency = false, -- the one we're currently parsing
                        write = function( t, buf, beg, len )
                            assert(beg == 1)
                            assert(buf:len() == len)
                            return t.base:write(buf)
                        end,
                        closeSnk = function( t ) return t.base:closeSnk() end,
                    }
                    pomParser.base = newXmlParser{
                        cls = pomParser,
                        onElementBeg = function( tag, pomParser )
                            table.insert(pomParser.xmlElemStack, { tag = tag, })
                            pomParser.currentValue = false
                        end,
                        onElementEnd = function( tag, pomParser )
                            mod.processXmlValue(pomParser)
                            local elem = table.remove(pomParser.xmlElemStack)
                            assert(elem.tag == tag);
                        end,
                        onChunk = function( buf, pomParser )
                            if pomParser.currentValue then
                                pomParser.currentValue = pomParser.currentValue .. buf
                            else
                                pomParser.currentValue = buf
                            end
                        end,
                        onEnd = function( pomParser )
                            assert(#pomParser.xmlElemStack == 0)
                            local app = pomParser.app
                            local mvnArtifact = pomParser.mvnArtifact
                            pomParser.mvnArtifact = false
                            if not mvnArtifact.groupId then
                                mvnArtifact.groupId = mvnArtifact.parentGroupId end
                            if not mvnArtifact.version then
                                mvnArtifact.version = mvnArtifact.parentVersion end
                            local key = mod.getMvnArtifactKey(mvnArtifact)
                            if app.mvnArtifacts[key] then
                                local old = app.mvnArtifacts[key]
                                local oId = mod.getMvnArtifactKey(old)
                                local nId = mod.getMvnArtifactKey(mvnArtifact)
                                if oId ~= nId then
                                    print("Already exists BUT DIFFERS:")
                                    for k,v in pairs(old) do print("O",k,v) end
                                    print()
                                    for k,v in pairs(mvnArtifact) do print("N",k,v) end
                                    error("TODO_20221215150040")
                                else
                                    log:write("Already known. ReUse "..tostring(oId).."\n")
                                end
                            else
                                app.mvnArtifacts[key] = mvnArtifact
                            end
                            -- Check for missing poms.
                            local key = mod.getMvnArtifactKey({
                                artifactId = mvnArtifact.parentArtifactId,
                                groupId = mvnArtifact.parentGroupId,
                                version = mvnArtifact.parentVersion,
                            })
                            if not app.mvnArtifacts[key] then -- parent pom missing
                                onParentPomMissing(
                                    mvnArtifact.parentGroupId,
                                    mvnArtifact.parentArtifactId,
                                    mvnArtifact.parentVersion)
                            end
                        end,
                    }
                end
                pomParser:write(buf, beg, len)
            end,
            closeSnk = function() pomParser:closeSnk() end,
        })
        if not ok then break end
    end
    log:write("[INFO ] No more pom URLs\n")
    mod.resolveDependencyVersionsFromDepsMgmnt(app)
    mod.resolveProperties(app)
    mod.storeAsSqliteFile(app)
    log:write("\n\nState DUMP:\n\n")
    mod.printStuffAtEnd(app)
end


-- Deprecated. Use the callback variant
function mod.enrichFromUrls( app )
    local pomSrc = mod.newPomUrlSrc(app)
    local missingPoms, missingDone = {}, {}
    mod.enrichFromCbacks(app, objectSeal{
        onParentPomMissing = function( gid, aid, version )
            local artif = mod.newMvnArtifact()
            local url = "http://localhost:8080/isa-poms"
            if false then
            elseif aid == "paisa-api" then
                url = url .. "/apis/".. aid .."/pom.xml"
            elseif aid == "service" and gid == "ch.post.it.paisa.service" then
                url = url .."/platform/poms/service/paisa-service-superpom/pom.xml"
            else
                log:write("Missing: ".. gid .."\t".. aid .."\t".. version .."\n")
                return
            end
            if not missingDone[url] then missingPoms[url] = true end
        end,
        writeNextPomTo = function( snk )
            local pomUrl = pomSrc:nextPomUrl()
            if not pomUrl then
                pomUrl, _ = pairs(missingPoms)(missingPoms)
                if pomUrl then
                    missingDone[pomUrl] = true
                    missingPoms[pomUrl] = nil
                    log:write("NeedAlso: ".. pomUrl .."\n")
                end
            end
            if not pomUrl then
                log:write("No more poms\n")
                return false
            end
            local proto = pomUrl:match("^(https?)://")
            local isTLS = (proto:upper() == "HTTPS")
            local host = pomUrl:match("^https?://([^:/]+)[:/]")
            local port = pomUrl:match("^https?://[^:/]+:(%d+)[^%d]")
            local url = pomUrl:match("^https?://[^/]+(.*)$")
            if port == 443 then isTLS = true end
            if not port then port = (isTLS and 443 or 80) end
            log:write("> GET ".. proto .."://".. host ..":".. port .. url .."\n")
            local req = objectSeal{
                app = app,
                base = false,
                pomParser = false,
            }
            req.base = app.http:request{
                cls = req,
                host = assert(host), port = assert(port),
                method = "GET", url = url,
                useTLS = isTLS,
                onRspHdr = function( msg, req )
                    if msg.status ~= 200 then
                        log:write("< "..tostring(msg.proto) .." "..tostring(msg.status).." "..tostring(msg.phrase).."\n")
                        for i, h in ipairs(msg.headers) do
                            log:write("< ".. tostring(h[1]) ..": ".. tostring(h[2]) .."\n")
                        end
                        log:write("< \n")
                        error("Unexpected HTTP ".. tostring(msg.status))
                    end
                end,
                onRspChunk = function( buf, req )
                    snk:write(buf, 1, buf:len())
                end,
                onRspEnd = function( req )
                    snk:closeSnk()
                end,
            }
            req.base:closeSnk()
            return true
        end,
    })
end


function mod.run( app )
    assert(not app.mvnPropsByArtifact) app.mvnPropsByArtifact = {}
    assert(not app.mvnDepsByArtifact) app.mvnDepsByArtifact = {}
    assert(not app.mvnMngdDepsByArtifact) app.mvnMngdDepsByArtifact = {}
    local fileExists = io.open(app.statePath, "rb")
    if fileExists then
        io.close(fileExists)
        mod.loadFromSqliteFile( app )
    else
        assert(not app.mvnArtifacts)
        app.mvnArtifacts = {}
    end
    if false then
    elseif app.asCsv == "parents" then
        mod.printCsvParents(app)
    elseif app.asCsv == "deps" then
        mod.printCsvDependencies(app)
    elseif app.isExample then
        mod.enrichFromUrls(app)
    else
        error("TODO_20221215175852")
    end
    if app.sqlite then app.sqlite:close() app.sqlite = false end
end


function mod.main()
    local app = objectSeal{
        http = newHttpClient{
            socketMgr = assert(mod.newSocketMgr()),
        },
        isExample = false,
        asCsv = false,
        nullvalue = false,
        mvnArtifacts = false,
        mvnPropsByArtifact = false,
        mvnDepsByArtifact = false,
        mvnMngdDepsByArtifact = false,
        sqlite = false,
        statePath = false,
        preparedStmts = {},
        stringIdByStr = {},
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(nil, mod.main)
