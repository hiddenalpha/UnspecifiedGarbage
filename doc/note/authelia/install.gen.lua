--[===========================================================================[

  Authelia - SelfHosted SSO
  
  - [github](https://github.com/authelia/authelia)
  - [Doc](https://www.authelia.com/)
  - [detailed tutorial](https://geekscircuit.com/configure-authelia-with-nginx-proxy-manager/)

  ]===========================================================================]

local autheliaVersion = "4.39.1"
local appHome = "/opt/authelia-".. autheliaVersion


-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/base64.lua)
function b64enc( src )local
b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
return((src:gsub('.',function(x)local r,b='',x:byte()for i=8,1,-1 do
r=r..(b%2^i-b%2^(i-1)>0 and'1'or'0')end return
r;end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(x)if(#x<6)then
return''end local c=0 for i=1,6 do c=c+(x:sub(i,i)=='1'and 2^(6-i)or
0)end return b:sub(c+1,c+1)end)..({'','==','='})[#src%3+1])end


-- [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/wrap.lua)
function wrap80( str
)str=str:gsub("(................................................................................)","%1\n"):gsub("\n$","")if
str:byte(str:len())~=0x10 then str=str.."\n"end return str end


function b64encW80( str ) return wrap80(b64enc(str)) end


function vars( dst )
	dst:write([=[
  \
  && `# vars` \
  && SUDO=sudo \
  && cacheDir=/var/tmp \
  && autheliaVersion=']=].. autheliaVersion ..[=[' \
  && arch='amd64' \
  && appHome=']=].. appHome ..[=[' \
  && autheliaUser=authelia \
  && autheliaGrp=authelia \
]=])
end


function ensureAppUserExists( dst )
	dst:write([=[
  \
  && `# ensureAppUserExists` \
  && if ! grep -E "^${autheliaUser:?}:" /etc/passwd >/dev/null; then true \
     && echo "No such user '${autheliaUser:?}'"; \
     && false \
    ;fi \
]=])
end


function aptInstall( dst )
	dst:write([=[
  \
  && `# aptInstall` \
  && `# Package missing? Try: $SUDO apt update` \
  && $SUDO apt install --no-install-recommends -y \
       curl \
]=])
end


function storeKnownHashes( dst )
	dst:write([=[
  \
  && `# storeKnownHashes` \
  && printf '%s\n' \
      '8f7492da4fc5122721314e936dace124fbd4fc946e27f2723011bba6b16a8bc4 *authelia-v4.39.1-linux-amd64.tar.gz' \
      '254e481f104665561656402164c2190539f06a3088742050f062d0ece7673d81 *authelia-v4.39.1-linux-arm64.tar.gz' \
     | $SUDO tee "${cacheDir:?}/SHA256SUM" >/dev/null \
]=])
end


function installAuthelia( dst )
	dst:write([=[
  \
  && `# installAuthelia` \
  && cd /var/tmp \
  && isFileOk () { true \
      && grep -E "authelia.+${autheliaVersion:?}.+${arch:?}" "${cacheDir:?}/SHA256SUM" \
         | sha256sum -c - ;} \
  && if ! isFileOk ;then true \
      && curl -SL \
          -o "${cacheDir:?}/authelia-v${autheliaVersion:?}-linux-${arch:?}.tar.gz" \
          'https://github.com/authelia/authelia/releases/download/v'"${autheliaVersion:?}"'/authelia-v'"${autheliaVersion:?}"'-linux-'"${arch:?}"'.tar.gz' \
      && isFileOk \
    ;fi\
  && $SUDO mkdir /opt/authelia-"${autheliaVersion:?}" \
                 /opt/authelia-"${autheliaVersion:?}"/unpack \
                 /opt/authelia-"${autheliaVersion:?}"/bin \
                 /opt/authelia-"${autheliaVersion:?}"/etc \
                 /opt/authelia-"${autheliaVersion:?}"/var \
                 /opt/authelia-"${autheliaVersion:?}"/var/lib \
                 /opt/authelia-"${autheliaVersion:?}"/skel \
  && $SUDO chown "${autheliaUser:?}:${autheliaGrp:?}" \
       /opt/authelia-"${autheliaVersion:?}"/var/lib \
  && cd /opt/authelia-"${autheliaVersion:?}/unpack" \
  && $SUDO tar xf "${cacheDir:?}/authelia-v${autheliaVersion:?}-linux-${arch:?}.tar.gz" \
  && cd /opt/authelia-"${autheliaVersion:?}" \
  && $SUDO mv unpack/authelia-linux-a??64  bin/authelia \
  && $SUDO mv -t skel/. \
       unpack/config.template.yml \
  && $SUDO rm \
       unpack/authelia.service \
       unpack/authelia@.service \
       unpack/authelia.sysusers.conf \
       unpack/authelia.tmpfiles.conf \
       unpack/authelia.tmpfiles.config.conf \
  && $SUDO rmdir unpack \
]=])
end


function createConfig( dst )
	dst:write([=[
  \
  && `# createConfig` \
  && <<EOF_YuF8gFVUbHVVBIiA base64 -d|$SUDO tee "${appHome:?}/etc/config.yml" >/dev/null &&
]=]..b64encW80([=[
log:
    # Sending the Authelia process a SIGHUP will cause it to close and reopen
    # the current log file and truncate it.
    level: "warn"  # OneOf: trace, debug, info, warn, error.
    format: "text"
    file_path: "/var/log/authelia/authelia.log"
    keep_stdout: false
server:
    address: tcp4://127.0.0.1:9091/
storage:
    #encryption_key: "WUoXVW1HUWc918C5H4qApHVi6A3H3d9Z" # TODO
    local:
        path: "/opt/authelia-]=].. autheliaVersion ..[=[/var/lib/authelia.db"
authentication_backend:
    password_reset: { disable: true }
    file:
        path: "/opt/authelia-]=].. autheliaVersion ..[=[/etc/users.yml
        password:
            algorithm: argon2id
            iterations: 1
            salt_length: 16
            parallelism: 8
            memory: 64
session:
    #name: "authelia_session"
    #same_site: "lax"
    #inactivity: "12h"
    #expiration: "3d"
    #remember_me: "300d"
    cookies: [{
        domain: "example.com",
        authelia_url: "https://auth.example.com/login",
        default_redirection_url: "https://example.com/wherever/to/go",
    }]
#    # This secret can also be set using the env variables AUTHELIA_SESSION_SECRET_FILE
#    secret: "a-really-L0ng_s7r0ng-secr3t-st1nggggg-shoul0-be-used"
#    expiration: 3600  # seconds
#    inactivity: 7200  # seconds
#    domain: "example.com"  # Should match whatever your root protected domain is
#identity_validation:
#    reset_password:
#        jwt_secret: "TODO-a-super-long-strong-string-of-letters-numbers-characters"
#totp:
#    issuer: example.com
#    period: 30
#    skew: 1
access_control:
    default_policy: deny
    rules: [{
        domain: [ "noauth.example.com" ],
        policy: bypass,
    },{
        domain: [ "foo.example.com" ],
        policy: one_factor,
        #networks: [ "192.168.1.0/24" ],
    }]
notifier:
    disable_startup_check: true
    #filesystem:
    #    filename: "/path/to/notification.txt"
#smtp:
#    ...
#oidc:
#    ...
theme: "dark"
]=]) ..[=[
EOF_YuF8gFVUbHVVBIiA
true \
]=])
end


function createUserDbYml( dst )
	local contents = b64encW80([=[
# Use: authelia crypto hash generate
users:
    john:
        displayname: "John Wick"
        password: "$argon2id$v=19$m=65536,t=3,p=2$BpLnfgDsdfdsgdthgdsdfsdfdg6bUGsDY//8mKUYNZZaR0t4MFFSs+iM"
        email: john@example.com
        groups: ["admins", "dev"]
    harry:
        displayname: "Thanos Infinity"
        password: "$argon2id$v=19$m=65536,t=3,p=2$BpLnfgjhfrtretasdfdfghja44sdfdfa/8mKUYNZZaR0t4MFFSs+iM"
        email: thanos@authelia.com
        groups: []
]=])
	dst:write([=[
  \
  && `# createUserDbYml` \
  && <<EOF_Ar8AlO6UXh3kYrj0 base64 -d | $SUDO tee "${appHome:?}/etc/users.yml" >/dev/null &&
]=].. contents ..[=[
EOF_Ar8AlO6UXh3kYrj0
true \
]=])
end


function createInitdSkel( dst )
	dst:write([=[
  \
  && `# createInitdSkel` \
  && <<EOF_WlEZR87guI9RGVda base64 -d | $SUDO tee "${appHome:?}/skel/authelia.initd.sh" >/dev/null &&
]=] .. b64encW80([=[
#!/bin/sh
### BEGIN INIT INFO
#
# Provides:          authelia
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     3 5
# Default-Stop:      0 1 6
# Short-Description: Authelia SSO server
# Description:       Authelia SingleSignOn server
#
### END INIT INFO

img=authelia
appUser=authelia
appHome="]=].. appHome ..[=["
pidfile="/var/run/${img:?}.pid"

#. /lib/init/vars.sh
#. /lib/lsb/init-functions

start () {
	if test -e "${pidfile:?}" ;then echo "EEXISTS: ${pidfile:?}"; exit 2 ;fi
	(sudo -u "${appUser:?}" -- \
		"${appHome:?}/bin/${img:?}" --config "${appHome:?}/etc/config.yml") &
	e=$?
	childpid=$!
	if test $e -ne 0 ;then
		# TODO I guess this doesn't work
		echo ERR $e
		return $e
	else
		echo "${childpid:?}" > "${pidfile}"
	fi
	return $e
}

stop () {
	if test ! -e "${pidfile:?}" ;then
		echo "ENOENT: ${pidfile:?}"
		return 2
	fi
	childpid="$(cat "${pidfile:?}")"
	kill "${childpid:?}"
	e=$?
	if test "$e" != "0" ;then
		echo "ESRCH: ${childpid:?}"
	fi
	rm "${pidfile:?}"
	return $e
}

reload () {
	pkill -SIGHUP "${img:?}"
}

status () {
	if test ! -e "${pidfile:?}" ;then
		echo "ENOENT: ${pidfile:?}"
		return 2
	fi
	childpid="$(cat "${pidfile:?}")"
	descr="$(ps -fp "${childpid:?}")"
	if test -z "$(echo "${descr?}"|tail -n+2)" ;then
		echo "ENOENT: pid ${childpid:?}"
		return 2
	else
		echo "${descr:?}"
		return 0
	fi
}

main () {
	action=$1
	e=99
	case "$action" in
		start)  start  ; e=$? ;;
		stop)   stop   ; e=$? ;;
		reload) reload ; e=$? ;;
		status) status ; e=$? ;;
		restart) stop; start ;;
		*)     echo "ENOTSUP: ${action?}"; e=95 ;;
	esac
	return $e
}

main "$@"
exit $?
]=]) .. [=[
EOF_WlEZR87guI9RGVda
true \
]=])
end


