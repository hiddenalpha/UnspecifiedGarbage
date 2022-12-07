--[====================================================================[

  Initially written using scriptlee 0.0.5-41-G .

  ]====================================================================]

local newHttpClient = require("scriptlee").newHttpClient
local newSqlite = require("scriptlee").newSqlite
local newXmlParser = require("scriptlee").newXmlParser
local objectSeal = require("scriptlee").objectSeal
local sleep = require("scriptlee").posix.sleep
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
        .."    --sqliteOut <path>\n"
        .."      Path where to export the result.\n"
        .."\n"
        .."\n")
end


function mod.parseArgs( app )
    local iA = 0
    local isExample = false
::nextArg::
    iA = iA + 1
    local arg = _ENV.arg[iA]
    if not arg then
        goto endOfArgs
    elseif arg == "--help" then
        mod.printHelp() return -1
    elseif arg == "--example" then
        isExample = true
    elseif arg == "--sqliteOut" then
        iA = iA + 1
        arg = _ENV.arg[iA]
        if not arg then log:write("Arg --sqliteOut needs value\n")return-1 end
        app.sqliteOutFile = arg
    else
        log:write("Unexpected arg: "..tostring(arg).."\n")return -1
    end
    goto nextArg
::endOfArgs::
    if not isExample then log:write("Bad Args\n") return -1 end
    return 0
end


function mod.newPomUrlSrc( app )
    local urls = {
        -- TODO insert URLs here!
    }
    local m = {
        nextPomUrl = function(t)
            return table.remove(urls, 1)
        end,
        __index = false,
    }
    m.__index = m
    return setmetatable({}, m)
end


function mod.processXmlValue( pomParser )
    local app = pomParser.req.app
    local xpath = ""
    for i, stackElem in ipairs(pomParser.xmlElemStack) do
        xpath = xpath .."/".. stackElem.tag
    end
    --log:write(xpath .."\n")
    local mvnArtifact = pomParser.mvnArtifact
    local newMvnDependency = function()return objectSeal{
        groupId = false,
        artifactId = false,
        version = false,
    }end
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
        if not pomParser.mvnDependency then pomParser.mvnDependency = newMvnDependency() end
        pomParser.mvnDependency.groupId = pomParser.currentValue
    elseif xpath == "/project/dependencies/dependency/artifactId" then
        if not pomParser.mvnDependency then pomParser.mvnDependency = newMvnDependency() end
        pomParser.mvnDependency.artifactId = pomParser.currentValue
    elseif xpath == "/project/dependencies/dependency/version" then
        if not pomParser.mvnDependency then pomParser.mvnDependency = newMvnDependency() end
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
        if not pomParser.mvnMngdDependency then pomParser.mvnMngdDependency = newMvnDependency() end
        pomParser.mvnMngdDependency.groupId = pomParser.currentValue
    elseif xpath == "/project/dependencyManagement/dependencies/dependency/artifactId" then
        if not pomParser.mvnMngdDependency then pomParser.mvnMngdDependency = newMvnDependency() end
        pomParser.mvnMngdDependency.artifactId = pomParser.currentValue
    elseif xpath == "/project/dependencyManagement/dependencies/dependency/version" then
        if not pomParser.mvnMngdDependency then pomParser.mvnMngdDependency = newMvnDependency() end
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
    --log:write("< "..tostring(msg.proto) .." "..tostring(msg.status).." "..tostring(msg.phrase).."\n")
    --for i, h in ipairs(msg.headers) do
    --    log:write("< ".. h.key ..": ".. h.val .."\n")
    --end
    --log:write("< \n")
    if msg.status ~= 200 then
        error("Unexpected HTTP ".. tostring(msg.status))
    end
    assert(not req.pomParser)
    req.pomParser = objectSeal{
        req = req,
        base = false,
        xmlElemStack = {},
        currentValue = false,
        mvnArtifact = objectSeal{
            parentGroupId = false,
            parentArtifactId = false,
            parentVersion = false,
            groupId = false,
            artifactId = false,
            version = false,
        },
        mvnDependency = false, -- the one we're currently parsing
        mvnMngdDependency = false, -- the one we're currently parsing
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
            assert(not app.mvnArtifacts[key])
            app.mvnArtifacts[key] = mvnArtifact
        end,
    }
