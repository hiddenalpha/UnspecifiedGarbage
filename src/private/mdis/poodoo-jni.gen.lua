#!/usr/bin/env lua
--[===========================================================================[

  "CopyPasta-headers" are from here:

  https://artifactory.tools.post.ch/artifactory/generic-paisa-local/mdis5-src/13MD05-90_02_07.tar.gz

  https://git.duagon.com/project/13/13mdis/linux/13MD05-90/-/tree/master/MDISforLinux?ref_type=heads

  ]===========================================================================]


-- [Source 1](https://stackoverflow.com/a/35303321/4415884)
-- [Source 2](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/base64.lua)
function b64enc( src )
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


function wrap72( str )
    return str
        :gsub("(........................................................................)", "%1\n")
        :gsub("\n$", "")
end


function write_vars( dst )
    dst:write([=[
  && SUDO=sudo \
  && PODMAN="sudo podman" \
  && poodooSrcWorktree=/home/${USER:?}/work/poodoo \
  && mdisSrcWorktree=./CopyPasta-headers \
  && baseImgTag=docker.tools.post.ch/paisa/alice:04.00.09.00 \
  && imgTag=gcc-for-poodoo:0.0.0-SNAPSHOT \
  && cntnrNm=gcc-for-poodoo \
]=])
end


function write_createDockerimage( dst )
    dst:write("  && echo ".. b64enc([=[
FROM ${baseImgTag}
USER root
WORKDIR /work
COPY CopyPasta-headers /opt/mdis-headers
RUN true \
  && SUDO=sudo \
  && $SUDO apt-get install --no-install-recommends -y \
       gcc libc-dev make openjdk-17-jdk-headless \
  && mkdir /work/poodoo \
  && find /work -exec chown jetty:jetty {} + \
  && find /work -type d -exec chmod 755 {} + \
  && find /work -type f -exec chmod 644 {} + \
  && true
USER jetty
]=]).." \\\n")
    dst:write([=[
  | base64 -d \
  | sed -e 's,${baseImgTag},'"${baseImgTag:?}"',' \
  | ${PODMAN:?} build --tag "${imgTag:?}" --file - . \
]=])
end


function write_purgeContainer( dst )
    dst:write([=[
  && (${PODMAN:?} stop "${cntnrNm:?}" || true) \
  && ${PODMAN:?} rm -f "${cntnrNm:?}" \
]=])
end


function write_createAndStartContainer( dst )
    dst:write([=[
  && ${PODMAN:?} create --name "${cntnrNm:?}" "${imgTag:?}" sleep 43200 \
  && ${PODMAN:?} start "${cntnrNm:?}" \
]=])
end


function write_poodooCopy( dst )
    dst:write([=[
  && (wd=$PWD && cd "${poodooSrcWorktree:?}" \
    && tar --owner=0 --group=0 -cz poodoo-web/src/main/c \
       | ${PODMAN:?} exec -i "${cntnrNm:?}" sh -c 'true \
          && cd /work/poodoo \
          && rm -rf $(ls -A) \
          && tar xz \
          && true' \
  && true) \
]=])
end


function write_poodooMake( dst )
    dst:write([=[
  && ${PODMAN:?} exec -i "${cntnrNm:?}" sh -c 'true \
       && wd="${PWD:?}" \
       && cd poodoo/poodoo-web/src/main/c \
       && CC=gcc \
       && LD=gcc \
       && CFLAGS="-Wall -O1 -fPIC -std=gnu99]=])
     dst:write([=[ -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include]=])
     dst:write([=[ -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include/linux]=])
     dst:write([=[ -I/opt/mdis-headers/13MD05-90/13Z015-06/INCLUDE/COM]=])
     dst:write([=[ -I/opt/mdis-headers/13MD05-90/MDISforLinux/INCLUDE/COM]=])
     dst:write([=[" \
       && LDFLAGS="-shared -lmscan_api -lmdis_api" \
       && mkdir -p "${wd:?}/build" \
       && ${CC:?} -c -o /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${CFLAGS:?} ch_post_it_paisa_poodoo_jni_CanBus.c \
       && ${LD:?} -o "${wd:?}"/build/lib_poodoo_canbus.so /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${LDFLAGS:?} \
       && cd "${wd:?}" \
       && true' \
]=])
end


function write_cpyResultToHostFromContainer( dst )
    dst:write([=[
  && mkdir -p build \
  && (cd build && rm -rf $(ls -A)) \
  && ${PODMAN:?} exec -i "${cntnrNm:?}" sh -c 'cd build && tar c $(ls -A)' | (cd build && tar x) \
  && echo && file build/* && echo \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\n")
    dst:write("\ntrue `# configure ` \\\n")
    write_vars(dst)
    dst:write("\ntrue `# setup docker container` \\\n")
    write_createDockerimage(dst)
    write_purgeContainer(dst)
    write_createAndStartContainer(dst)
    dst:write("\ntrue `# build poodoo jni parts` \\\n")
    write_poodooCopy(dst)
    write_poodooMake(dst)
    write_cpyResultToHostFromContainer(dst)
end


main()
