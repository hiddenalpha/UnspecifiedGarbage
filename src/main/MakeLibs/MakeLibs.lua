#!/usr/bin/env lua
--[[

  I'm ways too dumb to "just build a lib. It's easy...". Shut up! Look how long
  this file is! Then you know how "easy" it is!

  Source:
  https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/MakeLibs/

  TODO: Test if (especially wdoof) builds are usable at all.
  TODO: Add GLFW.

-- Config begins here -------------------------------------------------------]]

local host = "devuan5" -- "devuan5", "debian9"
local target = "posix" -- "posix", "windoof"
local version_cJSON = "1.7.15"
local version_expat = "2.4.2"
local version_lua = "5.4.3"
local version_mbedtls = "3.6.2"
local version_mbedtls_framework = "a2c76945ca090f9dd099001d7c5158557f5a2036"
local version_nuklear = "4.12.2"
local version_GLFW = "3.4"
local version_sqlite = "3.33.0"
local version_zlib = "1.2.11"
local ndebug_cJSON = true
local ndebug_expat = true
local ndebug_lua = true
local ndebug_mbedtls = true
local ndebug_GLFW = true
local ndebug_sqlite = true
local ndebug_zlib = true
local envWORKDIR = "/home/${USER:?}/work"
local envCACHEDIR = "/var/tmp"
local envMAKE_JOBS = 8

-- end Config -----------------------------------------------------------------

local TODO_EgXYTUrb6fVdv5wr, b64e, collectPkgsToAddOverall, defineExpat, defineLua, defineMbedtls,
    defineNuklear, defineGLFW, defineWhatToBuild, defineCJSON, defineZlib, main, newModule,
    newModuleDloads, newModuleEnviron, writeModulesMake, writeModulesPrepare, writeSystemSetupToDst
local envSUDO, envHOST
local cmdPkgInit, cmdPkgClean, cmdPkgAdd
local modulesToMake, pkgsToAddMerged, pkgsToAddGlobally


function defineWhatToBuild()
    local m
    modulesToMake = {}
    local add = function(m) m:verifyAndFreeze() table.insert(modulesToMake, m) end
    if version_cJSON   then add(defineCJSON  ()) end
    if version_expat   then add(defineExpat  ()) end
    if version_lua     then add(defineLua    ()) end
    if version_mbedtls then add(defineMbedtls()) end
    if version_nuklear then add(defineNuklear()) end
    if version_GLFW    then add(defineGLFW   ()) end
    if version_sqlite  then add(defineSqlite ()) end
    if version_zlib    then add(defineZlib   ()) end
end


function defineCJSON()
    local cjson = newModule()
    cjson.name = "cJSON"
    cjson.version = version_cJSON
    cjson.ndebug = ndebug_cJSON
    cjson.pkgsToAdd = {}
    cjson.dloads:add{
        url = "https://github.com/DaveGamble/cJSON/archive/refs/tags/v".. version_cJSON ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/cJSON-'.. version_cJSON ..'.t__',
    }
    cjson.makeShell = 'true \\\n'
    if target == "posix" then
        cjson.makeShell = cjson.makeShell .. ' && HOST_= \\\n'
    elseif target == "windoof" then
        cjson.makeShell = cjson.makeShell .. ' && HOST_=x86_64-w64-mingw32 \\\n'
    else error("ENOTSUP: "..target) end
    cjson.makeShell = cjson.makeShell .. [===[ \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && mkdir build build/obj build/lib build/include \
      && CFLAGS="-Wall -pedantic -fPIC" \
      && ${HOST_}cc $CFLAGS -c -o build/obj/cJSON.o cJSON.c \
      && ${HOST_}cc $CFLAGS -shared -o build/lib/libcJSON.so.${VERSION:?} build/obj/cJSON.o \
      && unset CFLAGS \
      && (cd build/lib \
         && MIN=${VERSION%.*} && MAJ=${MIN%.*} \
         && ln -s libcJSON.so.${VERSION:?} libcJSON.so.${MIN:?} \
         && ln -s libcJSON.so.${MIN:?} libcJSON.so.${MAJ} \
         ) \
      && ${HOST_?}ar rcs build/lib/libcJSON.a build/obj/cJSON.o \
      && cp -t build/. LICENSE README.md \
      && cp -t build/include/. cJSON.h \
      && rm build/obj -rf \
      && (cd build && true \
         && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM \
         && tar --owner=0 --group=0 -czf "${DSTTAR:?}" * \
         ) \
    ]===]
    cjson:verifyAndFreeze()
    return cjson
end


