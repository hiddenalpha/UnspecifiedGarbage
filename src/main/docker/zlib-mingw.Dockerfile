#
#   curl -sSL "https://git.hiddenalpha.ch/UnspecifiedGarbage.git/plain/src/main/docker/zlib-mingw.Dockerfile" | docker build -f- . -t "zlib-deb:$(date +%Y%m%d)"
#
ARG PARENT_IMAGE=alpine:3.16.0
FROM $PARENT_IMAGE

ARG ZLIB_VERSION="1.2.11"
ARG PKGS_TO_ADD="curl mingw-w64-gcc make tar ca-certificates"
ARG PKGS_TO_DEL=""
ARG PKG_INIT="true"
ARG PKG_ADD="apk add "
ARG PKG_DEL="apk del"
ARG PKG_CLEAN="true"

RUN true \
    && WORKDIR="/work" \
    && THEOLDPWD="$PWD" \
    # Prepare System
    && $PKG_INIT \
    && $PKG_ADD $PKGS_TO_ADD \
    # Prepare zlib
    && mkdir "${WORKDIR:?}" && cd "${WORKDIR:?}" \
    && mkdir tarballs tree build \
    && curl -sSL -o "tarballs/zlib-${ZLIB_VERSION}.tgz" "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION:?}.tar.gz" \
    && cd "${WORKDIR:?}/tree" \
    && tar --strip-components 1 -xzf "${WORKDIR:?}/tarballs/zlib-${ZLIB_VERSION:?}.tgz" \
    # Make zlib
    && sed -i "s;^PREFIX =.\*\$;;" win32/Makefile.gcc \
    && export DESTDIR=../build BINARY_PATH=/bin INCLUDE_PATH=/include LIBRARY_PATH=/lib \
    && make -e -fwin32/Makefile.gcc PREFIX=x86_64-w64-mingw32- \
    && make -e -fwin32/Makefile.gcc install PREFIX=x86_64-w64-mingw32- \
    && unset DESTDIR BINARY_PATH INCLUDE_PATH LIBRARY_PATH \
    && cp README ../build/. \
    && cd "${WORKDIR:?}/build" \
    && rm -rf lib/pkgconfig \
    && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM \
    && tar --owner=0 --group=0 -cz * > "${WORKDIR:?}/tarballs/zlib-1.2.11-windoof.tgz" \
    && cd "${WORKDIR:?}" \
    && rm -rf "${WORKDIR:?}/tree" "${WORKDIR:?}/build" \
    # Install zlib
    && mkdir -p /usr/local/x86_64-w64-mingw32 \
    && tar -C /usr/x86_64-w64-mingw32 -f "${WORKDIR:?}/tarballs/zlib-1.2.11-windoof.tgz" -x include lib \
    && cd "${THEOLDPWD:?}" \
    && unset THEOLDPWD WORKDIR \
    && $PKG_DEL $PKGS_TO_DEL \
    && $PKG_CLEAN \
    && true

WORKDIR /work


