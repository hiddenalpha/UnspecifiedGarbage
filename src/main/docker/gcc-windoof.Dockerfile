#
# Windoof GCC build env
#

ARG BASE_IMG=alpine:3.16.0
FROM $BASE_IMG

ARG PKGSTOADD="ca-certificates curl mingw-w64-gcc make tar"
ARG PKGSTODEL="ca-certificates curl"
ARG PKGADD="apk add"
ARG PKGDEL="apk del"
ARG PKGCLEAN="true"
ARG PKGINIT="true"
ARG VERSION_CJSON="1.7.15"
ARG VERSION_EXPAT="2.4.2"
ARG VERSION_LUA="5.4.3"
ARG VERSION_MBEDTLS="3.1.0"
ARG VERSION_SDL2="2.0.20"
ARG VERSION_SQLITE="3.33.0"
ARG VERSION_ZLIB="1.2.11"

ENV NDEBUG=1 MAKE_JOBS=8 HOST=x86_64-w64-mingw32

RUN true \
    && $PKGINIT && $PKGADD $PKGSTOADD \
    #
    && ensureSourceIsCached () { \
           local localPath=${1:?}; \
           local url=${2:?}; \
           if test -f "${localPath:?}"; then \
               echo "[DEBUG] Source avail as \"${localPath:?}\""; \
               return; \
           fi; \
           echo "[DEBUG] Downloading \"${localPath:?}\""; \
           echo "[DEBUG]   from \"${url:?}\""; \
           curl -L "$url" -o "${localPath:?}"; \
       } \
    #
    && makeZlib () { echo "\n  Build zlib\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir "/tmp/zlib" && cd "/tmp/zlib" \
    &&     tar xzf "${tarbal:?}" \
    &&     cd zlib-* \
    &&     mkdir build \
    &&     export DESTDIR=./build BINARY_PATH=/bin INCLUDE_PATH=/include LIBRARY_PATH=/lib \
    &&     sed -i "s;^PREFIX =.\*\$;;" win32/Makefile.gcc \
    &&     make -e -j$MAKE_JOBS -fwin32/Makefile.gcc PREFIX="${HOST:?}"- \
    &&     make -e -fwin32/Makefile.gcc install PREFIX="${HOST:?}"- \
    &&     unset DESTDIR BINARY_PATH INCLUDE_PATH LIBRARY_PATH \
    &&     cp README build/. \
    &&     (cd build && rm -rf lib/pkgconfig) \
    &&     (cd build && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM) \
    &&     (cd build && tar --owner=0 --group=0 -cz *) > "/tmp/zlib-${version:?}-windoof.tgz" \
    &&     cd / && rm -rf "/tmp/zlib" \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f "/tmp/zlib-${version:?}-windoof.tgz" -x include lib \
    &&     echo -e "\n  zlib Done :)\n" \
    &&     cd "${origDir:?}" ; } \
    && ensureSourceIsCached "/tmp/zlib-${VERSION_ZLIB:?}.tgz" "https://downloads.sourceforge.net/project/libpng/zlib/${VERSION_ZLIB:?}/zlib-${VERSION_ZLIB}.tar.gz" \
    && makeZlib "${VERSION_ZLIB:?}" "/tmp/zlib-${VERSION_ZLIB:?}.tgz" \
    #
    && $PKGADD xz \
    && makeExpat () { echo -e "\n  Build Expat\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir /tmp/expat && cd /tmp/expat \
    &&     tar xf "${tarbal:?}" --strip-components=1 \
    &&     mkdir build \
    &&     ./configure --prefix="${PWD:?}/build" --host="${HOST:?}" CFLAGS="-Wall -pedantic --std=c99 -O2" \
    &&     make -e clean \
    &&     make -e -j$MAKE_JOBS \
    &&     make -e install \
    &&     cp README.md build/. \
    &&     (cd build && rm -rf lib/cmake lib/libexpat.la lib/pkgconfig) \
    &&     (cd build && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM) \
    &&     (cd build && tar --owner=0 --group=0 -cz *) > "/tmp/expat-${version:?}-debian.tgz" \
    &&     cd / && rm -rf /tmp/expat \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f /tmp/expat-2.4.2-debian.tgz -x bin include lib \
    &&     echo -e "\n  Expat Done :)\n" ; } \
    && ensureSourceIsCached "/tmp/expat-${VERSION_EXPAT}.txz" "https://github.com/libexpat/libexpat/releases/download/R_2_4_2/expat-${VERSION_EXPAT}.tar.xz" \
    && makeExpat "${VERSION_EXPAT:?}" "/tmp/expat-${VERSION_EXPAT}.txz" \
    #
    && makeCJSON () { echo -e "\n  Build cJSON\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir /tmp/cJSON && cd /tmp/cJSON \
    &&     tar xf "${tarbal:?}" \
    &&     cd * \
    &&     mkdir build build/obj build/lib build/include \
    &&     CC="${HOST:?}-gcc" \
    &&     AR="${HOST:?}-ar" \
    &&     CFLAGS="-Wall -pedantic -fPIC" \
    &&     ${CC:?} $CFLAGS -c -o build/obj/cJSON.o cJSON.c \
    &&     ${CC:?} $CFLAGS -shared -o build/lib/libcJSON.so.1.7.15 build/obj/cJSON.o \
    &&     (cd build/lib && ln -s libcJSON.so."${version:?}" libcJSON.so."${version%.*}") \
    &&     (cd build/lib && ln -s libcJSON.so."${version%.*}" libcJSON.so."${version%.*.*}") \
    &&     ${AR:?} rcs build/lib/libcJSON.a build/obj/cJSON.o \
    &&     unset CC AR CFLAGS \
    &&     cp -t build/. LICENSE README.md \
    &&     cp -t build/include/. cJSON.h \
    &&     rm -rf build/obj \
    &&     (cd build && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM) \
    &&     (cd build && tar --owner=0 --group=0 -f "/tmp/cJSON-${version:?}-debian.tgz" -cz *) \
    &&     cd / && rm -rf /tmp/cJSON \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f /tmp/cJSON-${version:?}-debian.tgz -x include lib \
    &&     echo -e "\n  cJSON Done :)\n"; } \
    && ensureSourceIsCached "/tmp/cJSON-${VERSION_CJSON:?}.tgz" "https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.15.tar.gz" \
    && makeCJSON "${VERSION_CJSON:?}" "/tmp/cJSON-${VERSION_CJSON:?}.tgz" \
    #
    && $PKGADD python3 \
    && makeMbedtls () { echo -e "\n  Build mbedtls\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir /tmp/mbedtls && cd /tmp/mbedtls \
    &&     tar xf "${tarbal:?}" \
    &&     cd * \
    &&     sed -i 's;^DESTDIR=.*$;DESTDIR='"$PWD"'/build;' Makefile \
    # Yet another hack around as gethostname seems not to exist and I do
    # not understand how to disable compiling those "programs" which I
    # do not want anyway.
    &&     rm programs/ssl/ssl_mail_client.c programs/test/udp_proxy.c \
    &&     sed -i '/^\t\+\(ssl\/ssl_mail_client\|test\/udp_proxy\) \+\\$/d' programs/Makefile \
    &&     sed -i '/^ \+ssl_mail_client$/d' programs/ssl/CMakeLists.txt \
    &&     export CC="${HOST:?}-gcc" AR="${HOST:?}-ar" WINDOWS_BUILD=1 SHARED=1 \
    &&     make -e -j$MAKE_JOBS no_test \
    &&     if [ -e build ]; then echo "ERR already exists: $PWD/build"; false; fi \
    &&     make -e install \
    &&     unset CC AR WINDOWS_BUILD SHARED \
    &&     (cd build && tar --owner=0 --group=0 -cz *) > "/tmp/mbedtls-${version:?}-windoof.tgz" \
    &&     cd / && rm -rf /tmp/mbedtls \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f /tmp/mbedtls-${version:?}-windoof.tgz -x bin include lib \
    &&     cd "${origDir:?}" \
    &&     echo -e "\n  mbedtls Done :)\n" ; } \
    && ensureSourceIsCached "/tmp/mbedtls-${VERSION_MBEDTLS:?}.tgz" "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v${VERSION_MBEDTLS:?}.tar.gz" \
    && makeMbedtls "${VERSION_MBEDTLS:?}" "/tmp/mbedtls-${VERSION_MBEDTLS:?}.tgz" \
    #
    && makeSqLite () { echo -e "\n  Build SqLite\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir /tmp/sqlite && cd /tmp/sqlite \
    &&     tar xf "${tarbal:?}" \
    &&     cd * \
    &&     mkdir build \
    &&     $PKGADD gcc musl-dev tcl \
    &&     export CC="${HOST}-gcc" CPP="${HOST:?}-cpp" CXX="${HOST:?}-g++" BCC=gcc \
    &&     ./configure --prefix="${PWD:?}/build" --host=$HOST CC=$CC CPP=$CPP CXX=$CXX BCC=gcc BEXE=.exe config_TARGET_EXEEXT=.exe \
    &&     ln -s mksourceid.exe mksourceid \
    &&     make -e clean \
    &&     make -e -j$MAKE_JOBS \
    &&     $PKGDEL gcc musl-dev tcl \
    &&     make -e install \
    &&     unset CC CPP CXX BCC \
    &&     (cd build && rm -rf lemon* mksourceid lib/pkgconfig lib/*.la) \
    &&     cp README.md LICENSE.md VERSION build/. \
    &&     (cd build && find -not -name MD5SUM -type f -exec md5sum -b {} + > MD5SUM) \
    &&     (cd build && tar --owner=0 --group=0 -cz *) > "/tmp/sqlite-3.33.0-windoof.tgz" \
    &&     cd / && rm -rf /tmp/sqlite \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f /tmp/sqlite-${version:?}-windoof.tgz -x bin include lib \
    &&     cd "$origDir" \
    &&     echo -e "\n  SqLite Done :)\n"; } \
    && ensureSourceIsCached "/tmp/sqlite-${VERSION_SQLITE:?}.tgz" "https://github.com/sqlite/sqlite/archive/refs/tags/version-3.33.0.tar.gz" \
    && makeSqLite "${VERSION_SQLITE:?}" "/tmp/sqlite-${VERSION_SQLITE:?}.tgz" \
    #
    && $PKGADD binutils \
    && makeLua () { echo -e "\n  Build Lua\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir /tmp/lua && cd /tmp/lua \
    &&     tar xf "${tarbal:?}" \
    &&     cd * \
    &&     mkdir -p build/bin build/include build/lib build/man/man1 \
    &&     make -e -j$MAKE_JOBS PLAT=mingw CC="${HOST:?}-gcc -std=gnu99" "AR=${HOST:?}-ar rcu" "RANLIB=${HOST:?}-ranlib" \
    &&     cp -t build/. README \
    &&     cp -t build/bin/. src/lua.exe src/luac.exe \
    &&     cp -t build/include/. src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp \
    &&     cp -t build/lib/. src/liblua.a \
    &&     cp -t build/man/man1/. doc/lua.1 doc/luac.1 \
    &&     (cd build && find -not -name MD5SUM -type f -exec md5sum -b {} + > MD5SUM) \
    &&     (cd build && tar --owner=0 --group=0 -cz *) > "/tmp/lua-${version:?}-windoof.tgz" \
    &&     cd / && rm -rf /tmp/lua \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f /tmp/lua-${version:?}-windoof.tgz -x bin include lib man \
    &&     cd "$origDir" \
    &&     echo -e "\n  Lua Done :)\n"; } \
    && ensureSourceIsCached "/tmp/lua-${VERSION_LUA:?}.tgz" "https://www.lua.org/ftp/lua-${VERSION_LUA:?}.tar.gz" \
    && makeLua "${VERSION_LUA:?}" "/tmp/lua-${VERSION_LUA:?}.tgz" \
    #
    && $PKGADD alsa-lib libxext-dev pulseaudio-dev \
    && makeSDL2 () { echo -e "\n  Build SDL2\n" \
    &&     local version="${1:?}" \
    &&     local tarbal="${2:?}" \
    &&     local origDir="${PWD:?}" \
    &&     mkdir /tmp/SDL2 && cd /tmp/SDL2 \
    &&     tar xf "${tarbal:?}" \
    &&     cd * \
    &&     ./configure --prefix="${PWD:?}/build" --host="${HOST:?}" \
    &&     make -e -j$MAKE_JOBS \
    &&     make -e install \
    &&     cp -t build/. CREDITS.txt LICENSE.txt README-SDL.txt README.md \
    &&     (cd build \
    &&         ls -A \
               | egrep -v '^(CREDITS.txt|LICENSE.txt|README-SDL.txt|RADME.md|bin|lib|include)$' \
               | xargs rm -rf) \
    &&     (cd build && rm -rf lib/cmake lib/pkgconfig lib/*.la) \
    &&     (cd build && find -type f -exec md5sum -b {} + > MD5SUM) \
    &&     (cd build && tar --owner=0 --group=0 -cz *) > "/tmp/SDL2-${version:?}-windoof.tgz" \
    &&     cd / && rm -rf /tmp/SDL2 \
    &&     mkdir -p /usr/local \
    &&     tar -C /usr/local -f /tmp/SDL2-${version:?}-windoof.tgz -x include lib \
    &&     cd "$origDir" \
    &&     echo -e "\n  SDL2 Done :)\n"; } \
    && ensureSourceIsCached "/tmp/SDL2-${VERSION_SDL2:?}.tgz" "https://www.libsdl.org/release/SDL2-${VERSION_SDL2}.tar.gz" \
    && makeSDL2 "${VERSION_SDL2:?}" "/tmp/SDL2-${VERSION_SDL2:?}.tgz" \
    #
    && $PKGDEL $PKGSTODEL && $PKGCLEAN \
    && true

WORKDIR /work

CMD sleep 999999999


