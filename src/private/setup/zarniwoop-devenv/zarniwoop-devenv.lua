#!/usr/bin/env lua
--[===========================================================================[

  Environment for Zarniwoop development
  =====================================

  Intended to be used with "http://devuan.org/".

  Steps:
  - lua -W "${pathToThisFile:?}" | dos2unix | ssh "${vm:?}" -t 'cat > /var/tmp/setup && cp /var/tmp/setup /tmp/setup'
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
local dioVersion = "054897-060542"
local dioZip = "d-".. dioVersion ..".zip"
local dioUrl = "https://wikit.post.ch/download/attachments/613505757/".. dioZip .."?api=v2"
local quartusRun = "qinst-lite-linux-23.1std.1-993.run"
local quartusUrl = "https://cdrdv2.intel.com/v1/dl/getContent/825277/825299?filename=".. quartusRun
------------------------------------------------------------------------


function define_vars( dst )
    dst:write([=[
  && dioVersion=']=].. dioVersion ..[=[' \
  && dioZip=']=].. dioZip ..[=[' \
  && dioUrl=']=].. dioUrl ..[=[' \
  && quartusUrl=']=].. quartusUrl ..[=[' \
  && quartusRun=']=].. quartusRun ..[=[' \
  && quartusInstaller=/tmp/QuartusProgrammerSetup-24.1std.0.1077-linux.run \
  && quartusInstDir=/opt/QuartusProgrammerSetup-24.1std.0.1077 \
  && SUDO=sudo \
  && workDir=/home/$USER/zarniwoop-workspace \
  && cacheDir=/var/tmp \
]=])
end


function define_whyIsItSoFuckingHardToJustProvideATarball( dst )
    dst:write([=[
  && whyIsItSoFuckingHardToJustProvideATarball () { \
      && cd /tmp \
      && $SUDO mkdir "${quartusInstDir:?}" \
      && $SUDO chmod 777 "${quartusInstDir:?}" \
      && ${quartusInstaller:?} --mode unattended --installdir "${quartusInstDir:?}" --accept_eula 1 \
      && $SUDO find "${quartusInstDir:?}" -exec chown root:root {} + \
    ;} \
]=])
end


function define_aptInstall( dst )
    -- TODO update only once a day.
    dst:write([=[
  && $SUDO apt update \
  && $SUDO apt install -y --no-install-recommends vim make curl git unzip \
       libglib2.0-0 `# Grr... required by shitty intel installers. ` \
]=])
end


function define_storeKnownHashes( dst )
    dst:write([=[
  && storeKnownHashes() { \
      && <<EOF_ieuthg base64 -d | gunzip > "${cacheDir:?}/MD5SUM" &&
H4sIAGYI8GcAA1XLQQoCMQyF4b2ncC20JE3bNMdJmxYGZFBnBsTTW8SFbt7/Np+B6CBFLoYjStMYRk0a
kzTikeV8MQcpFuEZYSz+tdxOsXKXOmpLEhR7VBoVOnXEnqSg/qo8T/goQM6ThGrDMvRkxNlAMAGhGuGf
YslfxXG0YgFSJZ6EFBpI46DAxjzVfVm33V2Xvc9Zj6cL5HHbzaMTIf841tMbjUzVLOcAAAA=
EOF_ieuthg
true \
      && <<EOF_aeohaeou base64 -d | gunzip > "${cacheDir:?}/SHA1SUM" &&
H4sIAAQw+WcAA4XOQU4DMQwAwHtf0XOlRs7ajp0fcATxAidxENJ226YbBLyeGwcufGA0TtSKsEkqnBdy
6TEBIUd0U0VJmS2L9+PpZdrY5+N5XN+GXS4+Xn2ft/NCIT72FiBEEDmv79v8DGNuB8MUa7ISrRhAT6jc
qzYvWjQCccWerUk9nupXXa+bf/yxwr19H4RKoahepUNOAHURXqprQkdiVTUG7A1+f0++3v6Z/QD8h7H9
9AAAAA==
EOF_aeohaeou
true \
    ;} \
]=])
end


function define_downloadStuff( dst )
    local dloads = {
        { dstDir = "${cacheDir:?}", dstFile = "${dioZip:?}", url = "${dioUrl:?}", md5grep = dioVersion },
    }
    dst:write([=[
  && downloadStuff () { true \
]=])
    for _, dload in ipairs(dloads) do
        dst:write([=[
      && if test ! -e "]=].. dload.dstDir .."/".. dload.dstFile ..[=[" ;then true \
          && curl -Lo "]=].. dload.dstDir .."/".. dload.dstFile ..[=[" "]=].. dload.url ..[=[" \
          && grep ']=].. dload.md5grep ..[=[' "${cacheDir:?}/MD5SUM" | (cd "]=].. dload.dstDir ..[=[" && md5sum -c -) \
        ;fi \
]=])
    end
    dst:write([=[
    ;} \
]=])
end


function define_setupDuagonLib( dst )
    dst:write([=[
  && setupDuagonLib () { \
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
  && setupZarniwoop () { \
      && git clone https://gitit.post.ch/scm/isa/zarniwoop.git app \
    ;} \
]=])
end


function define_run( dst )
    dst:write([=[
  && aptInstall \
  && storeKnownHashes \
  && downloadStuff \
  && whyIsItSoFuckingHardToJustProvideATarball \
  && setupDuagonLib \
  && setupZarniwoop \
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
    define_run(dst)
    dst:write([=[
  && printf '\n  Zarniwoop setup complete (TODO install compiler etc)\n\n' \
]=])
    dst:write("\n")
end


main()

