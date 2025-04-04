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


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e \\\n")
    dst:write([=[
  && dioVersion=']=].. dioVersion ..[=[' \
  && dioZip=']=].. dioZip ..[=[' \
  && dioUrl=']=].. dioUrl ..[=[' \
  && quartusUrl=']=].. quartusUrl ..[=[' \
  && quartusRun=']=].. quartusRun ..[=[' \
  && SUDO=sudo \
  && WORKDIR=/home/$USER/zarniwoop-workspace \
  && CACHEDIR=/var/tmp \
  && $SUDO apt install -y --no-install-recommends openssh-server vim make curl git unzip \
  && cd "${CACHEDIR:?}" \
  && <<EOF_ieuthg base64 -d | gunzip > MD5SUM &&
H4sIAGYI8GcAA1XLQQoCMQyF4b2ncC20JE3bNMdJmxYGZFBnBsTTW8SFbt7/Np+B6CBFLoYjStMYRk0a
kzTikeV8MQcpFuEZYSz+tdxOsXKXOmpLEhR7VBoVOnXEnqSg/qo8T/goQM6ThGrDMvRkxNlAMAGhGuGf
YslfxXG0YgFSJZ6EFBpI46DAxjzVfVm33V2Xvc9Zj6cL5HHbzaMTIf841tMbjUzVLOcAAAA=
EOF_ieuthg
true \
  && curl -Lo "${CACHEDIR:?}/${dioZip:?}" "${dioUrl:?}" \
  && grep "${dioVersion:?}" MD5SUM | md5sum -c - \
  && mkdir -p "${WORKDIR:?}" \
  && cd "${WORKDIR:?}" \
  && unzip "${CACHEDIR:?}/${dioZip:?}" \
  && mv DIO021E "d-${dioVersion:?}" \
  && cd "d-${dioVersion:?}/devel" \
  && rm -rf app \
  && git clone https://gitit.post.ch/scm/isa/zarniwoop.git app \
  && cd /tmp \
  && curl -Lo "${CACHEDIR:?}/${quartusRun:?}" "${quartusUrl:?}" \
  && grep -E "lite.*23" MD5SUM | md5sum -c - \
  && mkdir "${CACHEDIR:?}/quartus-inst" \
  && (cd "${CACHEDIR:?}" && sh "${quartusRun:?}" --target "quartus-inst" --noexec) \
  && (cd "${CACHEDIR:?}/quartus-inst" && sh qinst.sh --cli) \
  && printf '\n  Zarniwoop setup complete (TODO install compiler etc)\n\n' \

]=])
end


main()

