#!/usr/bin/env lua
--[===========================================================================[

  https://artifactory.tools.post.ch/artifactory/generic-paisa-local/mdis5-src/13MD05-90_02_07.tar.gz

  https://git.duagon.com/project/13/13mdis/linux/13MD05-90/-/tree/master/MDISforLinux?ref_type=heads

  ]===========================================================================]


function write_vars( dst )
    dst:write([=[
  && poodooSrcWorktree=/c/work/projects/isa-svc/poodoo \
  && mdisSrcWorktree=/c/work/projects/forks/duagon-mdis/from-artifactory \
  && baseImgTag= docker.tools.post.ch/paisa/alice:04.00.09.00\
  && imgTag=gcc-for-poodoo:0.0.0-SNAPSHOT \
  && cntnrNm=gcc-for-poodoo \
  && podmanHost_T="ssh ${vm:?} -T" \
  && podmanHost_t="ssh ${vm:?} -t" \
  && podmanHost_wd="/work" \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e \\\n")
    write_vars(dst)
    dst:write([=[
  && ${podmanHost_T:?} 'true \
       && cd '${podmanHost_wd:?}' \
       && mkdir -p mdis podman emptyDir \
       && true' \
  && echo <<EOF_3VcAAM9rA |
RlJPTSAke2Jhc2VJbWdUYWd9ClVTRVIgcm9vdApSVU4gdHJ1ZSBcXAogICYmIFNVRE89c3VkbyBc
XAogICYmICRTVURPIGFwdC1nZXQgaW5zdGFsbCAtLW5vLWluc3RhbGwtcmVjb21tZW5kcyAteSBc
XAogICAgICAgZ2NjIGxpYmMtZGV2IG1ha2Ugb3Blbmpkay0xNy1qZGstaGVhZGxlc3MgXFwKICAm
JiBta2RpciAvd29yayBcXAogICYmIGNob3duIGpldHR5OmpldHR5IC93b3JrIFxcCiAgJiYgdHJ1
ZQpVU0VSIGpldHR5Cg==
EOF_3VcAAM9rA
  sed -E 's,${baseImgTag},'"${baseImgTag:?}"',' \
  | ${podmanHost_T:?} 'true \
      && cd '${podmanHost_wd:?}'/emptyDir \
      && sudo podman stop '"${cntnrNm:?}"' \
      && sudo podman create -f- . \
      && sudo podman create --name '"${cntnrNm:?}"' '"${imgTag:?}"' tail -f /dev/null \
      && $SUDO podman start '"${cntnrNm:?}"' \
      && true' \
  && ${podmanHost_T:?} 'true \
       && cd '${podmanHost_wd:?}' \
       && mkdir -p mdis podman \
       && true' \
  && tar --owner=0 --group=0 -cz -C "${mdisSrcWorktree:?}" \
       13MD05-90/MDISforLinux/INCLUDE/COM/MEN \
       13MD05-90/13Z015-06/INCLUDE/COM/MEN \
     | ${podmanHost_T:?} 'sudo podman exec -u0 -i '"${cntnrNm:?}"' sh -c '\''true \
         && cd '${podmanHost_wd:?}'/mdis \
         && rm -rf * \
         && tar x \
         && true'\''' \
]=])
    write_poodooCopy(dst)
--     dst:write([=[
-- ]=])
end


function write_poodooCopy( dst )

  && wd=$PWD && (cd "${poodooSrcWorktree:?}" \
    && tar --owner=0 --group=0 -cz poodoo-web/src/main/c \
       | ${podmanHost_T:?} 'sudo podman exec -i '${cntnrNm:?}' '\''true \
          && cd '${podmanHost_wd:?}'/poodoo \
          && rm -rf * \
          && tar x \
          && true'\''' \
  && true) \
  \
  && ${podmanHost_T:?} 'sudo podman exec -i '${cntnrNm:?}' sh -c '\''true \
       && cd '"${podmanHost_wd:?}"' \
       && mkdir poodoo mdis \
       && (cd poodoo && tar xf /var/tmp/poodoo-src.tgz) \
       && (cd mdis && tar xf /var/tmp/mdis-headers.tgz) \
       && true'\''' \

  && wd=$PWD \
  && (cd poodoo/poodoo-web/src/main/c \
  && BUILD="${wd:?}"/build \
  && CC=gcc \
  && LD=gcc \
  && CFLAGS="-Wall -O3 -fPIC -std=gnu99 -I${wd:?}/mdis/13MD05-90/13Z015-06/INCLUDE/COM -I${wd:?}/mdis/13MD05-90/MDISforLinux/INCLUDE/COM -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include -I/usr/lib/jvm/java-1.17.0-openjdk-amd64/include/linux" \
  && LDFLAGS="-shared -lmscan_api -lmdis_api" \
  && mkdir -p "${BUILD:?}" \
  && ${CC:?} -c -o /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${CFLAGS:?} ch_post_it_paisa_poodoo_jni_CanBus.c \
  && ${LD:?} -o "${BUILD:?}"/lib_poodoo_canbus.so /tmp/ch_post_it_paisa_poodoo_jni_CanBus.o ${LDFLAGS:?} \
  && true) \


main()
