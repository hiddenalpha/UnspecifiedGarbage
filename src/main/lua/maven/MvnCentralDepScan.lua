--[====================================================================[

  Initially written using scriptlee 0.0.5-46-G .

  ]====================================================================]

local AF_INET = require('scriptlee').posix.AF_INET
local AF_INET6 = require('scriptlee').posix.AF_INET6
local IPPROTO_TCP = require('scriptlee').posix.IPPROTO_TCP
local SOCK_STREAM = require('scriptlee').posix.SOCK_STREAM
local inaddrOfHostname = require('scriptlee').posix.inaddrOfHostname
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
local LOGDBG = (true)and(function(msg)log:write("[DEBUG] "..msg)end)or(function()end)


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


function mod.getUrlBy( app, thingy )
    if type(thingy) == "table" then
        local aid = assert(thingy.artifactId)
        local v = assert(thingy.version)
        local gid = assert(thingy.groupId)
        return "http://127.0.0.1:8081/tmp/artifactory/paisa/".. gid:gsub('%.','/') .."/".. aid .."/".. v .."/".. aid .."-".. v ..".pom"
    end
    error("Whops?!? ".. type(thingy))
end


function mod.processXmlValue( pomParser )
    local app = pomParser.req.app
    local xpath = {}
    for i, stackElem in ipairs(pomParser.xmlElemStack) do
        table.insert(xpath, "/")
        table.insert(xpath, stackElem.tag)
    end
    xpath = table.concat(xpath)
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


function mod.onMvnArtifactThatShouldBeFetched( app, mvnArtifact )
    assert(type(mvnArtifact.artifactId) == "string")
    assert(type(mvnArtifact.version) == "string")
    assert(type(mvnArtifact.groupId) == "string")
    local key = mod.getMvnArtifactKey(mvnArtifact)
    if app.mvnArtifactsNotFound[key] then
        LOGDBG("do NOT enqueue bcause 404: ".. mvnArtifact.artifactId .." ".. mvnArtifact.version .."\n")
        return
    end
    table.insert(app.nextUrlsToFetch, {
        artifactId = mvnArtifact.artifactId,
        version = mvnArtifact.version,
        groupId = mvnArtifact.groupId,
    })
    table.insert(app.taskQueue, function()mod.fetchAnotherMvnArtifact(app)end)
end


function mod.fetchAnotherMvnArtifact( app )
::findNextArtifactToFetch::
    local mvnArtifact
    mvnArtifact = table.remove(app.currentUrlsToFetch, 1)
    if not mvnArtifact then
        assert(#app.currentUrlsToFetch == 0)
        if #app.nextUrlsToFetch > 0 then -- switch to next set to process
            LOGDBG("currentUrlsToFetch drained. Continue with nextUrlsToFetch\n")
            app.currentUrlsToFetch = app.nextUrlsToFetch
            app.nextUrlsToFetch = {}
            goto findNextArtifactToFetch
        end
        table.insert(app.taskQueue, function() mod.onNoMorePomsToFetch(app) end)
        return
    end

    local pomUrl = mod.getUrlBy(app, mvnArtifact)
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
        artifactId = mvnArtifact.artifactId, -- so we know what we're trying to fetch
        version = mvnArtifact.version, -- so we know what we're trying to fetch
        groupId = mvnArtifact.groupId, -- so we know what we're trying to fetch
    }
    req.base = app.http:request{
        cls = req,
        host = assert(host), port = assert(port),
        method = "GET", url = url,
        --hdrs = ,
        useTLS = isTLS,
        onRspHdr = mod.onGetPomRspHdr,
        onRspChunk = function( buf, req ) if req.pomParser then req.pomParser:write(buf) end end,
        onRspEnd = function( req ) if req.pomParser then req.pomParser:closeSnk() end end,
    }
    req.base:closeSnk()
end


function mod.onMvnArtifactThatShouldBeScannedForDeps( app, mvnArtifact )
    assert(type(mvnArtifact.artifactId) == "string")
    assert(type(mvnArtifact.version) == "string")
    assert(type(mvnArtifact.groupId) == "string")
end


