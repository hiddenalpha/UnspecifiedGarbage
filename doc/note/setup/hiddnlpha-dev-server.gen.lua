#!/usr/bin/env lua
--[===========================================================================[

  POSIX script generator to setup dev env for me.

  [Install old php](https://tecadmin.net/how-to-install-php-on-debian-12/)

  ]===========================================================================]

local envSUDO = "sudo"
local cmdPkgInit = "$SUDO apt update"
local cmdPkgAdd = "$SUDO apt install -y --no-install-recommends"
local PKGSTOADD = "vim curl cifs-utils php8.2-cli php8.2-sqlite3 php8.2-fpm nginx"
local envGUESTWD = "/home/${USER:?}/hiddenalpha"
local envGUESTSUDO = "sudo"
local envSMBSHARENAME = "hiddenalpha-web"
local envSHAREMOUNTPOINT = "hiddenalpha-web"

local main


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\ntrue \\\n")
    dst:write([==[
  && SUDO=]==].. envSUDO ..[==[ \
  && PKGADD="]==].. cmdPkgAdd ..[==[" \
  && PKGSTOADD="]==].. PKGSTOADD ..[==[" \
  && now="$(date +%s)" \
  && old="$(date +%s -r "/tmp/26SzNGCeHo0s2syV" || echo 0)" \
  && if test "$((now - old))" -gt "$((7*3600))" ;then true \
      && ]==].. cmdPkgInit ..[==[ \
      && touch "/tmp/26SzNGCeHo0s2syV" \
    ;else true \
      && echo Assume apt cache fresh enough \
    ;fi \
  && ${PKGADD:?} ${PKGSTOADD?} \
  && $SUDO find /etc/nginx -type f -not -wholename '/etc/nginx/snippets*' -not -wholename '/etc/nginx/fastcgi.conf' -not -wholename '/etc/nginx/mime.types' -delete \
  && $SUDO find /etc/nginx -type d -empty -delete \
  && $SUDO rm -rf /var/www \
  && printf '%s\n' \
       'pid /run/nginx.pid;' \
       'events {}' \
       'user www-data www-data;' \
       'http {' \
       '    include /etc/nginx/mime.types;' \
       '    access_log /var/log/nginx/access.log combined;' \
       '    error_log /var/log/nginx/error.log notice; # debug, info, notice, warn, error, crit, alert, emerg.' \
       '    client_body_temp_path /tmp/nginx;' \
       '    proxy_temp_path /tmp/nginx;' \
       '    fastcgi_temp_path /tmp/nginx;' \
       '    uwsgi_temp_path /tmp/nginx;' \
       '    scgi_temp_path /tmp/nginx;' \
       '    server_tokens off;' \
       '    server {' \
       '        listen 0.0.0.0:80 default_server;' \
       '        server_name localhost;' \
       '        root /srv/www;' \
       '        location /example {' \
       '            return 418 "Teapod says hi\n";' \
       '        }' \
       '        location / {' \
       '          root  /mnt/hiddenalpha-web/www;' \
       '        }' \
       '        location ~ \.php$ {' \
       '          root  /mnt/hiddenalpha-web/www;' \
       '          include snippets/fastcgi-php.conf;' \
       '          fastcgi_pass unix:'"$(ls -d /run/php/php*-fpm.sock)"';' \
       '        }' \
       '    }' \
       '}' \
     | $SUDO tee /etc/nginx/nginx.conf >/dev/null \
  && $SUDO mkdir -p /mnt/hiddenalpha-web \
  && printf %s\\n \
       '//10.0.2.2/hiddenalpha-web  /mnt/hiddenalpha-web  cifs  nofail,password=,uid='$(id -u www-data)',gid='$(id -g www-data)'  0  0' \
     | $SUDO tee -a "/etc/fstab" >/dev/null \
  && $SUDO mount /mnt/hiddenalpha-web || true \
  && echo && $SUDO nginx -t && echo \
  && $SUDO service nginx restart \
  && $SUDO sed -i -E 's_(adm:x:4:)_\1'"${USER:?}"'_' /etc/group \
  && printf %s\\n > "/home/${USER:?}/README.txt" \
      '' \
      '  See "/etc/nginx/." for server cfg' \
      '' \
      '  && `# how to open access to server from host` ' \
      '  && ssh ${VM:?} -L localhost:8080:localhost:80 "echo && tail -n0 -F /var/log/nginx/error.log"' \
      '' \
]==])
end


main()

