
local exports = {}
local mod = {}
local stderr = io.stderr


local LogParse = { -- class
    line = nil,
    log = nil,
}


function exports.newLogParser( config )
    return LogParse:new(nil, config )
end


function LogParse:new(o, config)
    if not config or type(config.onLogEntry) ~= "function" then
        error( "Arg 'config.onLogEntry' must be a function" )
    end
    o = o or {};
    setmetatable(o, self);
    self.__index = self;
    -- Register callbacks
    self.cb_cls = config.cls
    self.cb_onLogEntry = config.onLogEntry
    self.cb_onEnd = config.onEnd
    self.cb_onError = config.onError or function(s)
        error(s or "nil")
    end
    self.cb_onWarn = config.onWarn or function(s)
        io.stdout:flush()
        warn(s)
    end
    -- END callbacks
    mod.setupParserPattern( o, config )
    return o;
end


function mod.setupParserPattern( this, c )
    local inputPat
    if c.patternV1 then
        inputPat = c.patternV1; -- Use the one from parameter.
    else
        this.cb_onWarn( "No 'c.patternV1' specified. Fallback to internal obsolete one." )
        inputPat = "DATE POD STAGE SERVICE THREAD LEVEL FILE - MSG"
    end
    local parts = {}
    for part in string.gmatch(inputPat,"[^ ]+") do
        table.insert( parts, part )
    end
    this.parts = parts
end


local function writeStderr(...)
    local args = table.pack(...)
    for i=1,args.n do
        io.stderr:write( args[i] or "nil" )
    end
end


function LogParse:tryParseLogs()
    self.numBrokenLogLines = 0
    self.thisEntryIsBroken = false
    while true do
        self.line = io.read("l");
        if self.line == nil then -- EOF
            self:publishLogEntry()
            break;
        end

        --io.write( "\nBUF: ", self.line, "\n\n" );
        --io.flush()

        if self.line:match("^%d%d%d%d%-%d%d%-%d%d[ T]%d%d:%d%d:%d%d,%d%d%d ") then
            -- Looks like the beginning of a new log entry.
            self.thisEntryIsBroken = false
            self:initLogEntryFromLine();
        elseif self.line:match("^%d%d:%d%d:%d%d[,.]%d%d%d %[") then
            -- FUCK THIS SHIT!!
            self.thisEntryIsBroken = true
            self.numBrokenLogLines = self.numBrokenLogLines + 1
            self:initLogEntryFromLine();
        elseif self.line:match("^%s+at [^ ]") then
            -- Looks like a line from exception stack
            self:appendStacktraceLine();
        elseif self.line:match("^%s*Caused by: ") then
            -- Looks like a stacktrace 'Caused by' line
            self:appendStacktraceLine();
        elseif self.line:match("^%s+Suppressed: ") then
            -- Looks like a stacktrace 'Suppressed: ' line
            self:appendStacktraceLine();
        elseif self.line:match("^%\t... (%d+) more$") then
            -- Looks like folded stacktrace elements
            self:appendStacktraceLine();
        else
            -- Probably msg containing newlines.
            self:appendLogMsg();
        end
        ::nextLine::
    end
    if self.numBrokenLogLines ~= 0 then
        stderr:write("[WARN ] Skiped ".. self.numBrokenLogLines .." entries with broken dates\n")
    end
end


function LogParse:initLogEntryFromLine()
    if self.thisEntryIsBroken then return end

    self:publishLogEntry()
    local log = self:getOrNewLogEntry();

    -- Try some alternative parsers
    mod.parseByPattern( self )
    --if log.date==nil then
    --    self:parseOpenshiftServiceLogLine();
    --end
    --if log.date==nil then
    --    self:parseEagleLogLine();
    --end
    --if log.date==nil then
    --    self:parseJettyServiceLogLine();
    --end

    if log.date==nil then
        self.cb_onWarn("Failed to parse log line:\n\n".. self.line .."\n\n", self.cb_cls)
    end