function defineExpat()
    local expat = newModule()
    expat.name = "expat"
    expat.version = version_expat
    expat.ndebug = ndebug_expat
    expat.pkgsToAdd = { "make", "findutils", }
    expat.dloads:add{
        url = "https://github.com/libexpat/libexpat/releases/download/R_2_4_2/expat-".. version_expat ..".tar.xz",
        dstFile = envCACHEDIR ..'/src/expat-'.. version_expat ..'.t__',
    }
    expat.makeShell = [===[ true \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && mkdir build \
    ]===]
    if target == "posix" then
        expat.makeShell = expat.makeShell .. [===[ \
          && ./configure --prefix=${PWD:?}/build CFLAGS="-Wall -pedantic --std=c99 -O2" \
        ]===]
    elseif target == "windoof" then
        expat.makeShell = expat.makeShell .. [===[ \
          && HOST=x86_64-w64-mingw32 \
          && ./configure --prefix=${PWD:?}/build --host=${HOST:?} CFLAGS="-Wall -pedantic --std=c99 -O2" \
        ]===]
    else error("ENOTSUP: "..target) end
    expat.makeShell = expat.makeShell .. [===[ \
      && make -e clean \
      && make -e -j${MAKE_JOBS:?} \
      && make -e install \
      && cp README.md build/. \
      && (cd build \
          && rm -rf lib/cmake lib/libexpat.la lib/pkgconfig \
          && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM \
          && tar --owner=0 --group=0 -cz * > "${DSTTAR:?}" \
         ) \
    ]===]
    expat:verifyAndFreeze()
    return expat
end


function defineLua()
    local lua = newModule()
    lua.name = "lua"
    lua.version = version_lua
    lua.ndebug = ndebug_lua
    lua.pkgsToAdd = {}
    lua.dloads:add{
        url = "https://www.lua.org/ftp/lua-".. version_lua ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/'.. lua.name ..'-'.. lua.version ..'.t__',
    }
    lua.makeShell = [===[ true \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && mkdir build build/bin build/include build/lib build/man build/man/man1 \
    ]===]
    if target == "posix" then
        lua.makeShell = lua.makeShell .. ' && export CFLAGS="-Wall -Wextra -DLUA_USE_DLOPEN=1" \\\n'
    elseif target == "windoof" then
        -- windoof is too "doooof" again ...
        lua.makeShell = lua.makeShell .. ' && export CFLAGS="-Wall -Wextra" \\\n'
    else error("ENOTSUP: "..target) end
    if not lua.ndebug then  lua.makeShell = lua.makeShell ..''
        ..' && export CFLAGS="$CFLAGS -ggdb -DLUAI_ASSERT -DLUA_USE_APICHECK" \\\n'
    end
    if target == "posix" then lua.makeShell = lua.makeShell .. [===[ \
        && export CFLAGS="$CFLAGS -DLUA_USE_POSIX" \
        && make -e -j${MAKEJOBS} AR='ar rcu'\
        && cp -t build/. README \
        && cp -t build/bin/. src/lua src/luac \
    ]===]
    elseif target == "windoof" then lua.makeShell = lua.makeShell .. [===[ \
        && sed -i -E 's,(RANLIB=)(strip ),\1'"${HOST:?}-"'\2,' src/Makefile \
        && make -e -j${MAKE_JOBS:?} PLAT=mingw \
            "CC=${HOST:?}-gcc -std=gnu99" \
            "AR=${HOST:?}-ar rcu" \
            "RANLIB=${HOST}-ranlib" \
        && cp -t build/. README \
        && cp -t build/bin/. src/lua.exe src/luac.exe \
        ]===]
    else error("ENOTSUP: "..target) end
    lua.makeShell = lua.makeShell .. [===[ \
      && cp -t build/include/. src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp \
      && cp -t build/lib/. src/liblua.a \
      && cp -t build/man/man1/. doc/lua.1 doc/luac.1 \
      && (cd build \
          && rm -rf include/lua.hpp \
          && find -not -name MD5SUM -type f -exec md5sum -b {} + > MD5SUM \
          && tar --owner=0 --group=0 -cz * > "${DSTTAR:?}" \
         ) \
    ]===]
    lua:verifyAndFreeze()
    return lua
end


function defineMbedtls()
    local mbedtls = newModule()
    mbedtls.name = "mbedtls"
    mbedtls.version = version_mbedtls
    mbedtls.ndebug = ndebug_mbedtls
    mbedtls.pkgsToAdd = { "make", "findutils", }
    mbedtls.environ:add("FRAMEWORK_VERSION", version_mbedtls_framework)
    mbedtls.environ:add("FRAMEWORK_SRCTAR",
        envCACHEDIR ..'/src/mbedtls-framework-g'.. version_mbedtls_framework ..'.t__')
    mbedtls.dloads:add{
        url = "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/mbedtls-".. mbedtls.version ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/'.. mbedtls.name ..'-'.. mbedtls.version ..'.t__',
    }
    mbedtls.dloads:add{
        url = "https://github.com/Mbed-TLS/mbedtls-framework/archive/".. version_mbedtls_framework ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/mbedtls-framework-g'.. version_mbedtls_framework ..'.t__',
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
  ]===]
    mbedtls:verifyAndFreeze()
    return mbedtls
