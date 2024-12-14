#!/usr/bin/env lua
--[===========================================================================[

  POSIX script generator to setup a php development server.

  [Install old php](https://tecadmin.net/how-to-install-php-on-debian-12/)

  ]===========================================================================]

local envSUDO = "sudo"
local cmdPkgInit = "$SUDO apt update"
local cmdPkgAdd = "$SUDO apt install -y --no-install-recommends"
local PKGSTOADD = "vim curl php8.2-cli php8.2-sqlite3 cifs-utils"
local envGUESTWD = "/home/${USER:?}/hiddenalpha"
local envGUESTSUDO = "sudo"
local envSMBSHARENAME = "beef-webapp"
local envSHAREMOUNTPOINT = "beef-webapp"

local main


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\ntrue \\\n")
    dst:write([==[
  && SUDO=]==].. envSUDO ..[==[ \
  && PKGADD="]==].. cmdPkgAdd ..[==[" \
  && PKGSTOADD="]==].. PKGSTOADD ..[==[" \
  && now="$(date +%s)" \
  && old="$(date +%s -r "/tmp/zhRL18M4yJyzRVRG" || echo 0)" \
  && if test "$((now - old))" -gt "$((7*3600))" ;then true \
      && ]==].. cmdPkgInit ..[==[ \
      && touch "/tmp/zhRL18M4yJyzRVRG" \
    ;else true \
      && echo Assume apt cache fresh enough \
    ;fi \
  && ${PKGADD:?} ${PKGSTOADD?} \
  && printf %s\\n > "/home/${USER:?}/README.txt" \
      '' \
      '  && `# how to open access to server from host` ' \
      '  && ssh ${VM:?} -L localhost:8080:localhost:80 "echo && tail -n0 -F /var/log/nginx/error.log"' \
      '' \
]==])
end


main()

