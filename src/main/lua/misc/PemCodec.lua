
local mod = {}
local log = io.stderr


function mod.printHelp( app )
    io.stdout:write("  \n"
        .."  encode/decode PEM from stdin to stdout\n"
        .."  \n"
        .."  HINT: Encode is not yet implemented.\n"
        .."  \n"
        .."  Options:\n"
        .."  \n"
        .."      -d     decode\n"
        .."  \n")
end


function mod.parseArgs(app)
    app.mode = "ENCODE"
    local i=0  while true do  i = i + 1
        local arg = _ENV.arg[i]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true
            break
        elseif arg == "-d" then
            app.mode = "DECODE"
        else
            log:write("EINVAL: ".. arg .."\n")
            return -1
        end
    end
    return 0
end


function mod.decode( app )
    local snk = app.snk
    local buf = app.src:read(11)
    if buf ~= "-----BEGIN " then
        log:write("EINVAL: No valid PEM header found\n")
        os.exit(1)
    end
    local numDashesInSequence = 0
    -- read until EOL
    while true do
        local buf = app.src:read(1)
        if buf == "\n" then
            if numDashesInSequence ~= 5 then
                log:write("EINVAL: No valid PEM header found\n")
                os.exit(1)
            end
            break
        end
        if buf == "-" then
            numDashesInSequence = numDashesInSequence + 1
        else
            numDashesInSequence = 0
        end
    end
    -- decode b64
    local sextets = {false, false, false, false}
    while true do
        local iByte = 1
        while iByte <= 4 do -- read input octets
            local buf = app.src:read(1)
            --assert(buf and buf:len() == 1, "TODO_20230824104846 EOF")
            local byte = buf:byte(1)
            if false then
            elseif byte >= 0x41 and byte <= 0x5A then -- A-Z
                sextets[iByte] = byte - 65
            elseif byte >= 0x61 and byte <= 0x7A then -- a-z
                sextets[iByte] = byte - 71
            elseif byte >= 0x30 and byte <= 0x39 then -- 0-9
                sextets[iByte] = byte + 4
            elseif byte == 0x2B then -- +
                sextets[iByte] = 63
            elseif byte == 0x2F then -- /
                sextets[iByte] = 64
            elseif byte == 0x3D then -- =
                sextets[iByte] = 0
            elseif byte == 0x0A then -- ignore whitespaces
                goto nextOctet
            elseif byte == 0x2D then -- dash, NOT part of b64. Looks as we've reached End of b64.
                goto readEndOfPemLine
            else
                error(string.format("Bad char: 0x%02X", byte))
            end
            iByte = iByte + 1
::nextOctet::
        end
        snk:write(string.format("%c%c%c",
            ( sextets[1]        << 2) | (sextets[2] >> 4) ,
            ((sextets[2] & 0xF) << 4) | (sextets[3] >> 2) ,
            ((sextets[3] & 0x3) << 6) |  sextets[4]
        ))
    end
::readEndOfPemLine::
    -- Did already read 1st dash in loop above. So we expect only 4 remaining
    local buf = app.src:read(999)
    if not buf:find("^----END [^\n-]+-----\n$") then
        log:write("[WARN] PEM trailer broken\n")
    end
end


function mod.main()
    local app = {
        isHelp = false,
        mode = false, -- one of "ENCODE" or "DECODE"
        src = io.stdin,
        snk = io.stdout,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp(app) return end
    if app.mode == "ENCODE" then
        log:write("ENOTSUP: PEM Encode not implented yet\n")
        os.exit(1)
    else
        assert(app.mode == "DECODE", app.mode)
        mod.decode(app)
    end
end


mod.main()
