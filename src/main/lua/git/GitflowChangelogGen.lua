
local log = io.stderr
local main


function printHelp()
    io.stdout:write("  \n"
        .."  Helper to extract essential data from a gitflow log which potentially\n"
        .."  is useful to write a CHANGELOG from.\n"
        .."  \n"
        .."  Options:\n"
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
        )
end


function parseArgs( app )
    local iA = 0
    while true do iA = iA + 1
        local arg = _ENV.arg[iA]
        if not arg then
            break
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
        elseif arg == "--help" then
            app.isHelp = true; return 0
        else
            log:write("EINVAL: ".. arg .."\n")return
        end
    end
    if not app.since then log:write("EINVAL: --since missing\n")return end
    if not app.remoteName then app.remoteName = "upstream" end
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
    local prevDate = "0000-00-00"
    local version, prevVersion = "v_._._", false
    local dateEntry = false
    local entries = {}
    for k, v in ipairs(app.commits) do
        local date = assert(v.hdr:match("\nDate: +([0-9-]+) "))
        local author = assert(v.hdr:match("\nAuthor: +([^\n]+)\n"))
        local prNr, short = v.msg:match("Pull request #(%d+): ([^\n]+)\n")
        prevVersion = version
        _, version = v.hdr:match("^([^\n]+)\n"):match("tag: ([a-z]+)-([^,]+)[,)]")
        if not version then version = prevVersion end

        if version ~= prevVersion or not dateEntry then
            if dateEntry then table.insert(entries, dateEntry) end
            dateEntry = {
                txt = date .." - ".. version .."\n\n" --.."Resolved issues:\n\n"
            }
            prevDate = date
        end
        -- Drop some crappy bloat
        local msg = short or v.msg
        local jiraNr = msg:match("^(SDCISA%-%d%d%d%d%d?)[^%d]")
        if false
        or msg:find("^Develop$")
        or msg:find("^Release$")
        or msg:find("^%[P2%] merge master back to develop$")
        or msg:find("^%[P2%] release [^ ]+ %[skip ci%]$")
        then
            goto nextCommit
        end
        if jiraNr then dateEntry.txt = dateEntry.txt .."[".. jiraNr .."] " end
        dateEntry.txt = dateEntry.txt .. msg
        if prNr then dateEntry.txt = dateEntry.txt .." (PR ".. prNr ..")" end
        dateEntry.txt = dateEntry.txt .."\n"
        ::nextCommit::
    end
    if dateEntry then table.insert(entries, dateEntry) end
    -- output
    for k, v in ipairs(entries) do
        snk:write("\n\n")
        snk:write(v.txt)
        snk:write("\n")
    end
end


function main()
    local app = {
        since = false,
        remoteName = false,
        isFetch = true,
        isTags = false,
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

