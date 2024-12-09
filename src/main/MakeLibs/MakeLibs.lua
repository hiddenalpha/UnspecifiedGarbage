#!/usr/bin/env lua
--[[

  I'm ways too dumb to "just build a lib. It's easy...". Shut up! Look how long
  this file is! Then you know how "easy" it is!

  Source:
  https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/MakeLibs/

  TODO: Test if (especially wdoof) builds are usable at all.
  TODO: Add expat.
  TODO: Add sqlite.
  TODO: Add lua.
  TODO: Add nuklear.
  TODO: Add GLFW.

-- Config begins here -------------------------------------------------------]]

local host = "devuan5" -- one of ["devuan5", "debian9"]
local target = "windoof" -- one of ["posix", "windoof"]
local version_cJSON = "1.7.15"
local version_expat = "2.4.2"
local version_lua = "5.4.3"
local version_mbedtls = "3.6.2"
local version_mbedtls_framework = "a2c76945ca090f9dd099001d7c5158557f5a2036"
local version_sqlite = "3.33.0"
local version_zlib = "1.2.11"
local ndebug_cJSON = true
local ndebug_mbedtls = true
local ndebug_zlib = true
local envWORKDIR = "/home/${USER:?}/work"
local envCACHEDIR = "/var/tmp"
local envMAKE_JOBS = 8

-- end Config -----------------------------------------------------------------

local main, b64e, TODO_EgXYTUrb6fVdv5wr, defineWhatToBuild, defineZlib, collectPkgsToAddOverall,
    writeSystemSetupToDst, writeModulesPrepare, writeModulesMake, newModule
local envSUDO, envHOST
local cmdPkgInit, cmdPkgClean, cmdPkgAdd
local modulesToMake, pkgsToAddMerged, pkgsToAddGlobally


function defineWhatToBuild()
    local m
    modulesToMake = {}
    m = defineZlib()    m:verifyAndFreeze() table.insert(modulesToMake, m)
    m = defineMbedtls() m:verifyAndFreeze() table.insert(modulesToMake, m)
end


function defineMbedtls()
    local mbedtls = newModule()
    mbedtls.name = "mbedtls"
    mbedtls.version = version_mbedtls
    mbedtls.ndebug = ndebug_mbedtls
    mbedtls.pkgsToAdd = { "make", "findutils", }
    mbedtls.environ:add("FRAMEWORK_VERSION", version_mbedtls_framework)
    mbedtls.environ:add("FRAMEWORK_SRCTAR",
        envCACHEDIR ..'/mbedtls-framework-g'.. version_mbedtls_framework ..'.tgz')
    mbedtls.dloads:add{
        url = "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/mbedtls-".. mbedtls.version ..".tar.gz",
        dstFile = envCACHEDIR ..'/'.. mbedtls.name ..'-'.. mbedtls.version ..'.tgz',
    }
    mbedtls.dloads:add{
        url = "https://github.com/Mbed-TLS/mbedtls-framework/archive/".. version_mbedtls_framework ..".tar.gz",
        dstFile = envCACHEDIR ..'/mbedtls-framework-g'.. version_mbedtls_framework ..'.tgz',
    }
    mbedtls.makeShell = [===[ true \
  && tar --strip-components=1 -xf "${SRCTAR:?}" \
  && (cd framework && tar --strip-components=1 -xf "${FRAMEWORK_SRCTAR:?}") \
  && (true \
      && `#TODO Mallocator  echo "#define MBEDTLS_PLATFORM_MEMORY" ` \
      && `#TODO Mallocator  echo "#undef  MBEDTLS_PLATFORM_FREE_MACRO" ` \
      && `#TODO Mallocator  echo "#undef  MBEDTLS_PLATFORM_CALLOC_MACRO" ` \
      && printf '#%s MBEDTLS_DEBUG_C\n' "$(test "${NDEBUG:?}" -ne 0 && echo "undef" || echo "define")" \
     ) >> "include/mbedtls/mbedtls_config.h" \
    ]===]
    if target == "posix" then
        -- no bullshit needed
    elseif target == "windoof" then
        mbedtls.makeShell = mbedtls.makeShell .. [===[ \
          && HOST=x86_64-w64-mingw32 \
          && export WINDOWS_BUILD=1 \
          && export CC=${HOST:?}-gcc \
          && export LD=${HOST:?}-ld \
          && export AR=${HOST:?}-ar \
        ]===]
    else error("TODO_JZYD0SH8ivqjGf8f "..target) end
    mbedtls.makeShell = mbedtls.makeShell .. [===[ \
  && make -e -j${MAKE_JOBS:?} lib $(test "${NDEBUG:?}" -ne 0 || echo "DEBUG=1") \
  && mkdir build build/include build/lib \
  && cp -rt build/include/. include/psa include/mbedtls \
  && cp -rt build/lib/.  library/libmbedcrypto.a  library/libmbedtls.a  library/libmbedx509.a \
  && (true \
      && echo "version=${VERSION:?}" \
      && echo "mbedtlsFrameworkGitsha1=${FRAMEWORK_VERSION:?}" \
     ) > build/METADATA.INI \
  && (cd build && find -type f -exec md5sum -b {} + > MD5SUM) \
  && (cd build && tar --owner=0 --group=0 -czf "${DSTTAR:?}" METADATA.INI include lib MD5SUM) \
  && (cd "$(dirname "${DSTTAR:?}")" && md5sum -b "$(basename "${DSTTAR:?}")" >> "${DSTMD5:?}") \
  ]===]
    mbedtls:verifyAndFreeze()
    return mbedtls
