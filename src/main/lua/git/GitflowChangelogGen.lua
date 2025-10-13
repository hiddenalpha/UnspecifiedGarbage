
local log = io.stderr
local main


function printHelp()
    io.stdout:write("  \n"
        .."  Helper to extract essential data from a gitflow log which potentially\n"
        .."  is useful to write a CHANGELOG from.\n"
        .."  \n"
        .."  Options:\n"
        .."  \n"
        .."    --svcName <str>\n"
        .."      Eg: 'preflux', 'trin', ...\n"
        .."  \n"
        .."    --since <date>\n"
        .."        Ignore commits with this ISO date and older.\n"
        .."  \n"
        .."    --remote <str>\n"
        .."      Name of the git remote to use. Defaults to 'upstream'.\n"
        .."  \n"
        .."    --no-fetch\n"
        .."      Do NOT update refs from remote. Just use what we have local.\n"
        .."  \n"
        .."    --tags\n"
        .."      Pass '--tags' to git-log.\n"
        .."  \n"
        .."    --markdown\n"
        .."      Produce markdown output.\n"
        .."  \n"
        .."    --html\n"
        .."      Produce HTML output.\n"
        .."  \n"
        )
end


function parseArgs( app )
    local iA = 0
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
        elseif arg == "--svcName" then
            iA = iA + 1; arg = _ENV.arg[iA]
            if not arg then log:write("EINVAL: --svcName needs value\n")return end
            if arg ~= "preflux" and arg ~= "trin" and arg ~= "paisa-api" then
                log:write("ENOTSUP: TODO impl svcName '".. arg .."'\n")return
            end
            app.svcName = arg
        elseif arg == "--since" then
            iA = iA + 1; arg = _ENV.arg[iA]
            if not arg then log:write("EINVAL: --since needs value\n")return end
            app.since = arg
        elseif arg == "--remote" then
            iA = iA + 1; arg = _ENV.arg[iA]
            if not arg then log:write("EINVAL: --remote needs value\n")return end
            app.remoteName = arg
        elseif arg == "--no-fetch" then
            app.isFetch = false
        elseif arg == "--tags" then
            app.isTags = true
        elseif arg == "--html" then
            app.isPrintHtml = true
        elseif arg == "--markdown" then
            app.isPrintMarkdown = true
        elseif arg == "--help" then
            app.isHelp = true; return 0
        else
            log:write("EINVAL: ".. arg .."\n")return
        end
    end
    if not app.since then log:write("EINVAL: --since missing\n")return end
    if not app.remoteName then app.remoteName = "upstream" end
    if not app.svcName then log:write("EINVAL: --svcName missing\n")return end
    local i = 0
    if app.isPrintHtml then i = i + 1 end
    if app.isPrintMarkdown then i = i + 1 end
    if i > 1 then log:write("EINVAL: Too many output formats given.\n")return end
    return 0
end


function readCommitHdr( app )
    --log:write("[DEBUG] parse hdr from '".. app.fullHistory:sub(app.fullHistoryRdBeg, app.fullHistoryRdBeg+256) .."...'\n")
    local f, t = app.fullHistory:find("^"
        .."commit ........................................[^\n]*\n"
        .."Merge: [0-9a-z]+ [0-9a-z]+\n"
        .."Author: [^\n]+\n"
        .."Date:   [^\n]+\n"
        .."\n"
        , app.fullHistoryRdBeg)
    if not f then f, t = app.fullHistory:find("^"
        .."commit ........................................[^\n]*\n"
        .."Author: [^\n]+\n"
        .."Date:   [^\n]+\n"
        .."\n"
        , app.fullHistoryRdBeg) end
    if not f then
        assert(app.fullHistory:len() == app.fullHistoryRdBeg-1, app.fullHistory:len()..", "..app.fullHistoryRdBeg)
        app.parseFn = false
        return
    end
    app.commitHdr = assert(app.fullHistory:sub(f, t-1))
    --log:write("hdrBeginsWith '"..(app.commitHdr:sub(1, 32)).."...'\n")
    app.fullHistoryRdBeg = t + 1
    --log:write("hdr parsed. rdCursr now points to '".. app.fullHistory:sub(app.fullHistoryRdBeg, app.fullHistoryRdBeg+16) .."...'\n")
    app.parseFn = assert(readCommitMsg)