end


function mod.onGetPomRspChunk( buf, req )
    req.pomParser:write(buf)
end


function mod.onGetPomRspEnd( req )
    req.pomParser:closeSnk()
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


function mod.storeAsSqliteFile( app )
    -- TODO could we cache our prepared queries?
    local db, stmt
    if not app.sqliteOutFile then
        log:write("[INFO ] No sqliteOutFile provided. Skip export.\n")
        return
    end
    -- Query to list Artifacts and their parents:
    --   SELECT GroupId.str AS 'GID', ArtifactId.str AS 'AID', Version.str AS 'Version', ParentGid.str AS 'ParentGid', ParentAid.str AS 'ParentAid', ParentVersion.str AS 'ParentVersion'
    --   FROM MvnArtifact AS A
    --   JOIN String GroupId ON GroupId.id = A.groupId
    --   JOIN String ArtifactId ON ArtifactId.id = A.artifactId
    --   JOIN String Version ON Version.id = A.version
    --   JOIN String ParentGid ON ParentGid.id = A.parentGroupId
    --   JOIN String ParentAid ON ParentAid.id = A.parentArtifactId
    --   JOIN String ParentVersion ON ParentVersion.id = A.parentVersion
    --
    -- Query to list dependencies:
    --   SELECT GroupId.str AS 'GID', ArtifactId.str AS 'AID', Version.str AS 'Version', DepGid.str AS 'Dependency GID', DepAid.str AS 'Dependnecy AID', DepVersion.str AS 'Dependency Version'
    --   FROM MvnArtifact AS A
    --   JOIN MvnDependency AS Dep ON Dep.mvnArtifactId = A.id
    --   JOIN MvnArtifact AS D ON Dep.needsMvnArtifactId = D.id
    --   JOIN String GroupId ON GroupId.id = A.groupId
    --   JOIN String ArtifactId ON ArtifactId.id = A.artifactId
    --   JOIN String Version ON Version.id = A.version
    --   JOIN String DepGid ON DepGid.id = D.groupId
    --   JOIN String DepAid ON DepAid.id = D.artifactId
    --   JOIN String DepVersion ON DepVersion.id = D.version
    --
    db = newSqlite{
        database = app.sqliteOutFile,
    }
    db:enhancePerf()
    db:prepare("CREATE TABLE String ("
        .." id INTEGER PRIMARY KEY,"
        .." str TEXT UNIQUE)"
    ):execute()
    db:prepare("CREATE TABLE MvnArtifact ("
        .." id INTEGER PRIMARY KEY,"
        .." groupId INT,"
        .." artifactId INT,"
        .." version INT,"
        .." parentGroupId INT,"
        .." parentArtifactId INT,"
        .." parentVersion INT)"
    ):execute()
    db:prepare("CREATE TABLE MvnDependency ("
        .." id INTEGER PRIMARY KEY,"
        .." mvnArtifactId INT,"
        .." needsMvnArtifactId INT)"
    ):execute()
    --db:prepare("CREATE TABLE MvnProperty ("
    --    .." id INTEGER PRIMARY KEY,"
    --    .." keyStringId INT,"
    --    .." valStringId INT)"
    --):execute()
    local mvnArtifactIds = {}
    local mvnArtifactIdsByArtif = {}
    local strings = {}
    local getStringId = function( str ) -- create/reUse strings on-demand
        if not str then return nil end
        local stringId = strings[str]
        if not stringId then
            local stmt = db:prepare("INSERT INTO String (str)VALUES(:str)")
            stmt:reset()
            stmt:bind(":str", str)
            stmt:execute()
            stringId = db:lastInsertRowid()
            strings[str] = stringId
        end
        return stringId
    end
    local stmtInsMvnArtifact = db:prepare("INSERT INTO MvnArtifact"
        .."('groupId', 'artifactId', 'version', 'parentGroupId', 'parentArtifactId', 'parentVersion')"
        .."VALUES"
        .."(:groupId , :artifactId , :version , :parentGroupId , :parentArtifactId , :parentVersion )")
    local insertMvnArtifact = function(a)
        assert(a.groupId and a.artifactId and a.version)
        if a.parentGroupId then assert(a.parentArtifactId and a.parentVersion)
        else assert(not a.parentArtifactId and not a.parentVersion) end
        stmtInsMvnArtifact:reset()
        stmtInsMvnArtifact:bind(":groupId", getStringId(a.groupId))
        stmtInsMvnArtifact:bind(":artifactId", getStringId(a.artifactId))
        stmtInsMvnArtifact:bind(":version", getStringId(a.version))
        stmtInsMvnArtifact:bind(":parentGroupId", getStringId(a.parentGroupId))
        stmtInsMvnArtifact:bind(":parentArtifactId", getStringId(a.parentArtifactId))
        stmtInsMvnArtifact:bind(":parentVersion", getStringId(a.parentVersion))
        stmtInsMvnArtifact:execute()
        local dbId = db:lastInsertRowid()
        mvnArtifactIds[a] = dbId -- TODO MUST be byString
        local bucket = mvnArtifactIdsByArtif[assert(a.artifactId)]
        if not bucket then bucket = {} mvnArtifactIdsByArtif[a.artifactId] = bucket end
        table.insert(bucket, { dbId = dbId, mvnArtifact = a, })
        return dbId
    end
    -- Store artifacts
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        insertMvnArtifact(mvnArtifact)
        local mvnDeps = app.mvnDepsByArtifact[mvnArtifact] or {}
        -- dependencies are nothing else than artifacts
        for _, mvnDep in pairs(mvnDeps) do
        end
    end
    -- Store dependencies
    local stmt = db:prepare("INSERT INTO MvnDependency"
        .."('mvnArtifactId', 'needsMvnArtifactId')"
        .."VALUES"
        .."(:mvnArtifactId , :needsMvnArtifactId )")
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        local mvnDeps = app.mvnDepsByArtifact[mvnArtifact]
        for _, mvnDep in pairs(mvnDeps or {}) do
            if not mvnDep.version then mvnDep.version = "TODO_5bbc0e87011e24d845136c5406302616" end
            assert(mvnDep.version, mvnDep.artifactId)
            assert(mvnDep.groupId and mvnDep.artifactId and mvnDep.version)
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