end


function mod.parseByPattern( this )
    local date, pod, stage, service, thread, level, file, msg, matchr, match
    local line = this.line
    local log = this:getOrNewLogEntry();

    -- We can just return on failure. if log is missing, it will report error
    -- on caller side. Just ensure that 'date' is nil.
    log.date = nil

    local rdPos = 1
    for i,part in ipairs(this.parts) do
        if part=="DATE" then
            date = line:gmatch("(%d%d%d%d%-%d%d%-%d%d[ T]%d%d:%d%d:%d%d,%d%d%d) ", rdPos)()
            if not date or date=="" then return end
            rdPos = rdPos + date:len()
            --stderr:write("date: "..tostring(date).."  (rdPos="..tostring(rdPos)..")\n")
        elseif part=="STAGE" then
            match = line:gmatch( " +[^%s]+", rdPos)()
            if not match then return end
            stage = match:gmatch("[^%s]+")()
            rdPos = rdPos + match:len()
            --stderr:write("stage: "..tostring(stage).."  (rdPos="..tostring(rdPos)..")\n")
        elseif part=="SERVICE" then
            match = line:gmatch(" +[^%s]+", rdPos)()
            if not match then return end
            service = match:gmatch("[^%s]+")()
            rdPos = rdPos + match:len()
            --stderr:write("service: "..tostring(service).."  (rdPos="..tostring(rdPos)..")\n");
        elseif part=="LEVEL" then
            match = line:gmatch(" +[^%s]+", rdPos)()
            if not match then return end
            level = match:gmatch("[^%s]+")()
            if not level:find("^[ABCDEFGINORTUW]+$") then -- [ABCDEFGINORTUW]+ -> (ERROR|WARN|INFO|DEBUG|TRACE)
               this.cb_onWarn( "Does not look like a level: "..(level or"nil"), this.cb_cls )
            end
            rdPos = rdPos + match:len()
            --stderr:write("level: "..tostring(level).."  (rdPos="..tostring(rdPos)..")\n");
        elseif part=="FILE" then
            match = line:gmatch(" +[^%s]+", rdPos)()
            if not match then return end
            file = match:gmatch("[^%s]+")()
            if file=="WARN" then stderr:write("\n"..tostring(line).."\n\n")error("Doesn't look like a file: "..tostring(file)) end
            rdPos = rdPos + match:len()
            --stderr:write("file: "..tostring(file).."  (rdPos="..tostring(rdPos)..")\n");
        elseif part=="-" then
            match = line:gmatch(" +%-", rdPos)()
            rdPos = rdPos + match:len();
            --stderr:write("dash  (rdPos="..tostring(rdPos)..")\n");
        elseif part=="MSG" then
            match = line:gmatch(" +.*$", rdPos)()
            if not match then return end
            msg = match:gmatch("[^%s].*$")()
            rdPos = rdPos + match:len()
            --stderr:write("msg: "..tostring(msg).."  (rdPos="..tostring(rdPos)..")\n")
        elseif part=="POD" then
            match = line:gmatch(" +[^%s]+", rdPos)()
            if not match then return end
            pod = match:gmatch("[^%s]+")()
            rdPos = rdPos + match:len()
            --stderr:write("pod: "..tostring(pod).."  (rdPos="..tostring(rdPos)..")\n")
        elseif part=="THREAD" then
            match = line:gmatch(" +[^%s]+", rdPos)()
            thread = match:gmatch("[^%s]+")()
            rdPos = rdPos + match:len()
            --stderr:write("thrd: "..tostring(thread).."  (rdPos="..tostring(rdPos)..")\n")
        end
    end

    log.raw = this.line;
    log.date = date;
    log.pod = pod;
    log.stage = stage;
    log.service = service;
    log.thread = thread;
    log.level = level;
    log.file = file;
    log.msg = msg;
end


