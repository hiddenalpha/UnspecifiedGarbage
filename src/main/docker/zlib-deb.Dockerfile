#
#   curl -sSL "https://git.hiddenalpha.ch/UnspecifiedGarbage.git/plain/src/main/docker/zlib-deb.Dockerfile" | docker build -f- . -t "zlib-deb:$(date +%Y%m%d)"
#
ARG PARENT_IMAGE=debian:9-slim
FROM $PARENT_IMAGE

ARG ZLIB_VERSION="1.2.11"
ARG PKGS_TO_ADD="curl gcc make tar libc-dev ca-certificates vim"
ARG PKGS_TO_DEL=""
ARG PKG_INIT="apt-get update"
ARG PKG_ADD="apt-get install -y --no-install-recommends"
ARG PKG_DEL="apt-get purge"
ARG PKG_CLEAN="apt-get clean"

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
    && ./configure --prefix="${WORKDIR:?}/build" \
    && make -e \
    && make install \
    && cp README "${WORKDIR}/build/." \
    && cd "${WORKDIR}/build" \
    && rm -rf lib/pkgconfig \
    && find -type f -not -name MD5SUM -exec md5sum -b {} + > MD5SUM \
    && tar --owner=0 --group=0 -cz * > "${WORKDIR:?}/tarballs/zlib-${ZLIB_VERSION:?}-debian.tgz" \
    && cd "${WORKDIR}" \
    && rm -rf "${WORKDIR:?}/tree" "${WORKDIR:?}/build" \
    # install zlib
    && mkdir -p /usr/local/ \
    && tar -C /usr/local -f "${WORKDIR:?}/tarballs/zlib-${ZLIB_VERSION:?}-debian.tgz" -x include lib \
    # cleanup
    && cd "${THEOLDPWD:?}" \
    && unset THEOLDPWD WORKDIR \
    && $PKG_DEL $PKGS_TO_DEL \
    && $PKG_CLEAN \
    && true

WORKDIR /work