end


function readCommitMsg( app )
    local idxOfC = app.fullHistoryRdBeg
    local chrPrev = false
    while true do idxOfC = idxOfC + 1
        local chr = app.fullHistory:byte(idxOfC)
        --log:write("CHR '"..tostring(app.fullHistory:sub(idxOfC, idxOfC)).."'\n")
        if (chr == 0x63) and chrPrev == 0x0A then
            idxOfC = idxOfC - 1
            break -- LF followed by 'c' (aka 'commit') found
        elseif not chr then
            idxOfC = idxOfC - 1
            break
        else
            chrPrev = assert(chr)
        end
    end
    local mtch = app.fullHistory:sub(app.fullHistoryRdBeg, idxOfC - 1)
    assert(mtch)
    while mtch:byte(mtch:len()) == 0x0A do mtch = mtch:sub(1, -2) end
    mtch = mtch:gsub("\n    ", "\n"):gsub("^    ", "")
    app.commitMsg = mtch
    app.fullHistoryRdBeg = idxOfC + 1
    app.parseFn = readCommitHdr
    --log:write("msg parsed. rdCursr now points to '".. app.fullHistory:sub(app.fullHistoryRdBeg, app.fullHistoryRdBeg+16) .."...'\n")
    table.insert(app.commits, {
        hdr = assert(app.commitHdr),
        msg = assert(app.commitMsg),
    })
end


function newTextPrinter( app, dst )
    return { append = function( t, entry )
        dst:write("\n\n")
        dst:write(entry.date .." - ".. entry.version .."\n\n")
        for k, msg in ipairs(entry.msgs) do
            if msg.jiraNr then
                dst:write("[".. msg.jiraNr .."] ")
            end
            dst:write(msg.body)
            if prNr then dst:write(" (PR ".. prNr ..")") end
            dst:write("\n")
        end
        dst:write("\n")
    end }
end


function newHtmlPrinter( app, dst )
    return { append = function( t, entry )
        dst:write('\n\n\n<h3>'.. entry.date .." - ".. entry.version .."</h3>\n\n")
        for k, msg in ipairs(entry.msgs) do
            if msg.jiraNr then
                dst:write(""
                    ..'[<a href="https://jira.post.ch/browse/'.. msg.jiraNr ..'">'
                    .. msg.jiraNr .."</a>] ")
            end
            dst:write(msg.body)
            if msg.prNr then
                dst:write(""
                    ..' (<a href="https://gitit.post.ch/projects/ISA/repos/'.. app.svcName ..'/pull-requests/'
                    .. msg.prNr ..'">PR '.. msg.prNr ..'</a>)'
                    .."")
            end
            dst:write("</br>\n")
        end
    end }
end


function newMarkdownPrinter( app, dst )
    return { append = function( t, entry )
        dst:write(""
            .."\n\n"
            .."## ".. entry.date .." - ".. entry.version .."\n"
            .."\n")
        for k, msg in ipairs(entry.msgs) do
            if msg.jiraNr then
                dst:write("- [[".. msg.jiraNr .."](https://jira.post.ch/browse/".. msg.jiraNr ..")] ")
            else
                dst:write("- [     NO-JIRA     ] ")
            end
            dst:write(msg.body)
            if msg.prNr then
                dst:write(" ([PR ".. msg.prNr .."](https://gitit.post.ch/projects/ISA/repos/".. app.svcName .."/pull-requests/".. msg.prNr .."))")
            end
            dst:write("\n")
        end
        dst:write("\n\n")
    end }
end