function LogParse:parseOpenshiftServiceLogLine()
    local date, pod, stage, service, thread, level, file, msg
    local this = self
    local line = this.line
    local log = self:getOrNewLogEntry();

    -- We can just return on failure. if log is missing, it will report error
    -- on caller side. Just ensure that 'date' is nil.
    log.date = nil

    -- VERSION 3 (Since 2021-09-24 houstonProd)
    local rdPos = 1
    -- Date
    date = line:gmatch("(%d%d%d%d%-%d%d%-%d%d[ T]%d%d:%d%d:%d%d,%d%d%d)", rdPos)()
    if not date then return end
    rdPos = rdPos + date:len()
    -- Pod
    pod = line:gmatch(" (%a+)", rdPos )()
    if not pod then return end
    rdPos = rdPos + pod:len()
    -- stage
    stage = line:gmatch( " (%a+)", rdPos)()
    if not stage then return end
    rdPos = rdPos + stage:len()
    -- service
    service = line:gmatch( " (%a+)", rdPos)()
    if not service then return end
    rdPos = rdPos + service:len()
    -- thread (this only maybe exists)
    thread = line:gmatch( " ([%a%d%-]+)", rdPos)()
    -- [ABCDEFGINORTUW]+ -> (ERROR|WARN|INFO|DEBUG|TRACE)
    if thread and thread:find("^[ABCDEFGINORTUW]+$") then
        thread = nil; -- Does more look like an error level. So do NOT advance
    else
        rdPos = rdPos + thread:len()
    end
    -- level
    level = line:gmatch( " ([A-Z]+)", rdPos)()
    if not level then return end
    rdPos = rdPos + level:len()
    -- file
    file = line:gmatch(" ([^%s]+)", rdPos)()
    if not file then return end
    rdPos = rdPos + file:len()
    -- msg
    msg = line:gmatch(" %- (.*)", rdPos)()
    if not msg then return end
    rdPos = rdPos + msg:len()

    -- VERSION 2 (Since 2021-09-24 prefluxInt)
    --local rdPos = 1
    ---- Date
    --date = line:gmatch("(%d%d%d%d%-%d%d%-%d%d[ T]%d%d:%d%d:%d%d,%d%d%d)", rdPos)()
    --if not date then return end
    --rdPos = rdPos + date:len()
    ---- Pod
    --pod = line:gmatch(" (%a+)", rdPos )()
    --if not pod then return end
    --rdPos = rdPos + pod:len()
    ---- stage
    --stage = line:gmatch( " (%a+)", rdPos)()
    --if not stage then return end
    --rdPos = rdPos + stage:len()
    ---- service
    --service = line:gmatch( " (%a+)", rdPos)()
    --if not service then return end
    --rdPos = rdPos + service:len()
    ---- thread (this only maybe exists)
    --thread = line:gmatch( " ([%a%d%-]+)", rdPos)()
    ---- [ABCDEFGINORTUW]+ -> (ERROR|WARN|INFO|DEBUG|TRACE)
    --if thread and thread:find("^[ABCDEFGINORTUW]+$") then
    --    thread = nil; -- Does more look like an error level. So do NOT advance
    --else
    --    rdPos = rdPos + thread:len()
    --end
    ---- level
    --level = line:gmatch( " ([A-Z]+)", rdPos)()
    --if not level then return end
    --rdPos = rdPos + level:len()
    ---- file
    --file = line:gmatch(" ([^%s]+)", rdPos)()
    --if not file then return end
    --rdPos = rdPos + file:len()
    ---- msg
    --msg = line:gmatch(" %- (.*)", rdPos)()
    --if not msg then return end
    --rdPos = rdPos + msg:len()

    log.raw = self.line;
    log.date = date;
    log.pod = pod;
    log.stage = stage;
    log.service = service;
    log.thread = thread;
    log.level = level;
    log.file = file;
    log.msg = msg;
end


