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
  && poodooSrcWorktree=/home/${USER:?}/work/poodoo \
  && mdisSrcWorktree=./CopyPasta-headers \
  && baseImgTag=docker.tools.post.ch/paisa/alice:04.00.09.00 \
  && imgTag=gcc-for-poodoo:0.0.0-SNAPSHOT \
  && cntnrNm=gcc-for-poodoo \
]=])
end


function write_createDockerimage( dst )
    dst:write("  && echo ")
    dst:write(b64enc([=[
FROM ${baseImgTag}
USER root
WORKDIR /work
COPY CopyPasta-headers /work/CopyPasta-headers
RUN true \
  && SUDO=sudo \
  && $SUDO apt-get install --no-install-recommends -y \
       gcc libc-dev make openjdk-17-jdk-headless \
  && find -exec chown jetty:jetty {} + \
  && find -type d -exec chmod 755 {} + \
  && find -type f -exec chmod 644 {} + \
  && true
USER jetty
]=]).." \\\n")
    dst:write([=[
  | base64 -d \
  | sed -e 's,${baseImgTag},'"${baseImgTag:?}"',' \
  | sudo podman build --file - emptyDir \
]=])
end


function write_restartContainer( dst )
    dst:write([=[
  && $SUDO podman stop "${cntnrNm:?}" \
  && $SUDO podman create --name '"${cntnrNm:?}"' '"${imgTag:?}"' tail -f /dev/null \
  && $SUDO podman start '"${cntnrNm:?}"' \
]=])
end


function write_poodooCopy( dst )
    dst:write([=[
  && (wd=$PWD && cd "${poodooSrcWorktree:?}" \
    && tar --owner=0 --group=0 -cz poodoo-web/src/main/c \
       | $SUDO podman exec -i "${cntnrNm:?}" 'true \
          && cd "${podmanHost_wd:?}"/poodoo \
          && rm -rf $(ls -A) \
          && tar x \
          && true' \
  && true) \
]=])
end


function write_poodooMake( dst )
    dst:write([=[
  && (wd=$PWD && cd poodoo/poodoo-web/src/main/c \
  && BUILD="${wd:?}"/build \
  && CC=gcc \
  && LD=gcc \
  && CFLAGS="-Wall -O3 -fPIC -std=gnu99 -I${wd:?}/mdis/13MD05-90/13Z015-06/INCLUDE/COM -I${wd:?}/mdis/13MD05-90/MDISforLinux/INCLUDE/COM -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include/linux" \
  && LDFLAGS="-shared -lmscan_api -lmdis_api" \
  && mkdir -p "${BUILD:?}" \
  && ${CC:?} -c -o /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${CFLAGS:?} ch_post_it_paisa_poodoo_jni_CanBus.c \
  && ${LD:?} -o "${BUILD:?}"/lib_poodoo_canbus.so /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${LDFLAGS:?} \
  && true) \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\n")
    dst:write("\ntrue `# configure ` \\\n")
    write_vars(dst)
    dst:write("\ntrue `# setup docker container` \\\n")
    dst:write([=[
  && mkdir -p mdis podman emptyDir \
]=])
    write_createDockerimage(dst)
    write_restartContainer(dst)
    dst:write("\ntrue `# build poodoo jni parts` \\\n")
    write_poodooCopy(dst)
    write_poodooMake(dst)
end


main()
