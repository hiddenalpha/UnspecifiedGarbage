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
local LOGDBG = (false)and(function(msg)log:write("[DEBUG] "..msg)end)or(function()end)


function mod.printHelp()
    out:write("\n"
        .."  Collecting dependency information by scanning maven poms\n"
        .."\n"
        .."  Options:\n"
        .."\n"
        .."    --yolo\n"
        .."      WARN: only use if you know what you're doing!\n"
        .."\n"
        .."    --state <path>\n"
        .."      Data file to update.\n"
        .."\n"
        .."\n")
end


function mod.parseArgs( app )
    local iA = 0
    local isYolo = false
::nextArg::
    iA = iA + 1
    local arg = _ENV.arg[iA]
    if not arg then
        goto endOfArgs
    elseif arg == "--help" then
        mod.printHelp() return -1
    elseif arg == "--yolo" then
        isYolo = true
    elseif arg == "--state" then
        iA = iA + 1
        arg = _ENV.arg[iA]
        if not arg then log:write("Arg --sqliteOut needs value\n")return-1 end
        app.sqliteFile = arg
    else
        log:write("Unexpected arg: "..tostring(arg).."\n")return -1
    end
    goto nextArg
::endOfArgs::
    if not isYolo then log:write("Bad Args\n") return -1 end
    return 0
end


function mod.strTrim( str )
    if not str then return str end
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end


function mod.processXmlValue( pomParser )
    local app = pomParser.app
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
        -- need to trim values
        mvnArtifact.groupId = mod.strTrim(mvnArtifact.groupId)
        mvnArtifact.artifactId = mod.strTrim(mvnArtifact.artifactId)
        mvnArtifact.version = mod.strTrim(mvnArtifact.version)
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
    if app.mvnArtifactsAlreadyParsed[key] then
        LOGDBG("do NOT enqueue bcause have already: ".. mvnArtifact.artifactId .." ".. mvnArtifact.version .."\n")
        return
    end
    app.mvnArtifactsAlreadyParsed[key] = true -- TODO maybe should do this in another place
    table.insert(app.nextUrlsToFetch, {
        artifactId = mvnArtifact.artifactId,
        version = mvnArtifact.version,
        groupId = mvnArtifact.groupId,
    })
end