end


function defineNuklear()
    local nk = newModule()
    nk.name = "nuklear"
    nk.version = version_nuklear
    nk.ndebug = true -- has no effect
    nk.dloads:add{
        url = "https://github.com/Immediate-Mode-UI/Nuklear/archive/refs/tags/".. version_nuklear ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/'.. nk.name ..'-'.. nk.version ..'.t__',
    }
    nk.pkgsToAdd = { "findutils" }
    nk.makeShell = [===[ true \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && mkdir include \
      && cp nuklear.h include/. \
      && find include -type f -exec md5sum -b {} + > MD5SUM \
      && tar --owner=0 --group=0 -cz include MD5SUM > "${DSTTAR:?}" \
    ]===]
    nk:verifyAndFreeze()
    return nk
end


function defineGLFW()
    local glfw = newModule()
    glfw.name = "GLFW"
    glfw.version = version_GLFW
    glfw.ndebug = ndebug_GLFW
    glfw.dloads:add{
        url = "https://github.com/glfw/glfw/archive/refs/tags/".. glfw.version ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/'.. glfw.name ..'-'.. glfw.version ..'.t__',
    }
    glfw.pkgsToAdd = { "cmake", "libxrandr-dev", "libxinerama-dev", "libxcursor-dev", "libxi-dev", }
    glfw.makeShell = [===[ true \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && rm -rf build \
    ]===]
    if target == "posix" then
        glfw.makeShell = glfw.makeShell .. [===[ \
          && cmake \
               -D GLFW_BUILD_EXAMPLES=0 \
               -D GLFW_BUILD_TESTS=0 \
               -D GLFW_BUILD_DOCS=1 \
               -D USE_MSVC_RUNTIME_LIBRARY_DLL=0 \
               -D GLFW_BUILD_X11=1 \
               -D GLFW_BUILD_WAYLAND=0 `# TODO enable ` \
               . \
          && CC=gcc \
        ]===]
    elseif target == "windoof" then
        glfw.makeShell = glfw.makeShell .. [===[ \
          && cmake \
               -D GLFW_BUILD_EXAMPLES=0 \
               -D GLFW_BUILD_TESTS=0 \
               -D GLFW_BUILD_DOCS=1 \
               -D GLFW_BUILD_WIN32=1 \
               -D USE_MSVC_RUNTIME_LIBRARY_DLL=1 \
               -D CMAKE_TOOLCHAIN_FILE=CMake/x86_64-w64-mingw32.cmake \
               . \
          && CC=${HOST_?}gcc \
        ]===]
    else error("ENOTSUP: "..target) end
    glfw.makeShell = glfw.makeShell .. [===[ \
      && make clean CC="${CC:?}" \
      && make -j"${MAKE_JOBS:?}" CC="${CC:?}" \
      && mkdir  build  build/include  build/lib \
      && cp -art build/include/. include/* \
      && cp -t build/lib/.  src/libglfw3.a \
      && (cd build && find $(ls -A) -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM ) \
      && mkdir dist \
      && (cd build && tar --owner=0 --group=0 -czf "${DSTTAR:?}" $(ls -A) ) \
    ]===]
    glfw:verifyAndFreeze()
    return glfw
end


function defineSqlite()
    local sqlite = newModule()
    sqlite.name = "sqlite"
    sqlite.version = version_sqlite
    sqlite.ndebug = ndebug_sqlite
    sqlite.pkgsToAdd = { "tcl" }
    sqlite.dloads:add{
        url = "https://github.com/sqlite/sqlite/archive/refs/tags/version-".. sqlite.version ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/'.. sqlite.name ..'-'.. sqlite.version ..'.t__',
    }
    sqlite.makeShell = [===[ true \
      && tar --strip-components 1 -xf "${SRCTAR:?}" \
      && mkdir build \
    ]===]
    if target == "posix" then
        sqlite.makeShell = sqlite.makeShell .. [===[ \
          && ./configure --prefix=${PWD:?}/build \
          && make -e clean && make -e -j${MAKE_JOBS:?} && make -e install \
        ]===]
    elseif target == "windoof" then
        sqlite.makeShell = sqlite.makeShell .. [===[ \
          && ./configure --prefix=${PWD:?}/build --host=${HOST:?} \
               CC=${CC:?} BEXE=.exe config_TARGET_EXEEXT=.exe \
          && rm -f mksourceid && ln -s mksourceid.exe mksourceid \
          && make -e clean \
          && make -e -j${MAKE_JOBS:?} BCC=gcc\
          && make -e install \
          && (cd build && rm -rf lemon* mksourceid lib/pkgconfig lib/*.la) \
        ]===]
    else error("ENOTSUP: "..target) end
    sqlite.makeShell = sqlite.makeShell .. [===[ \
      && cp README.md LICENSE.md VERSION build/. \
      && (cd build \
          && rm -rf lib/libsqlite3.la lib/pkgconfig \
          && find -not -name MD5SUM -type f -exec md5sum -b {} + > MD5SUM \
          && tar --owner=0 --group=0 -cz * > "${DSTTAR:?}" \
         ) \
    ]===]
    sqlite:verifyAndFreeze()
    return sqlite
end


function defineZlib()
    local zlib = newModule()
    zlib.name = "zlib"
    zlib.version = version_zlib
    zlib.ndebug = ndebug_zlib
    zlib.dloads:add({
        url = "https://downloads.sourceforge.net/project/libpng/zlib/".. zlib.version .."/zlib-".. zlib.version ..".tar.gz",
        dstFile = envCACHEDIR ..'/src/'.. zlib.name ..'-'.. zlib.version ..'.t__',
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
    dst:write(""
        .." && (cd '".. envCACHEDIR .."' && mkdir -p src dst md5) \\\n"
        .."")
    for k, mod in pairs(modulesToMake) do
        assert(type(k) == "number", k)
        assert(type(mod) == "table", mod)
        local name = assert(mod.name)
        local version = assert(mod.version)
        for dload in pairs(mod.dloads) do
            dst:write(""
                ..' && if test -e "'.. dload.dstFile ..'" ;then true \\\n'
                ..'     && echo "OK: EEXISTS: '.. dload.dstFile ..'" \\\n'
                ..'   ;else true \\\n'
                ..'     && echo curl -Lo "'.. dload.dstFile ..'" "'.. dload.url ..'" \\\n'
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
        local srcTar = name ..'-'.. version ..'.t__'
        local dstTar = name ..'-'.. version ..'+$(/usr/bin/*gcc -dumpmachine).tgz'
        local dstMd5 = name ..'-'.. version ..'.md5'
        local isWindoof
        if     target == "posix"   then isWindoof = false
        elseif target == "windoof" then isWindoof = true
        else   error("ENOTSUP: ".. target) end
        dst:write(""
            ..' && if test -e "'.. envCACHEDIR ..'/dst/'.. dstTar ..'" ;then true \\\n'
            ..'     && echo "OK: EEXISTS: '.. envCACHEDIR ..'/dst/'.. dstTar ..'" \\\n'
            ..'   ;else (true \\\n'
            ..'     && export VERSION="'.. version ..'" \\\n'
            ..'     && export SRCTAR="'.. envCACHEDIR ..'/src/'.. srcTar ..'" \\\n'
            ..'     && export DSTTAR="'.. envCACHEDIR ..'/dst/'.. dstTar ..'" \\\n'
            ..'     && rm -rf "'.. envWORKDIR ..'/make/'.. mod.name ..'" \\\n'
            ..'     && (cd "'.. envWORKDIR ..'" && mkdir -p make) \\\n'
            ..'     && (cd "'.. envWORKDIR ..'/make" && mkdir -p "'.. mod.name ..'") \\\n'
            ..'     && cd "'.. envWORKDIR ..'/make/'.. mod.name ..'" \\\n'
            .."")
        if mod.ndebug then dst:write('     && export NDEBUG=1 \\\n') end
        for env, _ in pairs(mod.environ) do
            assert(type(env) == "table")
            assert(type(env.k) == "string", env.k)
            assert(type(env.v) == "string", env.v)
            dst:write('     && export "'.. env.k ..'='.. env.v ..'" \\\n')
        end
        dst:write(""
            ..'     && (echo "set -e" && echo '.. b64e(mod.makeShell) ..'|base64 -d)|sh - \\\n'
            ..'     && DSTMD5="'.. envCACHEDIR ..'/md5/'.. dstMd5 ..'" \\\n'
            ..'     && (cd "$(dirname "${DSTTAR:?}")" && md5sum -b "$(basename "${DSTTAR:?}")" >> "${DSTMD5:?}") \\\n'
            ..'   );fi \\\n'
            ..' && mkdir -p "'.. envWORKDIR ..'/dist" \\\n'
            ..' && cp -t "'.. envWORKDIR ..'/dist/." "'.. envCACHEDIR ..'/dst/'.. dstTar ..'" \\\n'
            ..' && cp -t "'.. envWORKDIR ..'/dist/." "'.. envCACHEDIR ..'/md5/'.. dstMd5 ..'" \\\n'
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