function mod.enqueueMissingDependencies( app, mvnArtifact )
    local hasParent = (not not mvnArtifact.parentArtifactId)
    if hasParent then
        local parentKey = mod.getMvnArtifactKey({
            artifactId = mvnArtifact.parentArtifactId,
            version = mvnArtifact.parentVersion,
            groupId = mvnArtifact.parentGroupId,
        })
        local parent = app.mvnArtifacts[parentKey]
        if not parent then
            LOGDBG("Enqueue parent:  aid=".. mvnArtifact.parentArtifactId
                .."  v=".. mvnArtifact.parentVersion.."  gid=".. mvnArtifact.parentGroupId .."\n")
            table.insert(app.taskQueue, function()
                mod.onMvnArtifactThatShouldBeFetched(app, objectSeal{
                    artifactId = mvnArtifact.parentArtifactId,
                    version = mvnArtifact.parentVersion,
                    groupId = mvnArtifact.parentGroupId,
                })
            end)
        end
    end
    local deps = app.mvnDepsByArtifact[mvnArtifact]
    if not deps then
        LOGDBG("Has no dependencies:  aid="..tostring(mvnArtifact.artifactId)
            ..", ver="..tostring(mvnArtifact.version)..", gid="..tostring(mvnArtifact.groupId).."\n")
        return
    end
    for _,dep in pairs(deps) do
        local isIncomplete = (not dep.artifactId or not dep.version or not dep.groupId)
        local hasUnresolvedMvnProps = false
        if not isIncomplete then
            hasUnresolvedMvnProps = (dep.artifactId:find("${",0,true) or dep.version:find("${",0,true) or dep.groupId:find("${",0,true))
        end
        if isIncomplete or hasUnresolvedMvnProps then
            LOGDBG("Incomplete. Give up  aid="..tostring(dep.artifactId)
                .."  v="..tostring(dep.version).."  gid="..tostring(dep.groupId).."\n")
        else
            LOGDBG("Enqueue dependency:  aid="..tostring(dep.artifactId)
                .."  v="..tostring(dep.version).."  gid="..tostring(dep.groupId).."\n")
            table.insert(app.taskQueue, function()
                mod.onMvnArtifactThatShouldBeFetched(app, objectSeal{
                    artifactId = dep.artifactId,
                    version = dep.version,
                    groupId = dep.groupId,
                })
            end)
        end
    end
end


function mod.onGetPomRspHdr( msg, req )
    local app = req.app
    log:write("< "..tostring(msg.proto) .." "..tostring(msg.status).." "..tostring(msg.phrase).."\n")
    if msg.status == 404 then
        log:write("HTTP 404. Ignore aid='".. req.artifactId .."' v='".. req.version .."' gid='".. req.groupId .."'.\n")
        local key = assert(mod.getMvnArtifactKey(req))
        app.mvnArtifactsNotFound[key] = true
        table.insert(app.taskQueue, function() mod.fetchAnotherMvnArtifact(app) end)
        return
    elseif msg.status ~= 200 then
        for i, h in ipairs(msg.headers) do
            log:write("< ".. h.key ..": ".. h.val .."\n")
        end
        log:write("< \n")
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
            if type(pomParser.currentValue) == "table" then
                pomParser.currentValue = table.concat(pomParser.currentValue)
            end
            mod.processXmlValue(pomParser)
            local elem = table.remove(pomParser.xmlElemStack)
            assert(elem.tag == tag);
        end,
        onChunk = function( buf, pomParser )
            if type(pomParser.currentValue) ~= "table" then
                pomParser.currentValue = { buf }
            else
                table.insert(pomParser.currentValue, buf)
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
            table.insert(app.taskQueue, function()
                mod.onNewArtifactGotFetched(app, mvnArtifact)
            end)
        end,
    }
end


function mod.onNewArtifactGotFetched( app, mvnArtifact )
    mod.resolveProperties(app) -- TODO IMHO we shouldn't call that so often
    mod.resolveDependencyVersionsFromDepsMgmnt(app) -- TODO IMHO we shouldn't call that so often
    mod.enqueueMissingDependencies(app, mvnArtifact)
end


