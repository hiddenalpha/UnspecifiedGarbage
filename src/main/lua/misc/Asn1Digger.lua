

local mod = {}
local log, inn, out = io.stderr, io.stdin, io.stdout


function mod.printHelp()
    io.stdout:write("  \n"
        .."  Print ASN.1 from stdin to a textual representation on stdout.\n"
        .."  \n"
        .."  Options:\n"
        .."  \n"
        .."      -c <num>\n"
        .."          Number of columns to use for hex-dumps. Defaults to 16.\n"
        .."  \n")
end


function mod.parseArgs( app )
    app.hexCols = 16
    local i = 0  while true do  i = i + 1
        local arg = _ENV.arg[i]
        if not arg then
            break
        elseif arg == "--help" then
            app.isHelp = true; break
        elseif arg == "-c" then
            i = i + 1
            app.hexCols = _ENV.arg[i]
            if not app.hexCols or not app.hexCols:find("^[0-9]+$") or app.hexCols:len() > 8 then
                log:write("EINVAL: -c ".. (app.hexCols or "needs a value") .."\n")
                return -1
            end
            app.hexCols = tonumber(app.hexCols)
        else
            log:write("EINVAL: ".. arg .."\n")
            return -1
        end
    end
    return 0
end


function mod.state_type( app )
    local ty = app.src:read(1)
    if not ty then -- EOF
        app.isInnEof = true
        return
    end
    ty = ty:byte(1)
    app.type = ty
    app.funcToCall = mod.state_length
end


function mod.state_length( app )
    local len = app.src:read(1)
    assert(len, len)
    len = len:byte(1)
    app.len = len
    app.funcToCall = mod.state_value
end


function mod.state_value( app )
    assert(type(app.len) == "number", app.len)
    local val = app.src:read(app.len)
    assert(val, val)
    if app.type == 0x99 and app.len == 1 and val:byte(1) == 0x0D then
        app.dst:write(string.format("- Certificate (t=0x%02X, l=0x01, v=0x0D)\n", app.type))
    elseif app.type == 0x04 then
        app.dst:write(string.format("- OctetStream (t=0x%02X, l=%d):", app.type, app.len))
        local i = 0 while i < val:len() do i = i + 1
            if (i-1) % 32 == 0 then app.dst:write("\n  ") end
            app.dst:write(string.format(" %02X", val:byte(i)))
        end
        app.dst:write("\n")
    -- elseif app.type == 0x2D then
    else
        app.dst:write(string.format("Type 0x%02X (%d), length %d:", app.type, app.type, app.len))
        local line = ""
        local i = 0 while i < val:len() do i = i + 1
            if (i-1) % app.hexCols == 0 then app.dst:write(string.format("%s\n  %08X:", line, i-1)); line = "  " end
            local char = val:byte(i)
            app.dst:write(string.format(" %02X", char))
            local isPrintable = false
                or (char >= 0x20 and char <= 0x7E)
            line = line .. (isPrintable and string.char(char) or ".")
        end
        if line:len() > 0 then
            i = i % app.hexCols
            while i < app.hexCols do app.dst:write("   "); i = i + 1 end
            app.dst:write(line)
        end
        app.dst:write("\n")
    end
    app.funcToCall = mod.state_type
end


function mod.run( app )
    app.src = io.stdin
    app.dst = io.stdout
    app.funcToCall = mod.state_type
    while not app.isInnEof do
        app.funcToCall(app)
    end
end


function mod.main()
    local app = {
        src = false,
        dst = false,
        isInnEof = false,
        funcToCall = false,
        type = false,
        len = false,
        value = false,
    }
    if mod.parseArgs(app) ~= 0 then os.exit(1) end
    if app.isHelp then mod.printHelp() return end
    mod.run(app)
end


mod.main()