end


function defineZlib()
    local zlib = newModule()
    zlib.name = "zlib"
    zlib.version = version_zlib
    zlib.ndebug = ndebug_zlib
    zlib.dloads:add({
        url = "https://downloads.sourceforge.net/project/libpng/zlib/".. zlib.version .."/zlib-".. zlib.version ..".tar.gz",
        dstFile = envCACHEDIR ..'/'.. zlib.name ..'-'.. zlib.version ..'.tgz',
    })
    if host == "devuan5" and target == "posix" then
        zlib.pkgsToAdd = {}
    elseif host == "devuan5" and target == "windoof" then
        zlib.pkgsToAdd = {}
    else
        error("ENOTSUP: ".. host ..", ".. target)
    end
    zlib.makeShell = [===[ true \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && mkdir build \
    ]===]
    if target == "posix" then
        zlib.makeShell = zlib.makeShell ..[===[ \
          && ./configure --prefix="$(pwd)/build/" \
          && make -j${MAKE_JOBS:?} && make install \
        ]===]
    elseif target == "windoof" then
        zlib.makeShell = zlib.makeShell ..[===[ \
          && export HOST=x86_64-w64-mingw32 \
          && export CC=${HOST:?}-gcc AR=${HOST:?}-ar STRIP=${HOST:?}-strip \
          && export DESTDIR=./build BINARY_PATH=/bin INCLUDE_PATH=/include LIBRARY_PATH=/lib \
          && sed -i "s;^PREFIX =.\*\$;;" win32/Makefile.gcc \
          && make -e -j${MAKE_JOBS:?} -fwin32/Makefile.gcc PREFIX=${HOST}- \
          && make -e -fwin32/Makefile.gcc install PREFIX=${HOST}- \
          && unset DESTDIR BINARY_PATH INCLUDE_PATH LIBRARY_PATH \
        ]===]
    else error(target) end
    zlib.makeShell = zlib.makeShell ..[===[ \
      && cp README build/. \
      && (cd build && rm -rf lib/pkgconfig) \
      && (cd build && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM) \
      && (cd build && tar --owner=0 --group=0 -czf "${DSTTAR:?}" README* include lib $(find . -wholename share) MD5SUM) \
      && (cd "$(dirname "${DSTTAR:?}")" && md5sum -b "${DSTTAR:?}" >> "${DSTMD5:?}") \
    ]===]
    return zlib
end


function newModuleDloads()
    local isModifiable = true
    return setmetatable({
        dloads = {},
        add = function( t, dload )
            assert(type(dload) == "table", type(dload))
            assert(type(dload.url) == "string", dload.url)
            assert(type(dload.dstFile) == "string", dload.dstFile)
            table.insert(rawget(t, "dloads"), dload)
        end,
        verifyAndFreeze = function( t ) isModifiable = false end
    }, {
        __newindex = function(t, k, v)
            assert(isModifiable, "ReadOnly")
            assert(k ~= "verifyAndFreeze", "EINVAL: "..k)
            rawset(t, k, v)
        end,
        __pairs = function(t, i, dloads)
            i, dloads = 0, rawget(t, "dloads")
            return function() i = i + 1  return dloads[i] end
        end,
    })
end


