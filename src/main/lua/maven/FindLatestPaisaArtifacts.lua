
--local AF_INET = require('scriptlee').posix.AF_INET
--local AF_INET6 = require('scriptlee').posix.AF_INET6
--local IPPROTO_TCP = require('scriptlee').posix.IPPROTO_TCP
--local SOCK_STREAM = require('scriptlee').posix.SOCK_STREAM
--local inaddrOfHostname = require('scriptlee').posix.inaddrOfHostname
local newHttpClient = require("scriptlee").newHttpClient
--local newSqlite = require("scriptlee").newSqlite
local newTlsClient = assert(require("scriptlee").newTlsClient)
--local newXmlParser = require("scriptlee").newXmlParser
local objectSeal = require("scriptlee").objectSeal
local sleep = require("scriptlee").posix.sleep
--local socket = require('scriptlee').posix.socket
local startOrExecute = require("scriptlee").reactor.startOrExecute

local out, log = io.stdout, io.stderr
local mod = {}
local LOGDBG = (true)and(function(msg)log:write("[DEBUG] "..msg)end)or(function()end)


function mod.printHelp()
    out:write("\n"
        .."  List latest PAISA maven artifacts\n"
        .."\n"
        .."  Options:\n"
        .."\n"
        .."    --yolo\n"
        .."      WARN: only use if you know what you're doing!\n"
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
    else
        log:write("Unexpected arg: "..tostring(arg).."\n")return -1
    end
    goto nextArg
::endOfArgs::
    if not isYolo then log:write("Bad Args\n") return -1 end
    return 0
end


function mod.compareVersion(a, b)
    local semverFmt = "^(%d+)%.(%d+)%.(%d+)"
    local gagaFmt   = "^(%d+)%.(%d+)%.(%d+)%.(%d+)"
    -- parse
    local amaj, amin, apat, abui = a:match(semverFmt)
    if not amaj then amaj, amin, apat, abui = a:match(gagaFmt) end
    local bmaj, bmin, bpat, bbui = b:match(semverFmt)
    if not bmaj then bmaj, bmin, bpat, bbui = b:match(gagaFmt) end
    -- compare
    --LOGDBG("CMP "..tostring(a).."  VS  "..tostring(b).."\n")
    local diff = amaj - bmaj
    if diff ~= 0 then return diff end
    diff = amin - bmin
    if diff ~= 0 then return diff end
    diff = apat - bpat
    if diff ~= 0 then return diff end
    if abui and not bbui then return  1 end
    if not abui and bbui then return -1 end
    if not abui and not bbui then return 0 end
    diff = abui - bbui
    if diff ~= 0 then return diff end
    return 0
end


function mod.newWebDirListParser( app, opts )
    local cb_cls = opts.cls
    local cb_onEntry = opts.onEntry
    local cb_onEnd = opts.onEnd
    opts = nil
    local t = {
        collected = {},
    }
    local m = {
        write = function( t, buf )
            table.insert(t.collected, buf)
        end,
        closeSnk = function( t )
            local buf = table.concat(t.collected)
            local iter = buf:gmatch('<a href%="([^"]+)">[^<]+</a> +%d+%-%a+%-%d+ %d+:%d+[^\n]+\n')
            for aid,_ in iter do
                cb_onEntry(aid, cb_cls)
            end
            cb_onEnd(cb_cls)
        end,
        __index = false,
    } m.__index = m
    return setmetatable(t, m)
end


function mod.onMvnPomFoundInArtifactory( app, path )
    local gid, aid, ver, aid, ver = path:match(
        "^/artifactory/paisa/(.+)/([^/]+)/([^/]+)/([^/]+)-([^/]+).pom")
    if not gid or not aid or not ver then
        log:write("input: \"".. path .."\"\n")
        error("Failed to extract artifact identity")
    end
    gid = gid:gsub('/', '.')
    out:write("r;".. gid ..";".. aid ..";".. ver .."\n")
end


function mod.onArtifactSubdirFoundInArtifactory( app, path )
    assert(not path:find("/$"), path)
    path = path .."/"
    --if path:len() > 37 and not path:find("^/artifactory/paisa/ch/post/it/paisa/preflux") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/[^/]+/[^-]+%-config/") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/[^/]+/[^-]+%-domain/") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/[^/]+/[^-]+%-test/") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/alice") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/aseed") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/data/resources/paisa%-data%-resources%-") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/data/transformer/") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/paisa-devpack") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/paisa-pom") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/paisa-superpom") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/tragula") then goto skipThisPath end
    if path:find("^/artifactory/paisa/ch/post/it/paisa/tyro") then goto skipThisPath end
    goto doHttpRequest
