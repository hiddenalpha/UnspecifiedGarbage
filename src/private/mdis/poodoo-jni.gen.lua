#!/usr/bin/env lua
--[===========================================================================[

  "CopyPasta-headers" are from here:

  https://artifactory.tools.post.ch/artifactory/generic-paisa-local/mdis5-src/13MD05-90_02_07.tar.gz

  https://git.duagon.com/project/13/13mdis/linux/13MD05-90/-/tree/master/MDISforLinux?ref_type=heads

  ]===========================================================================]


local thisSrcDir = "/c/work/projects/UnspecifiedGarbage/src/private/mdis"
--
-- 'bapoXXX' intended for BAPO ssh helpers via commented blocks only
local bapoPoodooSrcDir = "/c/work/projects/isa-svc/poodoo"
--
local vmUser = "user"
local vmPoodooSrcDir = "/home/${vmUser:?}/work/poodoo"
local vmMdisHdrsDir = "/opt/mdis-headers"


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
  && thisSrcDir="]=].. thisSrcDir ..[=[" \
  && SUDO=sudo \
  && PODMAN="sudo podman" \
  && thisSrcDir="]=].. thisSrcDir ..[=[" \
  && vmUser="]=].. vmUser ..[=[" \
  && vmPoodooSrcDir="]=].. vmPoodooSrcDir ..[=[" \
  && mdisSrcWorktree="${thisSrcDir:?}/CopyPasta-headers" \
  && vmMdisHdrsDir="]=].. vmMdisHdrsDir ..[=[" \
  && baseImgTag=docker.tools.post.ch/paisa/alice:04.00.09.00 \
  && imgTag=gcc-for-poodoo:0.0.0-SNAPSHOT \
  && cntnrNm=gcc-for-poodoo \
]=])
end


function write_sshHelper( dst )
    dst:write([=[
  && true <<EOF_XAANRAy \

  Helper in case docker is not available on localhost.

  && `# Copy stuff into vm ` \
  && SSH_T="ssh localhost -p22 -T" \
  && thisSrcDir="]=].. thisSrcDir ..[=[" \
  && vmUser="]=].. vmUser ..[=[" \
  && vmMdisHdrsDir="]=].. vmMdisHdrsDir ..[=[" \
  && vmPoodooSrcDir="]=].. vmPoodooSrcDir ..[=[" \
  && bapoPoodooSrcDir="]=].. bapoPoodooSrcDir ..[=[" \
  && (cd ${thisSrcDir:?}/CopyPasta-headers \
     && tar --owner=0 --group=0 -c 13MD05-90/13Z015-06/INCLUDE/COM 13MD05-90/MDISforLinux/INCLUDE/COM) \
     | ${SSH_T:?} 'true \
        && SUDO=sudo \
        && $SUDO mkdir "'"${vmMdisHdrsDir:?}"'" \
        && cd "'"${vmMdisHdrsDir:?}"'" \
        && $SUDO tar x \
        && true' \
  && (cd "${bapoPoodooSrcDir:?}" && tar --owner=0 --group=0 -c poodoo-web/src/main/c) \
     | ${SSH_T:?} 'true \
       && mkdir -p "'"${vmPoodooSrcDir:?}"'" \
       && cd "'"${vmPoodooSrcDir:?}"'" \
       && tar x \
       && true' \

EOF_XAANRAy
true \
]=])
end


function write_createDockerimage( dst )
    dst:write([=[
  && rm -rf mdis-headers \
  && mkdir -p mdis-headers \
  && (cd "${vmMdisHdrsDir:?}" && tar c *) | (cd mdis-headers && tar x) \
]=])
    dst:write("  && echo ".. b64enc([=[
FROM ${baseImgTag}
USER root
WORKDIR /work
COPY mdis-headers/13MD05-90/13Z015-06/INCLUDE/COM /usr/include
COPY mdis-headers/13MD05-90/MDISforLinux/INCLUDE/COM /usr/include
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
  && ${PODMAN:?} create --name "${cntnrNm:?}" -v"${vmPoodooSrcDir:?}:/work/poodoo:rw" "${imgTag:?}" sleep 43200 \
  && ${PODMAN:?} start "${cntnrNm:?}" \
]=])
end


function write_poodooMake( dst )
    dst:write([=[
  && ${PODMAN:?} exec -i "${cntnrNm:?}" sh -c 'true \
       && wd="${PWD:?}" \
       && cd poodoo/poodoo-web/src/main/c \
       && CC=gcc \
       && LD=gcc \
       && CFLAGS="-Wall -Os -fPIC -std=gnu99]=])
     dst:write([=[ -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include]=])
     dst:write([=[ -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include/linux]=])
     -- OBSOLETE dst:write([=[ -I/opt/mdis-headers/13MD05-90/13Z015-06/INCLUDE/COM]=])
     -- OBSOLETE dst:write([=[ -I/opt/mdis-headers/13MD05-90/MDISforLinux/INCLUDE/COM]=])
     dst:write([=[" \
       && LDFLAGS="-shared -lmscan_api -lmdis_api" \
       && mkdir -p "${wd:?}/poodoo/target/x86_64-linux-gnu/lib" \
       && ${CC:?} -c -o /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${CFLAGS:?} ch_post_it_paisa_poodoo_jni_CanBus.c \
       && ${LD:?} -o "${wd:?}"/poodoo/target/x86_64-linux-gnu/lib/lib_poodoo_canbus.so /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${LDFLAGS:?} \
       && cd "${wd:?}" \
       && true' \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\n")
    dst:write("\ntrue `# configure ` \\\n  && printf '\\033[0m' \\\n")
    write_vars(dst)
    dst:write("\ntrue `# ssh helper ` \\\n  && printf '\\033[0m' \\\n")
    write_sshHelper(dst)
    dst:write("\ntrue `# setup docker container` \\\n  && printf '\\033[0m' \\\n")
    write_createDockerimage(dst)
    write_purgeContainer(dst)
    write_createAndStartContainer(dst)
    dst:write("\ntrue `# build poodoo jni parts` \\\n  && printf '\\033[0m' \\\n")
    write_poodooMake(dst)
end


main()
