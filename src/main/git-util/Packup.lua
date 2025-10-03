
local out = io.stdout
local log = io.stderr


function printHelp( app )
	out:write("  \n"
		.."  Export SOME git branches only. Handy for mailing for example.\n"
		.."  \n"
		.."  --src <path>\n"
		.."      Git repo where to export from.\n"
		.."      Defaults to the current working dir if ommitted.\n"
		.."      Example:  /path/to/project/.git\n"
		.."  \n"
		.."  --dst <path>\n"
		.."      A directory, where to export the result to.\n"
		.."      Example:  /path/to/some/dir\n"
		.."  \n"
		.."  --br <branchName>\n"
		.."      Name of the branch to export.\n"
		.."  \n"
		.."  --append\n"
		.."      By default, script refuses to mess-up existing directories. But\n"
		.."      with this option, it will also export if the target dir/repo\n"
		.."      already exists.\n"
		.."  \n"
		.."  --depth <int>\n"
		.."      How many commits to export.\n"
		.."  \n"
		.."  --since <IsoDate|IsoDatetime>\n"
		.."      In place of depth, one can also provide a date from when on the\n"
		.."      commits should be exported.\n"
		.."  \n")
end


function parseArgs( app )
	local iA, argv = 0, _ENV.arg
::nextArg::
	iA = iA + 1
	local arg = argv[iA]
	if not arg then
		goto verify
	elseif arg == "--help" then
		app.isHelp = true  return true
	elseif arg == "--dst" then
		iA = iA + 1
		app.dst = argv[iA]
		if not app.dst then log:write("EINVAL: ".. arg .." needs value\n") return end
	elseif arg == "--br" then
		iA = iA + 1
		app.branch = argv[iA]
		if not app.branch then log:write("EINVAL: ".. arg .." needs value\n") return end
	elseif arg == "--append" then
		app.isAppend = true
	elseif arg == "--depth" then
		iA = iA + 1
		app.depth = math.tointeger(argv[iA])
		if not app.depth then log:write("EINVAL: ".. arg .." "..tostring(argv[iA]).."\n") return end
	elseif arg == "--since" then
		iA = iA + 1
		app.since = argv[iA]
		if not app.since then log:write("EINVAL: ".. arg .." "..tostring(argv[iA]).."\n") return end
	else
		log:write("EINVAL: ".. arg .."\n")
	end
	goto nextArg
::verify::
	if not app.dst then log:write("EINVAL: --dst missing\n") return end
	if not app.src then
		app.src = assert(os.getenv("PWD"), "environ.PWD missing") .."/.git"
	end
	if not app.depth and not app.since then  app.depth = 1  end
	return true
end


function run( app )
	local remoteQt = "'file://".. app.src:gsub("'", [['"'"']]) .."'"
	local brQt = "'".. app.branch:gsub("'", [['"'"']]) .."'"
	local mkdir = (app.isAppend and "mkdir -p" or "mkdir")
	local cmdline = "true"
		..' && origDir="${PWD:?}"'
		.." && ".. mkdir .." '".. app.dst:gsub("'",[['"'"']]) .."/export.git'"
		.." && cd '".. app.dst:gsub("'",[['"'"']]) .."/export.git'"
	if not app.isAppend then
		cmdline = cmdline
			.." && if test -n \"$(ls -A .)\";then echo 'dst already exists';false;fi"
	end
	local limit = nil
		or (app.depth and(" --depth="..app.depth))
		or (app.since and(" --shallow-since '".. app.since:gsub("'", [['"'"']]) .."'"))
	assert(limit, "limit")
	cmdline = cmdline
		.." && git init --bare"
		.." && git fetch ".. limit .." ".. remoteQt .." ".. brQt ..":".. brQt
		.." && git gc --prune=now"
		..[[ && printf '\nResult ready in\n  %s\n\n' "${PWD:?}" ]]
		.." && true"
	local ok, how, code = os.execute(cmdline)
	if not ok then error(how..", "..code) end
end


function main()
	local app = {
		isHelp = false,
		isAppend = false,
		src = false,
		dst = false,
	}
	if not parseArgs(app) then os.exit(1) end
	if app.isHelp then printHelp() return end
	run(app);
end


main()