function mod.newPomParser( app, cls )
    local pomParser = objectSeal{
        app = app,
        outerCls = cls,
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
    pomParser.base = newXmlParser{
        cls = pomParser,
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
            local app = pomParser.app
            local mvnArtifact = pomParser.mvnArtifact
            pomParser.mvnArtifact = false
            if not mvnArtifact.groupId then mvnArtifact.groupId = mvnArtifact.parentGroupId end
            if not mvnArtifact.version then mvnArtifact.version = mvnArtifact.parentVersion end
            local key = mod.getMvnArtifactKey(mvnArtifact)
            if app.mvnArtifacts[key] then
                log:write("[WARN ] Already have  aid=".. mvnArtifact.artifactId
                    ..", ver=".. mvnArtifact.version ..", gid=".. mvnArtifact.groupId .."\n")
                return
            end
            app.mvnArtifacts[key] = mvnArtifact
            table.insert(app.taskQueue, function()
                mod.onNewArtifactGotFetched(app, mvnArtifact)
            end)
        end,
    }
    return pomParser
end


function mod.fetchMvnArtifactFromFileOrElseSrcNr( app, mvnArtifact, repoDir, pomSrcNrFallback )
    local path = repoDir
        .."/".. mvnArtifact.groupId:gsub('%.','/')
        .."/".. mvnArtifact.artifactId
        .."/".. mvnArtifact.version
        .."/".. mvnArtifact.artifactId .."-".. mvnArtifact.version
        ..".pom"
    local fd = io.open(path, "rb")
    if not fd then
        log:write("ENOENT ".. path .."\n")
        mod.fetchFromSourceNr(app, mvnArtifact, pomSrcNrFallback)
        return
    end
    log:write("fopen(\"".. path .."\", \"rb\")\n")
    local file = objectSeal{
        base = false,
        pomParser = false,
    }
    file.pomParser = mod.newPomParser(app, false)
    while true do
        local buf = fd:read(1<<16)
        if not buf then break end
        local ok, emsg = pcall(file.pomParser.write, file.pomParser, buf)
        if not ok then
            log:write("EMSG:\n".. emsg .."\n\n")
            if emsg:find("^%[[^]]+%]:%d+: XMLParseError .+ unknown encoding") then
                log:write("[ERROR] Ignore: ".. emsg .."\n")
                sleep(3)
                return
            end
            error(emsg)
        end
    end
    file.pomParser:closeSnk()
end


function mod.fetchMvnArtifactFromWebserverOrElseSrcNr( app, mvnArtifact, baseUrl, pomSrcNrFallback )
    local aid = assert(mvnArtifact.artifactId)
    local ver = assert(mvnArtifact.version)
    local gid = assert(mvnArtifact.groupId)
    local pomUrl = baseUrl .."/paisa/".. gid:gsub('%.','/')
        .."/".. aid .."/".. ver .."/".. aid .."-".. ver ..".pom"
    local proto = pomUrl:match("^(https?)://")
    local isTLS = (proto:upper() == "HTTPS")
    local host = pomUrl:match("^https?://([^:/]+)[:/]")
    local port = pomUrl:match("^https?://[^:/]+:(%d+)[^%d]")
    local url = pomUrl:match("^https?://[^/]+(.*)$")
    if port == 443 then isTLS = true end
    if not port then port = (isTLS and 443 or 80) end
::doHttpRequest::
    log:write("> GET ".. proto .."://".. host ..":".. port .. url .."\n")
    local req = objectSeal{
        app = app,
        base = false,
        pomParser = false,
        artifactId = aid, -- so we know what we're trying to fetch
        version = ver, -- so we know what we're trying to fetch
        groupId = gid, -- so we know what we're trying to fetch
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
    local ok, emsg = pcall(req.base.closeSnk, req.base)
    if not ok then
        if emsg:find("^ENOMSG") then
            log:write("ENOMSG Artifactory closed connection appruptly?!? Retry in a few seconds ....\n"); sleep(7)
            goto doHttpRequest
        end
        error(emsg)
    end
end


function mod.fetchFromSourceNr( app, mvnArtifact, pomSrcNr )
    if not pomSrcNr then pomSrcNr = 1 end
    local pomSrc = app.pomSources[pomSrcNr]
    if not pomSrc then
        mod.onNoMorePomSources(app, mvnArtifact)
    end
    -- pom source ready to use
    if false then
    elseif pomSrc.type == "local-file-cache" then
        --LOGDBG("Fetch from local file cache\n")
        mod.fetchMvnArtifactFromFileOrElseSrcNr(app, mvnArtifact, pomSrc.repoDir, pomSrcNr + 1)
    elseif pomSrc.type == "webserver" then
        --LOGDBG("Fetch from webserver\n")
        mod.fetchMvnArtifactFromWebserverOrElseSrcNr(app, mvnArtifact, pomSrc.baseUrl, pomSrcNr + 1)
    else
        error("Whops. pomSources[i].type is ".. pomSrc.type)
    end
end


function mod.fetchAnotherMvnArtifact( app, pomSrcNr )
::findNextArtifactToFetch::
    local mvnArtifact
    mvnArtifact = table.remove(app.currentUrlsToFetch, 1)
    if not mvnArtifact then
        assert(#app.currentUrlsToFetch == 0)
        if #app.nextUrlsToFetch > 0 then -- switch to next set to process
            --LOGDBG("currentUrlsToFetch drained. Continue with nextUrlsToFetch\n")
            app.currentUrlsToFetch = app.nextUrlsToFetch
            app.nextUrlsToFetch = {}
            goto findNextArtifactToFetch
        end
        return
    end
    assert(mvnArtifact)
    mod.fetchFromSourceNr(app, mvnArtifact, 1)
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
            --LOGDBG("Enqueue parent:  aid=".. mvnArtifact.parentArtifactId
            --    .."  v=".. mvnArtifact.parentVersion.."  gid=".. mvnArtifact.parentGroupId .."\n")
            mod.onMvnArtifactThatShouldBeFetched(app, objectSeal{
                artifactId = mvnArtifact.parentArtifactId,
                version = mvnArtifact.parentVersion,
                groupId = mvnArtifact.parentGroupId,
            })
        end
    end
    local deps = app.mvnDepsByArtifact[mvnArtifact]
    if not deps then
        --LOGDBG("Has no dependencies:  aid="..tostring(mvnArtifact.artifactId)
        --    ..", ver="..tostring(mvnArtifact.version)..", gid="..tostring(mvnArtifact.groupId).."\n")
        return
    end
    for _,dep in pairs(deps) do
        local isIncomplete = (not dep.artifactId or not dep.version or not dep.groupId)
        local hasUnresolvedMvnProps = false
        if not isIncomplete then
            hasUnresolvedMvnProps = (dep.artifactId:find("${",0,true) or dep.version:find("${",0,true) or dep.groupId:find("${",0,true))
        end
        if isIncomplete or hasUnresolvedMvnProps then
            --LOGDBG("Incomplete. Give up  aid="..tostring(dep.artifactId)
            --    .."  v="..tostring(dep.version).."  gid="..tostring(dep.groupId).."\n")
        else
            LOGDBG("Enqueue dependency:  aid="..tostring(dep.artifactId)
                .."  v="..tostring(dep.version).."  gid="..tostring(dep.groupId).."\n")
            --if dep.artifactId:find("\n") or dep.version:find("\n") or dep.groupId:find("\n") then
            --    log:write("Wanted by  aid="..tostring(mvnArtifact.artifactId)
            --        ..", ver="..tostring(mvnArtifact.version)
            --        ..", gid="..tostring(mvnArtifact.groupId).."\n");
            --    error("WTF?!?")
            --end
            mod.onMvnArtifactThatShouldBeFetched(app, objectSeal{
                artifactId = dep.artifactId,
                version = dep.version,
                groupId = dep.groupId,
            })
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
        return
    elseif msg.status ~= 200 then
        for i, h in ipairs(msg.headers) do
            log:write("< ".. h[1] ..": ".. h[2] .."\n")
        end
        log:write("< \n")
        error("Unexpected HTTP ".. tostring(msg.status))
    end
    assert(not req.pomParser)
    req.pomParser = mod.newPomParser(app, req)
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
        local parent
        if mvnArtifact.parentArtifactId then -- has its parent declared
            parent = mvnArtifacts[mod.getMvnArtifactKey{
                groupId = mvnArtifact.parentGroupId,
                artifactId = mvnArtifact.parentArtifactId,
                version = mvnArtifact.parentVersion,
            }];
        end
        if parent then -- parent exists
            funcs.resolveForDependency(parent, mvnDependency)
        end
    end
    function funcs.resolveForArtifact( mvnArtifact )
        --LOGDBG("resolveForArtifact("..mvnArtifact.artifactId..", ".. mvnArtifact.version ..")\n")
        local mvnDeps = mvnDepsByArtifact[mvnArtifact]
        if not mvnDeps then return end
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
                    mvnDependency.version = mod.strTrim(propVal)
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
        LOGDBG("Cannot resolve ${"..propKey.."}\n")
        return nil
    end
    return mod.getPropValThroughParentChain(app, parent, propKey)
end


function mod.printStuffAtEnd( app )
    if true then return end
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


function mod.getOrNewStringId( app, str )
    local err -- serves as tmp and retval
    local db, ok, emsg, rs, stringId, stmt, stmtStr
    -- serve from memory if possible
    if not str then err = nil; goto endFn end
    stringId = app.cachedStringIds[str]
    if stringId then err = stringId; goto endFn end
    -- serve from DB if possible.
    db = app.db
    stmtStr = "SELECT id FROM String WHERE str = :str"
    stmt = app.stmtCache[stmtStr]
    if not stmt then stmt = db:prepare(stmtStr); app.stmtCache[stmtStr] = stmt end
    stmt:reset()  stmt:bind(":str", str)
    rs = stmt:execute()
    if rs:next() then -- already exists. re-use
        err = rs:value(1)
        app.cachedStringIds[str] = err
        goto endFn
    end
    -- no such string yet. create.
    stmtStr = "INSERT INTO String (str) VALUES (:str)"
    stmt = app.stmtCache[stmtStr]
    if not stmt then stmt = db:prepare(stmtStr); app.stmtCache[stmtStr] = stmt end
    stmt:reset();  stmt:bind(":str", str);
    ok, emsg = pcall(stmt.execute, stmt)
    if not ok then
        log:write("String: \"".. str .."\"\n")
        error(emsg)
    end
    err = db:lastInsertRowid()
    app.cachedStringIds[str] = err
::endFn::
    --LOGDBG("dbStr(\""..tostring(str).."\") -> "..tostring(err).."\n");
    return err
end


function mod.insertMvnArtifact( app, mvnArtifact )
    local a = mvnArtifact
    assert(a.groupId and a.artifactId and a.version)
    if a.parentGroupId then assert(a.parentArtifactId and a.parentVersion)
    else assert(not a.parentArtifactId and not a.parentVersion) end
    -- Get needed string IDs
    local gid = mod.getOrNewStringId(app, a.groupId)
    local aid = mod.getOrNewStringId(app, a.artifactId)
    local ver = mod.getOrNewStringId(app, a.version)
    local pgid = mod.getOrNewStringId(app, a.parentGroupId)
    local paid = mod.getOrNewStringId(app, a.parentArtifactId)
    local pver = mod.getOrNewStringId(app, a.parentVersion)
    -- look if it already exists
    local db = app.db
    local stmtStr = "SELECT id from MvnArtifact"
        .." WHERE artifactId = :aid AND version = :ver AND groupId = :gid"
        .."   AND parentArtifactId = :paid AND parentVersion = :pver AND parentGroupId = :pgid"
    local stmt = app.stmtCache[stmtStr]
    if not stmt then stmt = db:prepare(stmtStr); app.stmtCache[stmtStr] = stmt end
    stmt:reset()
    stmt:bind(":aid", aid) stmt:bind(":ver", ver) stmt:bind(":gid", gid)
    stmt:bind(":paid", paid) stmt:bind(":pver", pver) stmt:bind(":pgid", pgid)
    local rs = stmt:execute()
    local dbId
    if rs:next() then
        -- Already exists
        dbId = assert(rs:value(1))
    else
        -- no such record. create it.
        local stmtStr = "INSERT INTO MvnArtifact"
            .."('groupId', 'artifactId', 'version', 'parentGroupId', 'parentArtifactId', 'parentVersion')"
            .."VALUES"
            .."(:groupId , :artifactId , :version , :parentGroupId , :parentArtifactId , :parentVersion )"
        local stmt = app.stmtCache[stmtStr]
        if not stmt then stmt = db:prepare(stmtStr); app.stmtCache[stmtStr] = stmt end
        stmt:reset()
        stmt:bind(":groupId", gid)
        stmt:bind(":artifactId", aid)
        stmt:bind(":version", ver)
        stmt:bind(":parentGroupId", pgid)
        stmt:bind(":parentArtifactId", paid)
        stmt:bind(":parentVersion", pver)
        stmt:execute()
        dbId = assert(db:lastInsertRowid())
    end
    app.cachedMvnArtifactDbIds[a] = dbId
    local bucket = app.mvnArtifactIdsByArtif[assert(a.artifactId)]
    if not bucket then bucket = {} app.mvnArtifactIdsByArtif[a.artifactId] = bucket end
    table.insert(bucket, { dbId = dbId, mvnArtifact = a, })
    return dbId
end


function mod.storeAsSqliteFile( app )
    local stmt
    if not app.sqliteFile then
        log:write("[INFO ] No state file provided. Skip export.\n")
        return
    end
    local db = app.db
    -- Query:  List artifacts
    --   SELECT GroupId.str AS 'GID', ArtifactId.str AS 'AID', Version.str AS 'Version'
    --   FROM MvnArtifact AS A
    --   JOIN String GroupId ON GroupId.id = A.groupId
    --   JOIN String ArtifactId ON ArtifactId.id = A.artifactId
    --   JOIN String Version ON Version.id = A.version
    --   ORDER BY GroupId.str, ArtifactId.str, Version.str
    --   ;
    -- Query:  List Artifacts with parents:
    --   SELECT GroupId.str AS 'GID', ArtifactId.str AS 'AID', Version.str AS 'Version', ParentGid.str AS 'ParentGid', ParentAid.str AS 'ParentAid', ParentVersion.str AS 'ParentVersion'
    --   FROM MvnArtifact AS A
    --   JOIN String GroupId ON GroupId.id = A.groupId
    --   JOIN String ArtifactId ON ArtifactId.id = A.artifactId
    --   JOIN String Version ON Version.id = A.version
    --   JOIN String ParentGid ON ParentGid.id = A.parentGroupId
    --   JOIN String ParentAid ON ParentAid.id = A.parentArtifactId
    --   JOIN String ParentVersion ON ParentVersion.id = A.parentVersion
    --   ORDER BY GroupId.str, ArtifactId.str, Version.str
    --   ;
    -- Query:  List dependencies:
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
    --   ORDER BY GroupId.str, ArtifactId.str, Version.str
    --   ;
    -- Store artifacts
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        mod.insertMvnArtifact(app, mvnArtifact)
        local mvnDeps = app.mvnDepsByArtifact[mvnArtifact] or {}
        -- dependencies are nothing else than artifacts
        for _, mvnDep in pairs(mvnDeps) do
            -- TODO?!?
        end
    end
    -- Store dependencies
    for _, mvnArtifact in pairs(app.mvnArtifacts) do
        local mvnDeps = app.mvnDepsByArtifact[mvnArtifact]
        for _, mvnDep in pairs(mvnDeps or {}) do
            if not mvnDep.version then mvnDep.version = "TODO_5bbc0e87011e24d845136c5406302616" end
            assert(mvnDep.version, mvnDep.artifactId)
            assert(mvnDep.groupId and mvnDep.artifactId and mvnDep.version)
            local bucket = app.mvnArtifactIdsByArtif[mvnDep.artifactId]
            local depId = nil
            for _,a in pairs(bucket or {}) do
                if  mvnDep.groupId == a.mvnArtifact.groupId
                and mvnDep.artifactId == a.mvnArtifact.artifactId
                and mvnDep.version == a.mvnArtifact.version then
                    depId = assert(a.dbId)
                end
            end
            if not depId then -- Artifact not stored yet. Do now.
                depId = mod.insertMvnArtifact(app, {
                    groupId = mvnDep.groupId,
                    artifactId = mvnDep.artifactId,
                    version = mvnDep.version,
                })
            end
            -- maybe already in db?
            local stmtStr = "SELECT id FROM MvnDependency"
                .." WHERE mvnArtifactId = :mvnArtifactId AND needsMvnArtifactId = :needsMvnArtifactId"
            local stmt = app.stmtCache[stmtStr];
            if not stmt then stmt = db:prepare(stmtStr); app.stmtCache[stmtStr] = stmt end
            stmt:reset()
            stmt:bind(":mvnArtifactId", app.cachedMvnArtifactDbIds[mvnArtifact])
            stmt:bind(":needsMvnArtifactId", depId)
            local rs = stmt:execute()
            if not rs:next() then -- not yet in db. create.
                local stmtStr = "INSERT INTO MvnDependency"
                    .."('mvnArtifactId', 'needsMvnArtifactId')"
                    .."VALUES"
                    .."(:mvnArtifactId , :needsMvnArtifactId )"
                local stmt = app.stmtCache[stmtStr]
                if not stmt then stmt = db:prepare(stmtStr); app.stmtCache[stmtStr] = stmt end
                stmt:reset()
                stmt:bind(":mvnArtifactId", assert(app.cachedMvnArtifactDbIds[mvnArtifact]))
                stmt:bind(":needsMvnArtifactId", assert(depId, mvnDep.artifactId))
                stmt:execute()
            end
        end
    end
end


function mod.dbOpen( app )
    assert(not app.db)
    app.db = newSqlite{
        database = app.sqliteFile,
    }
    local db = app.db
    db:prepare("BEGIN TRANSACTION"):execute()
    db:enhancePerf()
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
    --db:prepare("CREATE TABLE MvnProperty ("
    --    .." id INTEGER PRIMARY KEY,"
    --    .." keyStringId INT,"
    --    .." valStringId INT)"
    --):execute()
end


function mod.dbCommit( app )
    app.db:prepare("END TRANSACTION"):execute()
    app.db:close()
    app.db = nil
end


function mod.run( app )
    mod.dbOpen(app)
    table.insert(app.taskQueue, function()mod.fetchAnotherMvnArtifact(app)end)
    while true do
        local task = table.remove(app.taskQueue, 1)
        if not task then
            if #app.currentUrlsToFetch > 0 or #app.nextUrlsToFetch > 0 then
                log:write("[WARN ] Huh2?!? ".. #app.currentUrlsToFetch .." ".. #app.nextUrlsToFetch
                    ..". Why are there still entries? Keep looping.\n")
                table.insert(app.taskQueue, function()mod.fetchAnotherMvnArtifact(app)end)
                goto nextTask
            end
            if #app.taskQueue > 0 then -- TODO fix this würgaround
                goto nextTask
            else
                break
            end
        end
        task()
        ::nextTask::
    end
    mod.resolveDependencyVersionsFromDepsMgmnt(app)
    mod.resolveProperties(app)
    if #app.currentUrlsToFetch > 0 or #app.nextUrlsToFetch > 0 then
        log:write("[WARN ] ".. #app.currentUrlsToFetch .." ".. #app.nextUrlsToFetch
            ..". Why are there entries again?!?.\n")
        error("WTF?!?")
        return
    end
    mod.printStuffAtEnd(app)
    mod.storeAsSqliteFile(app)
    mod.dbCommit(app)
end


function mod.main()
    local app = objectSeal{
        http = newHttpClient{},
        mvnArtifacts = {},
        mvnArtifactsAlreadyParsed = {},
        mvnArtifactsNotFound = {},
        mvnArtifactIdsByArtif = {},
        mvnPropsByArtifact = {},
        mvnDepsByArtifact = {},
        mvnMngdDepsByArtifact = {},
        taskQueue = {},
        db = false,
        sqliteFile = false,
        stmtCache = {},
        cachedMvnArtifactDbIds = {},
        cachedStringIds = {},
        pomSources = {
            objectSeal{ type = "local-file-cache", repoDir = "C:/Users/fankhauseand/.m2/repository", },
            objectSeal{ type = "webserver", baseUrl = "http://127.0.0.1:8081/tmp/artifactory", },
            --objectSeal{ type = "webserver", baseUrl = "https://artifactory.pnet.ch/artifactory", },
        },
        -- Set of URLs that are currently processed
        currentUrlsToFetch = {},
        -- Set of URLs that need to be fetchet later (eg bcause dependency not fetched yet)
        nextUrlsToFetch = {
            -- TODO place URLs here (bcause there's no API to do this yet)
            --{ artifactId = "trin-web", version = "02.01.07.00", groupId = "ch.post.it.paisa.trin" },
        },
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


--startOrExecute(nil, mod.main)
startOrExecute(mod.main)