function createNginxSkel( dst )
	local contents = b64encW80([=[
#
# TODO this is INCOMPLETE!
#
http {
	server {
		location /authelia {
			internal;
			set $upstream_authelia http://127.0.0.1:9091/api/verify;
			proxy_pass_request_body off;
			proxy_pass $upstream_authelia;
			proxy_set_header Content-Length "";
			#
			# Timeout if the real server is dead
			proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
			client_body_buffer_size 128k;
			proxy_set_header Host $host;
			proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $remote_addr; 
			proxy_set_header X-Forwarded-Proto $scheme;
			proxy_set_header X-Forwarded-Host $http_host;
			proxy_set_header X-Forwarded-Uri $request_uri;
			proxy_set_header X-Forwarded-Ssl on;
			proxy_redirect  http://  $scheme://;
			proxy_http_version 1.1;
			proxy_set_header Connection "";
			proxy_cache_bypass $cookie_session;
			proxy_no_cache $cookie_session;
			proxy_buffers 4 32k;
			#
			send_timeout 5m;
			proxy_read_timeout 240;
			proxy_send_timeout 240;
			proxy_connect_timeout 240;
		}
		location / {
			set $upstream_<appname> http://<your application internal ip address with port number>;  #ADD IP AND PORT OF SERVICE
			proxy_pass $upstream_<appname>;  #change name of the service
			#
			auth_request /login;
			auth_request_set $target_url $scheme://$http_host$request_uri;
			auth_request_set $user $upstream_http_remote_user;
			auth_request_set $groups $upstream_http_remote_groups;
			proxy_set_header Remote-User $user;
			proxy_set_header Remote-Groups $groups;
			error_page 401 =302 https://auth.<example.com>/?rd=$target_url;
			#
			client_body_buffer_size 128k;
			#
			proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
			#
			send_timeout 5m;
			proxy_read_timeout 360;
			proxy_send_timeout 360;
			proxy_connect_timeout 360;
			#
			proxy_set_header Host $host;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_set_header X-Forwarded-Proto $scheme;
			proxy_set_header X-Forwarded-Host $http_host;
			proxy_set_header X-Forwarded-Uri $request_uri;
			proxy_set_header X-Forwarded-Ssl on;
			proxy_redirect  http://  $scheme://;
			proxy_http_version 1.1;
			proxy_set_header Connection "";
			proxy_cache_bypass $cookie_session;
			proxy_no_cache $cookie_session;
			proxy_buffers 64 256k;
			#
			# add your ip range here, and remove this comment!
			set_real_ip_from 192.168.1.0/16;
			set_real_ip_from 172.0.0.0/8;
			set_real_ip_from 10.0.0.0/8;
			real_ip_header X-Forwarded-For;
			real_ip_recursive on;
		}
	}
}
]=])
	dst:write([=[
  \
  && `# createNginxSkel (WARN: INCOMPLETE)` \
  && <<EOF_r9b5ORa7zE7nsTFr base64 -d | $SUDO tee "${appHome:?}/skel/nginx.conf" >/dev/null &&
]=].. contents ..[=[
EOF_r9b5ORa7zE7nsTFr
true \
]=])
end


function main()
	local dst = io.stdout
	dst:write("#!/bin/sh\nset -e \\\n")
	vars(dst)
	ensureAppUserExists(dst)
	storeKnownHashes(dst)
	aptInstall(dst)
	installAuthelia(dst)
	createConfig(dst)
	createUserDbYml(dst)
	createInitdSkel(dst)
	createNginxSkel(dst)
end


main()