function run( app )
    local snk = io.stdout
    if app.isFetch then
        -- Make sure refs are up-to-date
        local gitFetch = "git fetch \"".. app.remoteName .."\""
        log:write("[DEBUG] ".. gitFetch .."\n")
        local gitFetch = io.popen(gitFetch)
        while true do
            local buf = gitFetch:read(1<<16)
            if not buf then break end
            log:write(buf)
        end
    end
    -- Collect input
    local git = "git log --date-order --first-parent --decorate --since \"".. app.since.."\""
    if app.isTags then git = git .." --tags" end
    git = git .." \"".. app.remoteName .."/master\""
    git = git .." \"".. app.remoteName .."/develop\""
    log:write("[DEBUG] ".. git .."\n")
    local git = io.popen(git)
    while true do
        local buf = git:read(1<<16)
        if not buf then break end
        --io.stdout:write(buf)
        table.insert(app.fullHistory, buf)
    end
    -- Parse raw commits
    app.fullHistory = table.concat(app.fullHistory)
    app.parseFn = assert(readCommitHdr)
    while app.parseFn do app.parseFn(app) end
    -- Prepare output
    if app.isPrintHtml then
        app.outputPrinter = newHtmlPrinter(app, snk)
    elseif app.isPrintMarkdown then
        app.outputPrinter = newMarkdownPrinter(app, snk)
    else
        app.outputPrinter = newTextPrinter(app, snk)
    end
    local prevDate = "0000-00-00"
    local version, prevVersion = "v_._._", false
    local dateEntry = false
    local entries = {}
    for k, v in ipairs(app.commits) do
        local date = assert(v.hdr:match("\nDate: +([0-9-]+) "))
        local author = assert(v.hdr:match("\nAuthor: +([^\n]+)\n"))
        local prNr, short = v.msg:match("Pull request #(%d+): ([^\n]+)\n")
        prevVersion = version
        _, version = v.hdr:match("^([^\n]+)\n"):match("tag: ([a-z-]+)-([^,]+)[,)]")
        if not version then version = prevVersion end
        if version ~= prevVersion or not dateEntry then
            if dateEntry and dateEntry.msgs and (#dateEntry.msgs > 0)
            then table.insert(entries, dateEntry) end
            dateEntry = { date = assert(date), version = assert(version) }
            prevDate = date
        end
        local msg = short or v.msg
        -- Drop some crappy bloat
        if msg:find("^Develop$")
        or msg:find("^Release$")
        or msg:find("^%[AUTO%] Release PR$")
        or msg:find("^%[P2%] merge master back to develop$")
        or msg:find("^%[P2%] release [^ ]+ %[skip ci%]$")
        then
            goto nextCommit
        end
        local jiraNr
        local jiraNrPref = msg:match("^(%[?SDCISA%-%d%d%d%d%d?[^%d] ?)")
        if jiraNrPref then
            jiraNr = msg:match("^%[?(SDCISA%-%d%d%d%d%d?)[^%d]")
            if jiraNr then msg = msg:sub(#jiraNrPref):gsub("^%s+", "") end
        end
        if not dateEntry.msgs then dateEntry.msgs = {} end
        table.insert(dateEntry.msgs, {
            jiraNr = jiraNr or false,
            prNr = prNr or false,
            body = msg or false,
        })
        ::nextCommit::
    end
    if dateEntry.msgs and #dateEntry.msgs > 0 then table.insert(entries, dateEntry) end
    -- output
    for k, v in ipairs(entries) do
        app.outputPrinter:append(v)
    end
end


function main()
    local app = {
        since = false,
        remoteName = false,
        svcName = false,
        isFetch = true,
        isTags = false,
        isPrintHtml = false,
        isPrintMarkdown = false,
        outputPrinter = false,
        fullHistory = {},
        fullHistoryRdBeg = 1,
        commits = {},
        parseFn = false,
    }
    if parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then printHelp() return end
    run(app)
end


main()