function newModuleEnviron()
    local isModifiable = true
    return setmetatable({
        environ = {},
        add = function( t, k, v )
            assert(type(k) == "string", k)
            assert(type(v) == "string", v)
            table.insert((rawget(t, "environ")), ({ k=k, v=v, }))
        end,
        verifyAndFreeze = function( t ) isModifiable = false end
    }, {
        __newindex = function(t, k, v)
            assert(isModifiable, "ReadOnly")
            assert(k ~= "verifyAndFreeze", "EINVAL: "..k)
            rawset(t, k, v)
        end,
        __pairs = function( t, i, environ )
            i, environ = 0, rawget(t, "environ")
            return function() i = i + 1  return environ[i] end
        end,
    })
end


function newModule()
    local RO, RW = 1, 2
    local fields = { ["name"]=RW, ["version"]=RW, ["dloads"]=RW, ["pkgsToAdd"]=RW, ["makeShell"]=RW,
        ["verifyAndFreeze"]=RO, ["ndebug"]=RW, }
    return setmetatable({
        verifyAndFreeze = function( t )
            for k, _ in pairs(fields) do
                assert(rawget(t, k), k)
                fields[k] = RO
            end
        end
    }, {
        __newindex = function(t, k, v) assert(fields[k] and fields[k]>=2, "Not writable: ".. k) rawset(t, k, v) end,
        __index = function(t, k)
            if k == "dloads" then
                local dloads = rawget(t, "dloads")
                if not dloads then dloads = newModuleDloads(); rawset(t, "dloads", dloads) end
                return dloads
            end
            if k == "environ" then
                local environ = rawget(t, "environ")
                if not environ then environ = newModuleEnviron(); rawset(t, "environ", environ) end
                return environ
            end
            assert(fields[k] and fields[k]>=1, "NoSuchProperty: ".. k)
            return rawget(t, k)
        end,
    })
end


function collectPkgsToAddOverall()
    assert(not pkgsToAddMerged)
    local numPkgsMerged = 0
    pkgsToAddMerged = {}
    for k, v in pairs(pkgsToAddGlobally) do
        assert(type(k) == "number", type(k))
        assert(type(v) == "string", type(v))
        pkgsToAddMerged[v] = true
        numPkgsMerged = numPkgsMerged + 1
    end
    if #modulesToMake <= 0 then error("Why no modules?") end
    for _, mod in pairs(modulesToMake) do
        assert(type(mod.pkgsToAdd) == "table")
        for _, pkg in pairs(mod.pkgsToAdd) do
            assert(type(pkg) == "string")
            pkgsToAddMerged[pkg] = true
            numPkgsMerged = numPkgsMerged + 1
        end
    end
    assert(numPkgsMerged > 0, "Why no pkgs found?")
end


function writeSystemSetupToDst( dst )
    dst:write(""
        .." && SUDO=".. envSUDO .." \\\n"
        ..' && now="$(date +%s)" \\\n'
        ..' && old="$(date +%s -r "/tmp/fUXfavAEP6jtMbIF" || echo 0)" \\\n'
        ..' && if test "$((now - old))" -gt "$((7*3600))" ;then true \\\n'
        .."     && ".. cmdPkgInit .." \\\n"
        ..'     && touch "/tmp/fUXfavAEP6jtMbIF" \\\n'
        ..'   ;else true \\\n'
        ..'     && echo Assume apt cache fresh enough \\\n'
        ..'   ;fi \\\n'
        .." && ".. cmdPkgAdd.."")
    for pkgName, v in pairs(pkgsToAddMerged) do
        assert(type(pkgName) == "string")  assert(v == true, v)
        dst:write(" ".. pkgName)
    end
    dst:write(" \\\n"
        ..' && export MAKE_JOBS='.. envMAKE_JOBS ..' \\\n'
        .."")
end


function writeModulesPrepare( dst )
    for k, mod in pairs(modulesToMake) do
        assert(type(k) == "number", k)
        assert(type(mod) == "table", mod)
        local name = assert(mod.name)
        local version = assert(mod.version)
        local srcTar = name ..'-'.. version ..'.tgz'
        for dload in pairs(mod.dloads) do
            dst:write(""
                ..' && if test -e "'.. dload.dstFile ..'" ;then true \\\n'
                ..'     && echo "OK: EEXISTS: '.. dload.dstFile ..'" \\\n'
                ..'   ;else true \\\n'
                ..'     && echo "Dload  '.. dload.url ..'" \\\n'
                ..'     && curl -Lo "'.. dload.dstFile ..'" "'.. dload.url ..'" \\\n'
                ..'   ;fi \\\n'
                .."")
        end
    end
