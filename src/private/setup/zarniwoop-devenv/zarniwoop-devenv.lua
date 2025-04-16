#!/usr/bin/env lua
--[===========================================================================[

  Environment for Zarniwoop development
  =====================================

  Intended to be used with "http://devuan.org/".

  Steps:
  - lua -W "${pathToThisFile:?}" | dos2unix | ssh "${vm:?}" -T 'cat > /var/tmp/setup && cp /var/tmp/setup /tmp/setup'
  - adapt-n-run setup
  - sudo vim /etc/hostname /etc/hosts
  - set PS1
  - fix proxyPort
  - rm -rf ~/.bash_history ~/.viminfo
  - zerofill, sparsify
  - md5sum, tar, md5sum
  - TEST
  - compress

  TODO: "Quartus Prime 16 Lite" required, but no longer available via intel dload
        page. Need some solution here.
        Half-done kludge for quartus dot-run stuff not working, due to "CPU too old".
        TRY: Maybe try to dload the pure archives and extract manually.

  [maybe helpful for quartus install](https://community.intel.com/t5/Nios-V-II-Embedded-Design-Suite/Nios-V-Processor-Installation-and-Hello-World-Execution-Part-1/m-p/1552554)

  ]===========================================================================]
-- Configure your instance here ----------------------------------------
local dioVersion = "054897-067962" --"054897-060542"
local dioZip = "d-".. dioVersion ..".zip"
local dioUrl = "https://wikit.post.ch/download/attachments/613505757/".. dioZip .."?api=v2"
local qinstRun = "qinst-lite-linux-24.1std.0.1077.run"
local qinstUrl = "".. qinstRun
local cyclonevQdz = "cyclonev-24.1std.0.1077.qdz"
local cyclonevUrl = "https://downloads.intel.com/akdlm/software/acdsinst/24.1std/1077/ib_installers/".. cyclonevQdz
local quartusLiteRun = "QuartusLiteSetup-24.1std.0.1077-linux.run"
local quartusLiteUrl = "https://cdrdv2.intel.com/v1/dl/getContent/849769/849778?filename=".. quartusLiteRun
local quartusPgmRun = "QuartusProgrammerSetup-24.1std.0.1077-linux.run"
local quartusPgmUrl = "https://downloads.intel.com/akdlm/software/acdsinst/24.1std/1077/ib_installers/".. quartusPgmRun
local quartusLiteInstDir = "/opt/QuartusLite"
------------------------------------------------------------------------


function define_vars( dst )
    dst:write([=[
  && dioVersion=']=].. dioVersion ..[=[' \
  && dioZip=']=].. dioZip ..[=[' \
  && dioUrl=']=].. dioUrl ..[=[' \
  && qinstRun=']=].. qinstRun ..[=[' \
  && qinstUrl='https://cdrdv2.intel.com/v1/dl/getContent/825277/825299?filename='"${qinstRun}" \
  && quartusProgrRun="QuartusProgrammerSetup-24.1std.0.1077-linux.run" \
  && zarniwoopGitUrl="https://gitit.post.ch/scm/isa/zarniwoop.git" \
  && quartusLiteRun=']=].. quartusLiteRun ..[=[' \
  && quartusPgmRun=']=].. quartusPgmRun ..[=[' \
  && quartusPgmUrl='https://cdrdv2.intel.com/v1/dl/getContent/825277/825299?filename='"${quartusPgmRun:?}" \
  && cyclonevQdzFile='cyclonev-23.1std.1.993.qdz' \
  && SUDO=sudo \
  && workDir=/home/$USER/zarniwoop-workspace \
  && cacheDir=/var/tmp \
]=])
end


function define_whyIsItSoFuckingHardToJustProvideATarball( dst )
    dst:write([=[
  && whyIsItSoFuckingHardToJustProvideATarball () { true \
      && fuckOne="/opt/QuartusLite" \
      && fuckTwo="/opt/QuartusProgrammer" \
      && $SUDO chmod o+x "${cacheDir:?}/${quartusLiteRun:?}" "${cacheDir:?}/${quartusPgmRun:?}" \
      && $SUDO mkdir "${fuckOne:?}" "${fuckTwo:?}" && $SUDO chown 65534:65534 "${fuckOne:?}" "${fuckTwo:?}" \
      && sudo -u nobody sh -c 'true \
          && "'"${cacheDir}/${quartusLiteRun:?}"'" \
             --mode unattended \
             --disable-components devinfo,arria_lite,cyclone,cyclone10lp,max,max10,quartus_update,riscfree,questa_fse,questa_fe \
             --installdir "'"${fuckOne:?}"'" \
             --accept_eula 1 \
          ' \
]=])
    -- unused?  && sudo -u nobody sh -c 'true \
    -- unused?      && "'"${cacheDir:?}/${quartusPgmRun:?}"'" \
    -- unused?         --mode unattended \
    -- unused?         --installdir "'"${fuckTwo:?}"'" \
    -- unused?         --accept_eula 1 \
    -- unused?      ' \
    dst:write([=[
    ;} \
]=])
end


-- OBSOLETE? function define_whyIsItSoFuckingHardToJustProvideATarball( dst )
-- OBSOLETE?     dst:write([=[
-- OBSOLETE?   && whyIsItSoFuckingHardToJustProvideATarball () { true \
-- OBSOLETE?       && qinstRun=qinst-lite-linux-23.1std.1-993.run \
-- OBSOLETE?       && fuckOne=/tmp/2qIHCfuckOneSS29 \
-- OBSOLETE?       && fuckTwo=/tmp/y31IwfuckTwoNO4P \
-- OBSOLETE?       && fuckThree=/tmp/l1uPNfuckThreeZx \
-- OBSOLETE?       && sudo -u nobody sh -c 'true \
-- OBSOLETE?           && /tmp/"'"${qinstRun:?}"'" \
-- OBSOLETE?              --accept --noexec --keep --nox11 --nochown \
-- OBSOLETE?              --target "'"${fuckOne:?}"'" \
-- OBSOLETE?           ' \
-- OBSOLETE?       && sudo -u nobody sh -c 'true \
-- OBSOLETE?           && QUARTUS_CPUID_BYPASS=1 "'"${fuckOne:?}"'/qinst.sh" \
-- OBSOLETE?              --cli \
-- OBSOLETE?              --download-dir "'"${fuckTwo:?}"'" \
-- OBSOLETE?              --install-dir "'"${fuckThree:?}"'" \
-- OBSOLETE?              --accept-eula 1 \
-- OBSOLETE?              --components quartus,cyclonev,qprogrammer \
-- OBSOLETE?           ' \
-- OBSOLETE?     ;} \
-- OBSOLETE? ]=])
-- OBSOLETE? end


function define_aptInstall( dst )
    -- TODO update only once a day.
    dst:write([=[
  && aptInstall () { true \
      && $SUDO apt update \
      && $SUDO apt install -y --no-install-recommends vim make curl git unzip \
           python3 `# some ugly buildtool needs python` \
           libglib2.0-0 `# Grr... required by some shitty intel installers` \
           `# Some strange systems also need 'ca-certificates'` \
    ;} \
]=])
end


function define_storeKnownHashes( dst )
    dst:write([=[
  && storeKnownHashes() { true \
      && <<EOF_ieuthg base64 -d | gunzip > "${cacheDir:?}/MD5SUM" &&
H4sIAMe8/2cAA1XOywoCMQwF0L1f4VqYoWlek89JmxYGZPAxgvj1Ft3oJvduziWRzDs66BLQyapT7oWd
2CpqFzueYkpMi+kIU1jm13o5UNFmpZfKlh0aOfaSGjaAxraA/yoZJX9UApVBcokekhoHqkQy4ITggfCn
1OSrTKASVRJlbwIKeewUjq7jwVTpeLqu232fzuvextkezynjDPc9ZpjMcL49tsMbpBFgT+cAAAA=
EOF_ieuthg
true \
      && <<EOF_aeohaeou base64 -d | gunzip > "${cacheDir:?}/SHA1SUM" &&
H4sIAKciAGgAA4XOQU4DMQxA0X1P0XWljpzEjp0bsGAB4gSO46BK02lJZxBweliBxKYXeP/nqFKK50IN
XZGlGgUhkMzWc4yxFZJifX943nSs2+3xtPqLr9v1GHEKt7VNMAVgPs6nZfuYxrbsHLFVJuVcqUR07iED
JgrJVSTxT0wL+5/5NC6vQ89nH3dkTTlY1hq0KkDPSaibNK9SJQCSpV60se0P9mnzZfH3f9b01r52jLVi
EDfuUDKARaZoLjl5QhIRJUi9we/fg8/XO2ffh+tQl0gBAAA=
EOF_aeohaeou
true \
    ;} \
]=])
end


function define_downloadStuff( dst )
    local dloads = {
        { dstFile = "${dioZip:?}", url = "${dioUrl:?}", md5grep = dioVersion },
        { dstFile = "${quartusLiteRun:?}", url = "${quartusLiteUrl:?}", sha1grep = quartusLiteRun, },
        { dstFile = "${quartusPgmRun:?}", url = "${quartusPgmUrl:?}", sha1grep = quartusPgmRun, },
        { dstFile = "${cyclonevQdz:?}", url = "${cyclonevUrl:?}", sha1grep = cyclonevQdz, },
    }
    dst:write([=[
  && downloadStuff () { true \
]=])
    for _, dload in ipairs(dloads) do
        local grepCmd
        if dload.md5grep and not dload.sha1grep then
            grepCmd = [=[grep ']=].. dload.md5grep ..[=[' "${cacheDir:?}/MD5SUM" ]=]
                ..[=[| (cd "${cacheDir:?}" && md5sum -c -)]=]
        elseif not dload.md5grep and dload.sha1grep then
            grepCmd = [=[grep ']=].. dload.sha1grep ..[=[' "${cacheDir:?}/SHA1SUM" ]=]
                ..[=[| (cd "${cacheDir:?}" && sha1sum -c -)]=]
        else
            error("TODO_Dbw864SGHs7p8sL6")
        end
        dst:write([=[
      && if ! ]=].. grepCmd ..[=[ ;then true \
          && printf 'Dload "%s"\n '\''- from "%s"\n']=]
            ..[=[ "${cacheDir:?}/]=].. dload.dstFile
            ..[=[" "]=].. dload.url ..[=[" \
          && curl -Lo "${cacheDir:?}/]=].. dload.dstFile ..'" "'.. dload.url ..[=[" \
          && ]=].. grepCmd ..[=[ \
        ;fi \
]=])
    end
    dst:write([=[
    ;} \
]=])
end


function define_setupDuagonLib( dst )
    dst:write([=[
  && setupDuagonLib () { true \
      && mkdir -p "${workDir:?}" \
      && cd "${workDir:?}" \
      && unzip "${cacheDir:?}/${dioZip:?}" \
      && mv DIO021E "d-${dioVersion:?}" \
      && cd "d-${dioVersion:?}/devel" \
      && rm -rf app \
    ;} \
]=])
end


function define_setupZarniwoop( dst )
    dst:write([=[
  && setupZarniwoop () { true \
      && git clone "${zarniwoopGitUrl:?}" app \
    ;} \
]=])
end


function define_updateEnv( dst )
    local snip, paths = "", {
        quartusLiteInstDir .."/nios2eds/bin/gnu/H-x86_64-pc-linux-gnu/bin",
        quartusLiteInstDir .."/nios2eds/bin",
        quartusLiteInstDir .."/quartus/bin",
    }
    for _, path in ipairs(paths) do
        snip = snip ..":".. path
    end
    dst:write([=[
  && updateEnv () { true \
      && (true \
          && printf 'export PATH="${PATH}%s"\n' ']=].. snip ..[=[' \
          && printf 'export QUARTUS_ROOTDIR=/opt/QuartusLite/quartus\n' \
          && true) | $SUDO tee -a /etc/profile >/dev/null \
    ;} \
]=])
end


function define_run( dst )
    dst:write([=[
  && run () { true \
      && aptInstall \
      && storeKnownHashes \
      && downloadStuff \
      && whyIsItSoFuckingHardToJustProvideATarball \
      && setupDuagonLib \
      && setupZarniwoop \
      && updateEnv \
    ;} \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e \\\n")
    define_vars(dst)
    define_aptInstall(dst)
    define_storeKnownHashes(dst)
    define_downloadStuff(dst)
    define_whyIsItSoFuckingHardToJustProvideATarball(dst)
    define_setupDuagonLib(dst)
    define_setupZarniwoop(dst)
    define_updateEnv(dst)
    define_run(dst)
    dst:write([=[
  && run \
  && printf '\n  Zarniwoop setup complete (TODO install compiler etc)\n\n' \
]=])
    dst:write("\n")
end


main()

