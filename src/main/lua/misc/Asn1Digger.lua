

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
        .."  \n"
        .."      --gpg\n"
        .."          Assume GPG and print additional info for it.\n"
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
        elseif arg == "--gpg" then
            app.assumeGPG = true
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
    local typeName
    if app.type == 0x00 then typeName = "EndOfContent" end
    if app.type == 0x02 then typeName = "integer" end
    if app.type == 0x04 then typeName = "octet string" end
    if app.type == 0x0C then typeName = "utf8 string" end
    if not typeName then
        local tagClass = false
            or ((app.type & 0xC0) == 0) and "Universal"
            or ((app.type & 0x40) == 0) and "Application"
            or ((app.type & 0x80) == 0) and "Context-specifc"
            or "Private"
        local primOrConstr = ((app.type & 0x20) == 0)and"primitive"or"constructed"
        local isLongType = (app.type & 0x1F == 0x1F)
        local fmt = (isLongType) and("%s, %s, %s") or("subType 0x%02X, %s, %s")
        typeName = string.format(fmt,
            isLongType and("LongType") or(app.type & 0x1F),
            tagClass,
            primOrConstr)
    end
    app.dst:write(string.format("ASN.1 type 0x%02X, len %d (%s), value:", app.type, app.len, typeName))
    if app.assumeGPG then
        if app.type == 0x95 then
            app.dst:write(string.format("\nGPG secret key packet, version %d", val:byte(2)))
        elseif app.type == 0x99 and app.len == 1 and val:byte(1) == 0x0D then
            app.dst:write("\nGPG certificate")
        end
    end
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
        isHelp = false,
        assumeGPG = false,
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