function LogParse:parseEagleLogLine()
    local log = self:getOrNewLogEntry();
    local date, stage, service, level, file, msg = self.line:gmatch(""
        .."(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d,%d%d%d)" -- datetime
        .." (%a+)" -- stage
        .." (%a+)" -- service
        .." (%a+)" -- level
        .." ([^%s]+)" -- file
        .." %- (.*)" -- msg
    )();
    local pod = service; -- just 'mock' it
    log.raw = self.line;
    log.date = date;
    log.service = service;
    log.pod = pod;
    log.stage = stage;
    log.level = level;
    log.file = file;
    log.msg = msg;
end


function LogParse:parseJettyServiceLogLine()
    local log = self:getOrNewLogEntry();
    local date, pod, stage, service, level, file, msg = self.line:gmatch(""
        .."(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d,%d%d%d)" -- datetime
        .." (%S+)" -- pod (aka container)
        .." (%a+)" -- stage
        .." (%a+)" -- service
        .." (%a+)" -- level
        .." ([^%s]+)" -- file
        .." %- (.*)" -- msg
    )();
    log.raw = self.line;
    log.date = date;
    log.pod = pod;
    log.stage = stage;
    log.service = service;
    log.level = level;
    log.file = file;
    log.msg = msg;
end


function LogParse:appendLogMsg()
    local log = self:getOrNewLogEntry()
    log.msg = log.msg or "";
    log.raw = log.raw or "";

    log.msg = log.msg .."\n".. self.line;
    -- Also append to raw to have the complete entry there.
    log.raw = log.raw .."\n".. self.line;
end


function LogParse:appendStacktraceLine()
    local log = self:getOrNewLogEntry()
    if not log.stack then
        log.stack = self.line
    else
        log.stack = log.stack .."\n".. self.line
    end
    -- Also append to raw to have the complete entry there.
    log.raw = log.raw .."\n".. self.line;
end


function LogParse:publishLogEntry()
    local log = self.log
    if not log or self.thisEntryIsBroken then
        return -- nothing to do
    end
    if not log.raw then
        -- WhatTheHeck?!?
        local msg = "InternalError: Collected log unexpectedly empty"
        self.cb_onError(msg, self.cb_cls)
        error(msg); return
    end
    self.log = nil; -- Mark as consumed
    -- Make sure log lines do NOT end in 0x0D
    local msg = log.msg
    if msg:byte(msg:len()) == 0x0D then log.msg = msg:sub(1, -2) end
    self.cb_onLogEntry(log, self.cb_cls)
end


function LogParse:getOrNewLogEntry()
    self.log = self.log or LogEntry:new(nil)
    return self.log
end


function exports.normalizeIsoDateTime( str )
    if str:find("%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%d") then return str end -- already fine :)
    local y, mo, d, h, mi, s, ms = str:match("^(%d%d%d%d)-(%d%d)-(%d%d)[ T_-](%d%d):(%d%d):(%d%d)[,.](%d%d%d)$")
    return y .."-".. mo .."-".. d .."T".. h ..":".. mi ..":".. s ..".".. ms
end


LogEntry = {
    raw,
    date,
    service,
    stack,
}


function LogEntry:new(o)
    o = o or {};
    setmetatable(o, self);
    self.__index = self;
    return o;
end


function LogEntry:debugPrint()
    print( "+- PUBLISH ------------------------------------------------------------" );
    print( "| date ---> ", self.date or "nil" );
    print( "| pod ----> ", self.pod or "nil" );
    print( "| service > ", self.service or "nil" );
    print( "| stage --> ", self.stage or "nil" );
    print( "| thread -> ", self.thread or "nil" );
    print( "| level --> ", self.level or "nil" );
    print( "| file ---> ", self.file or "nil" );
    print( "| msg ----> ", self.msg or "nil" );
    print( "| " )
    io.write( "| RAW: ", self.raw or "nil", "\n" );
    print( "`--------------------" );
end


return exports