function mod.run( app )
    assert(not app.mvnArtifacts) app.mvnArtifacts = {}
    assert(not app.mvnPropsByArtifact) app.mvnPropsByArtifact = {}
    assert(not app.mvnDepsByArtifact) app.mvnDepsByArtifact = {}
    assert(not app.mvnMngdDepsByArtifact) app.mvnMngdDepsByArtifact = {}
    local pomSrc = mod.newPomUrlSrc(app)
    while true do
        local pomUrl = pomSrc:nextPomUrl()
        if not pomUrl then break end
        local proto = pomUrl:match("^(https?)://")
        local isTLS = (proto:upper() == "HTTPS")
        local host = pomUrl:match("^https?://([^:/]+)[:/]")
        local port = pomUrl:match("^https?://[^:/]+:(%d+)[^%d]")
        local url = pomUrl:match("^https?://[^/]+(.*)$")
        if not port then port = (isTLS and 443 or 80) end
        --log:write("> GET ".. proto .."://".. host ..":".. port .. url .."\n")
        local req = objectSeal{
            app = app,
            base = false,
            pomParser = false,
        }
        req.base = app.http:request{
            cls = req,
            host = assert(host), port = assert(port),
            method = "GET", url = url,
            --hdrs = ,
            useTLS = false, --TODO useTLS = isTLS,
            onRspHdr = mod.onGetPomRspHdr,
            onRspChunk = mod.onGetPomRspChunk,
            onRspEnd = mod.onGetPomRspEnd,
        }
        req.base:closeSnk()
    end
    log:write("[INFO ] No more pom URLs\n")
    mod.resolveDependencyVersionsFromDepsMgmnt(app)
    mod.resolveProperties(app)
    mod.storeAsSqliteFile(app)
    --mod.printStuffAtEnd(app)
end


function mod.main()
    local app = objectSeal{
        http = newHttpClient{},
        mvnArtifacts = false,
        mvnPropsByArtifact = false,
        mvnDepsByArtifact = false,
        mvnMngdDepsByArtifact = false,
        sqliteOutFile = false,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(nil, mod.main)