function mod.resolveDependencyVersionsFromDepsMgmnt( app )
    local mvnArtifacts = app.mvnArtifacts
    local mvnDepsByArtifact = app.mvnDepsByArtifact
    local mvnMngdDepsByArtifact = app.mvnMngdDepsByArtifact
    local funcs = {}
    function funcs.resolveForDependency( mvnArtifact, mvnDependency )
        assert(mvnArtifact)
        assert(mvnDependency)
        --LOGDBG("resolveForDependency(".. mvnArtifact.artifactId .."-".. mvnArtifact.version ..", "
        --    .. mvnDependency.artifactId .."-"..tostring(mvnDependency.version)..")\n")
        -- Nothing to do if its already set
        if mvnDependency.version then return end
        -- Do we have deps management available?
        local mngdDeps = mvnMngdDepsByArtifact[mvnArtifact]
        if mngdDeps then
            -- Lookup our own deps management for a version
            for _, mngdDep in pairs(mngdDeps) do
                if  mvnDependency.groupId == mngdDep.groupId
                and mvnDependency.artifactId == mngdDep.artifactId
                then
                    -- Version found :)
                    mvnDependency.version = assert(mngdDep.version);
                    return
                end
            end
        end
        assert(not mvnDependency.version)
        -- no deps management? Maybe parent has?
        local hasParent = (mvnArtifact.parentArtifactId)
        local parent = mvnArtifacts[mod.getMvnArtifactKey{
            groupId = mvnArtifact.parentGroupId,
            artifactId = mvnArtifact.parentArtifactId,
            version = mvnArtifact.parentVersion,
        }];
        local parentExists = (not not parent)
        if parentExists then
            funcs.resolveForDependency(parent, mvnDependency)
        end
    end
    function funcs.resolveForArtifact( mvnArtifact )
        --LOGDBG("resolveForArtifact("..mvnArtifact.artifactId..", ".. mvnArtifact.version ..")\n")
        local mvnDeps = mvnDepsByArtifact[mvnArtifact]
        if not mvnDeps then LOGDBG("No mvnDeps\n") return end
        if not (#mvnDeps > 0) then LOGDBG("mvnDeps empty\n") end
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
        log:write(string.format("ARTIFACT  %-30s %-13s %s\n",
            mvnArtifact.artifactId, mvnArtifact.version, mvnArtifact.groupId))
        log:write(string.format("  PARENT  %-30s %-13s %s\n",
            mvnArtifact.parentArtifactId, mvnArtifact.parentVersion, mvnArtifact.parentGroupId))
        local deps = app.mvnDepsByArtifact[mvnArtifact]
        --local mvnProps = app.mvnPropsByArtifact[mvnArtifact]
        --if mvnProps then for _, mvnProp in pairs(mvnProps) do
        --    log:write(string.format("    PROP  %-44s  %s\n", mvnProp.key, mvnProp.val))
        --end end
        if deps then for _, mvnDependency in pairs(deps) do
            log:write(string.format("     DEP  %-30s %-13s %s\n",
                mvnDependency.artifactId, mvnDependency.version, mvnDependency.groupId))
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
    db:close()
end


function mod.onNoMorePomsToFetch( app )
    log:write("[INFO ] No more POMs to fetch\n")
    mod.resolveDependencyVersionsFromDepsMgmnt(app)
    mod.resolveProperties(app)
    if #app.currentUrlsToFetch > 0 or #app.nextUrlsToFetch > 0 then
        log.write("[INFO ] Huh?!? ".. app.currentUrlsToFetch .." ".. app.nextUrlsToFetch .."\n")
        table.insert(app.taskQueue, function()mod.fetchAnotherMvnArtifact(app)end)
        return 
    end
    --mod.storeAsSqliteFile(app)
    mod.printStuffAtEnd(app)
end


function mod.run( app )
    table.insert(app.taskQueue, function()mod.fetchAnotherMvnArtifact(app)end)
    while true do
        local task = table.remove(app.taskQueue, 1)
        if not task then break end
        task()
    end
    mod.onNoMorePomsToFetch(app)
end


function mod.main()
    local app = objectSeal{
        http = newHttpClient{},
        mvnArtifacts = {},
        mvnArtifactsNotFound = {},
        mvnPropsByArtifact = {},
        mvnDepsByArtifact = {},
        mvnMngdDepsByArtifact = {},
        taskQueue = {},
        sqliteOutFile = false,
        -- Set of URLs that are currently processed
        currentUrlsToFetch = {},
        -- Set of URLs that need to be fetchet later (eg bcause dependency not fetched yet)
        nextUrlsToFetch = {
            -- TODO place URLs here (bcause there's no API to do this yet)
            { artifactId = "trin-web", version = "02.01.07.00", groupId = "ch.post.it.paisa.trin" },
        },
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


--startOrExecute(nil, mod.main)
startOrExecute(mod.main)