::skipThisPath::
    --LOGDBG("ignore '".. path .."'\n")
    if true then return end
::doHttpRequest::
    local req = objectSeal{
        base = false,
        rspStatus = false,
        rspParser = false,
        listOfChilds = false,
    }
    local reqMethod = "GET"
    --LOGDBG(reqMethod .." ".. path .."\n")
    req.base = app.http:request{
        cls = req,
        host = app.artifactoryInaddr,
        port = app.artifactoryPort,
        method = reqMethod,
        url = path,
        onRspHdr = function( rsp, req )
            req.rspStatus = rsp.status
            if req.rspStatus ~= 200 then
                log:write("REQ  ".. reqMethod .." ".. path .."\n")
                log:write("RSP  ".. rsp.proto .." ".. rsp.status .." ".. rsp.phrase .."\n")
                for _,hdr in ipairs(rsp.headers) do
                    log:write("RSP  ".. hdr[1] ..": ".. hdr[2] .."\n")
                end
                log:write("RSP  \n")
            end
            req.listOfChilds = {}
        end,
        onRspChunk = function( buf, req )
            if req.rspStatus ~= 200 then
                log:write("RSP  ".. buf:gsub('\n', '\nRSP  ') ..'\n')
                return
            end
            req.rspParser:write(buf)
        end,
        onRspEnd = function()
            if req.rspStatus ~= 200 then return end
            req.rspParser:closeSnk()
            req.rspStatus = "OK"
        end,
    }
    req.rspParser = mod.newWebDirListParser(app, {
        cls = req,
        onEntry = function( e, req ) table.insert(req.listOfChilds, e) end,
        onEnd = function( req ) end,
    })
    local ok, emsg = pcall(req.base.closeSnk, req.base)
    if not ok then
        if emsg:find("^ENOMSG") then -- No idea why artifactory does this sometimes
            log:write(tostring(emsg).."\n")
            log:write("sleep(7) ...\n"); sleep(7)
            goto doHttpRequest
        end
        error(emsg)
    end
    if req.rspStatus ~= "OK" then error("Unexpected response") end
    -- Cleanup childs
    local old, childs, poms
    old = req.listOfChilds
    childs = {}
    poms = {}
    for _,child in pairs(req.listOfChilds) do
        if child:find("^%d+%.%d+%.%d+%-") then goto skipThisChild end -- Skip pre-release (semver)
        if child:find("^%d+%.%d+%.%d+%.%d+%-") then goto skipThisChild end -- Skip pre-release (döns format)
        if child:find("/$") then
            table.insert(childs, child)
            goto nextChild
        end
        if child:find("%.pom$") then
            --LOGDBG("Keep  \""..tostring(child).."\"  (type=POM)\n")
            table.insert(poms, child)
            goto nextChild
        end
        ::skipThisChild::
        --LOGDBG("Skip  \""..tostring(child).."\"\n")
        ::nextChild::
    end
    -- Drop obsolete releases: Find versions, sort them, keep only bunch of
    -- what looks recent enough.
    local versionAlike = {}
    local iC = 0
    while iC < #childs do iC = iC + 1   -- Collect things that look like versions
        local child = childs[iC]
        if child:find("^%d+%.%d+%.%d+") or child:find("^%d+%.%d+%.%d+%.%d+") then
            table.remove(childs, iC)
            table.insert(versionAlike, child)
            iC = iC - 1
        end
    end
    table.sort(versionAlike, function(a, b) return mod.compareVersion(b, a) < 0 end)
    iC = 0
    for k, v in ipairs(versionAlike) do
        iC = iC + 1; if iC > 1 then break end -- add only a few
        --LOGDBG("Keep  \""..tostring(versionAlike[iC]).."\"\n")
        table.insert(childs, versionAlike[iC])
    end
    -- Process POMs
    for _, pom in pairs(poms) do
        mod.onMvnPomFoundInArtifactory(app, path .. pom)
    end
    -- Process childs
    for _,child in pairs(childs) do
        mod.onArtifactSubdirFoundInArtifactory(app, path .. child:gsub('/$',''))
    end
end


function mod.run( app )
    mod.onArtifactSubdirFoundInArtifactory(app, "/artifactory/paisa/ch/post/it/paisa")
end


function mod.main()
    local app = objectSeal{
        http = newHttpClient{},
        artifactoryInaddr = "artifactory.pnet.ch",
        artifactoryPort = 443,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    mod.run(app)
end


startOrExecute(mod.main)