end


function writeModulesMake( dst )
    for k, mod in pairs(modulesToMake) do
        assert(type(k) == "number", k)
        assert(type(mod) == "table", mod)
        mod:verifyAndFreeze()
        local     name,     version
            = mod.name, mod.version
        assert(name and version)
        local srcTar = name ..'-'.. version ..'.tgz'
        local dstTar = name ..'-'.. version ..'-bin.tgz'
        local dstMd5 = name ..'-'.. version ..'.md5'
        local isWindoof
        if     target == "posix"   then isWindoof = false
        elseif target == "windoof" then isWindoof = true
        else   error("ENOTSUP: ".. target) end
        dst:write(""
            ..' && if test -e "'.. envCACHEDIR ..'/'.. dstTar ..'" ;then true \\\n'
            ..'     && echo "OK: EEXISTS: '.. envCACHEDIR ..'/'.. dstTar ..'" \\\n'
            ..'   ;else (true \\\n'
            ..'     && export VERSION="'.. version ..'" \\\n'
            ..'     && export SRCTAR="'.. envCACHEDIR ..'/'.. srcTar ..'" \\\n'
            ..'     && export DSTTAR="'.. envCACHEDIR ..'/'.. dstTar ..'" \\\n'
            ..'     && export DSTMD5="'.. envCACHEDIR ..'/'.. dstMd5 ..'" \\\n'
            ..'     && rm -rf "'.. envWORKDIR ..'/'.. mod.name ..'" \\\n'
            ..'     && mkdir "'.. envWORKDIR ..'/'.. mod.name ..'" \\\n'
            ..'     && cd "'.. envWORKDIR ..'/'.. mod.name ..'" \\\n'
            .."")
        if mod.ndebug then dst:write('     && export NDEBUG=1 \\\n') end
        for env, _ in pairs(mod.environ) do
            assert(type(env) == "table")
            assert(type(env.k) == "string", env.k)
            assert(type(env.v) == "string", env.v)
            dst:write(""
                ..'     && export "'.. env.k ..'='.. env.v ..'" \\\n'
                .."")
        end
        dst:write(""
            ..'     && (echo "set -e" && echo '.. b64e(mod.makeShell) ..'|base64 -d)|sh - \\\n'
            ..'   );fi \\\n'
            ..' && mkdir -p "'.. envWORKDIR ..'/dist" \\\n'
            ..' && cp -t "'.. envWORKDIR ..'/dist/." "'.. envCACHEDIR ..'/'.. dstTar ..'" \\\n'
            ..' && cp -t "'.. envWORKDIR ..'/dist/." "'.. envCACHEDIR ..'/'.. dstMd5 ..'" \\\n'
            .."")
    end
end


-- [source](https://stackoverflow.com/a/35303321/4415884)
function b64e( src )
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((src:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#src%3+1])
end


function TODO_EgXYTUrb6fVdv5wr()
    if host == "devuan5" and target == "posix" then
        pkgsToAddGlobally = { "ca-certificates", "curl", "tar", "gzip", "make", "gcc", "libc6-dev", }
        envSUDO = "sudo"
        cmdPkgInit  = "$SUDO apt update"
        cmdPkgClean = "$SUDO apt clean"
        cmdPkgAdd   = "$SUDO apt install -y --no-install-recommends"
    elseif host == "devuan5" and target == "windoof" then
        pkgsToAddGlobally = { "ca-certificates", "curl", "tar", "gzip", "make",
            "gcc-mingw-w64-x86-64-posix", }
        envSUDO = "sudo"
        envHOST = "x86_64-w64-mingw32"
        cmdPkgInit  = "$SUDO apt update"
        cmdPkgClean = "$SUDO apt clean"
        cmdPkgAdd   = "$SUDO apt install -y --no-install-recommends"
    else
        error("ENOTSUP: ".. target)
    end
end


function main()
    local dst = io.stdout
    TODO_EgXYTUrb6fVdv5wr()
    defineWhatToBuild()
    collectPkgsToAddOverall()
    dst:write("#!/bin/sh\nset -e\ntrue \\\n")
    writeSystemSetupToDst(dst)
    writeModulesPrepare(dst)
    writeModulesMake(dst)
end


main()
