--[===========================================================================[

  Authelia - SelfHosted SSO
  
  - [github](https://github.com/authelia/authelia)
  - [Doc](https://www.authelia.com/)
  - [detailed tutorial](https://geekscircuit.com/configure-authelia-with-nginx-proxy-manager/)

  ]===========================================================================]

local autheliaVersion = "4.39.1"
local arch = "arm64" -- arm64, amd64
local autheliaPort, publicProxyPort
    = 9091        , 4443
local autheliaUser, autheliaGrp, autheliaUid, autheliaGid
    = "authelia"  , "authelia" , 65533      , 65533
local workdir = "."
local appHome = "/opt/authelia-".. autheliaVersion
local appRoot = workdir
local appSecDir = appRoot .."/etc/authelia/sec"
local srvPriv = "srvPriv.pem"
local srvPubl = "srvPubl.pem"
local srvCert = "srvCert.pem"
local domain = "example.com"
local domainAuth = "auth.example.com"
local basePath = "/authelia"


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
  && workdir=']=].. workdir ..[=[' \
  && cacheDir="/var/tmp" \
  && autheliaVersion=']=].. autheliaVersion ..[=[' \
  && arch=']=].. arch ..[=[' \
  && appHome=']=].. appHome ..[=[' \
  && appRoot=']=].. appRoot ..[=[' \
  && autheliaUser=]=].. autheliaUser ..[=[ \
  && autheliaGrp=]=].. autheliaGrp ..[=[ \
  && autheliaUid=]=].. autheliaUid ..[=[ \
  && autheliaGid=]=].. autheliaGid ..[=[ \
]=])
end


function ensureAppUserExists( dst )
	dst:write([=[
  \
  && `# ensureAppUserExists` \
  && passwd="${appRoot:?}/etc/passwd" \
  && mkdir -p "$(dirname "${passwd:?}")" \
  && (test -e "${passwd:?}" || touch "${passwd:?}") \
  && if ! grep -E "^${autheliaUser:?}:" "${passwd:?}" >/dev/null ;then true \
     && printf '%s:x:%s:%s::/var/lib/authelia:/usr/sbin/nologin\n' \
          "${autheliaUser:?}" "${autheliaUid:?}" "${autheliaGid:?}" \
        >> "${passwd:?}" \
    ;fi \
  && group="${appRoot:?}/etc/group" \
  && mkdir -p "$(dirname "${group:?}")" \
  && (test -e "${group:?}" || touch "${group:?}") \
  && if ! grep -E "^${autheliaGrp:?}:" "${group:?}" > /dev/null ;then true \
      && printf '%s:x:%s:\n' \
           "${autheliaGrp:?}" "${autheliaGid:?}" \
         >> "${group:?}" \
    ;fi \
]=])
end


function aptInstall( dst )
	dst:write([=[
  \
  && `# aptInstall` \
  && $SUDO apt install --no-install-recommends -y \
       curl \
  ;  if test $? -ne 0 ;then true \
      && echo "Package missing? Try: $SUDO apt update" \
      && false \
    ;fi \
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
  && (cd /var/tmp \
  && isFileOk () { true \
      && grep -E "authelia.+${autheliaVersion:?}.+${arch:?}" "${cacheDir:?}/SHA256SUM" \
         | sha256sum -c - ;} \
  && if ! isFileOk ;then true \
      && curl -SL \
          -o "${cacheDir:?}/authelia-v${autheliaVersion:?}-linux-${arch:?}.tar.gz" \
          'https://github.com/authelia/authelia/releases/download/v'"${autheliaVersion:?}"'/authelia-v'"${autheliaVersion:?}"'-linux-'"${arch:?}"'.tar.gz' \
      && isFileOk \
    ;fi\
  && `# EndOf cd`) \
  && mkdir -p "${appRoot:?}"/bin \
              "${appRoot:?}"/etc \
              "${appRoot:?}"/etc/authelia \
              ']=].. appSecDir ..[=[' \
              "${appRoot:?}"/etc/init.d \
              "${appRoot:?}"/etc/nginx \
              "${appRoot:?}"/etc/nginx/sites-available \
              "${appRoot:?}"/var \
              "${appRoot:?}"/var/lib \
              "${appRoot:?}"/var/lib/authelia \
  && rm -rf unpack && mkdir -p unpack \
  && (cd unpack && tar xf "${cacheDir:?}/authelia-v${autheliaVersion:?}-linux-${arch:?}.tar.gz") \
  && mv unpack/authelia-linux-a??64  "${appRoot:?}"/bin/authelia \
  && mv unpack/config.template.yml "${appRoot:?}/etc/authelia/config.yml.skel" \
  && rm unpack/authelia.service \
        unpack/authelia@.service \
        unpack/authelia.sysusers.conf \
        unpack/authelia.tmpfiles.conf \
        unpack/authelia.tmpfiles.config.conf \
  && $SUDO rmdir unpack \
  && <<EOF_YuF8gFVUbHVVBIiA base64 -d|tee "${appRoot:?}/etc/authelia/config.yml" >/dev/null &&
]=].. b64encW80(getAutheliaConfig()) ..[=[
EOF_YuF8gFVUbHVVBIiA
true \
  && base64 -d <<EOF_irLe8foWULF|$SUDO tee "${appRoot:?}/etc/nginx/sites-available/authelia" >/dev/null &&
]=].. b64encW80(getAutheliaNginxSite()) ..[=[
EOF_irLe8foWULF
true \
  && `# create some certs (WHY IS THIS SO FU**ING COMPLICATED)` \
  && caPrivPem=']=].. appSecDir ..[=[/caPriv.pem' \
  && caCrtPem=']=].. appSecDir ..[=[/caCrt.pem' \
  && srvPrivAbs=']=].. appSecDir .."/".. srvPriv ..[=[' \
  && srvPublAbs=']=].. appSecDir .."/".. srvPubl ..[=[' \
  && srvCertPem=']=].. appSecDir .."/".. srvCert ..[=[' \
  && srvSigReq=']=].. appSecDir ..[=[/sigReq.pem' \
  && `# create custom root CA` \
  && openssl genrsa -out "${caPrivPem:?}" 4096 \
  && `# SelfSign custom root CA` \
  && openssl req -x509 -new -nodes -key "${caPrivPem}" -days 365 -out "${caCrtPem:?}" \
       -subj "/C=/ST=SNAKEOIL/L=SNAKEOIL/O=SNAKEOIL/CN=SNAKEOIL.example.com" \
  && `# Create server key` \
  && openssl genrsa -out "${srvPrivAbs:?}" 2048 \
  && `# create sign-request` \
  && openssl req -new -key "${srvPrivAbs:?}" -out "${srvSigReq:?}" \
       -subj '/C=/ST=SNAKEOIL/L=SNAKEOIL/O=SNAKEOIL/CN=SNAKEOIL]=].. domain ..[=[' \
  && `# sign srv with CA` \
  && openssl x509 -req -in "${srvSigReq:?}" -CA "${caCrtPem:?}" -CAkey "${caPrivPem:?}" \
       `#whatisthisshitfor -CAcreateserial` -days 500 -out "${srvCertPem:?}" \
  && `# mk srv pub key` \
  && openssl rsa -in "${srvPrivAbs:?}" -pubout -out "${srvPublAbs:?}" \
  && `# (pseudo-) cleanup` \
  && rm "${srvSigReq:?}" \
  && `# permissions` \
]=])
end


function getAutheliaNginxSite()
	local todoFixme = 4443
	return [=[
server {
	server_name  auth.*;
	listen 443 ssl;
	#root /var/www;  # TODO unused?
	include /etc/nginx/tls-]=].. domain ..[=[.conf;
	set $upstream http://127.0.0.1:]=].. autheliaPort ..[=[;
	location /api/oidc/authorization {
		#internal;
		set $upstream http://127.0.0.1:]=].. autheliaPort ..[=[/api/verify?rd=https://]=].. domainAuth ..[=[:]=].. todoFixme ..[=[/;
		proxy_pass_request_body off;
		proxy_pass $upstream;
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
		proxy_pass $upstream;
		# https://www.authelia.com/integration/proxies/introduction/#required-headers
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_set_header X-Forwarded-Host $http_host;
		proxy_set_header X-Forwarded-Uri $request_uri;
		proxy_set_header X-Forwarded-For $remote_addr;
		# TODO maybe only need ONE of those 'Method' thingies?
		proxy_set_header X-Forwarded-Method $request_method;
		proxy_set_header X-Original-Method $request_method;
		proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
		# https://github.com/authelia/authelia/discussions/7182#discussioncomment-9127811
		proxy_no_cache $cookie_session;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection 'upgrade';
		proxy_cache_bypass $http_upgrade;
	}
}
]=]
end


function getAutheliaConfig( dst )
	return [=[
log:
  # Sending the Authelia process a SIGHUP will cause it to close and reopen
  # the current log file and truncate it.
  level: warn
  format: text
  file_path: "/var/log/authelia/authelia.log"
  keep_stdout: false
server:
  address: "tcp4://127.0.0.1:]=].. autheliaPort ..[=[/"
storage:
  #encryption_key: "TODO_WUoXVW1HUWc918C5H4qApHVi6A3H3d9Z"
  local:
    path: "]=].. appHome ..[=[/var/lib/authelia/authelia.db"
definitions:
  user_attributes:
    grafanaRole:
      expression: '("GrafanaSuperDuperAdmin" in groups) ? "GrafanaAdmin" : (("GrafanaAdmin" in groups) ? "Admin" : (("GrafanaEditor" in groups) ? "Editor" : (("GrafanaViewer" in groups) ? "Viewer" : "None")))'
authentication_backend:
  password_reset:
    disable: true
  file:
    path: ]=].. appHome ..[=[/var/lib/authelia/users.yml
    password:
      algorithm: argon2id
      iterations: 1
      salt_length: 16
      parallelism: 8
      memory: 64
identity_providers:
  oidc:
    jwks:
      # openssl genrsa -out ./foo.pem 4096
      # openssl rsa -in ./foo.pem -outform PEM -pubout -out ./foo.pub.pem
      - key: |
          {{- fileContent "]=].. appSecDir .."/".. srvPriv ..[=[" | nindent 10 }}
        certificate_chain: |
          {{- fileContent "]=].. appSecDir .."/".. srvCert ..[=[" | nindent 10 }}
    claims_policies:
      "myGrafanaClaimsPolicy":
        custom_claims:
          role: { attribute: "grafanaRole" }
    scopes:
      "grafana":
        claims: ["role"]
    clients:
      - client_id: "grafana"
        client_name: "Grafana"
        # authelia crypto hash generate
        client_secret: "$argon2id$v=19$m=65536,t=3,p=4$jEEn1HqJSeZo0+sK+UlObw$31a7CC/kTZZmBXQwdrVWuARsCGIg7OCSpoEKtQqV7rk" # aka "TODO_G7furLckWjthisVannoTying4shi1ttSlh8c"
        public: false
        authorization_policy: "two_factor"
        require_pkce: true
        pkce_challenge_method: "S256"
        redirect_uris:
          - "https://grafana.]=].. domain ..[=[/grafana/login/generic_oauth"
        claims_policy: "myGrafanaClaimsPolicy"
        scopes:
          - openid
          - profile
          #- groups
          - email
          - grafana
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: "client_secret_basic"
session:
  #name: "authelia_session",
  #same_site: "lax",
  #inactivity: "12h",
  #expiration: "3d",
  #remember_me: "300d",
  cookies:
    - domain: example.com
      authelia_url: "https://]=].. domainAuth .. basePath ..[=["
      default_redirection_url: "https://]=].. domainAuth ..":".. publicProxyPort .. basePath ..[=[/"
  #secret: "TODO-really-L0ng_s7r0ng-secr3t-st1nggggg-shoul0-be-used",
  #expiration: 3600s,
  #inactivity: 7200s,
  #domain: "]=].. domain ..[=[",
access_control:
  default_policy: "deny"
  rules:
    - domain: ["noauth.example.com"]
      policy: "bypass"
    - domain: ["TODO.example.com"]
      policy: "two_factor"
notifier:
  disable_startup_check: true
  #filesystem: { filename: "/path/to/notification.txt" }
theme: "dark"
#ntp:
#  address: 'udp://example.com:123'
#  version: 3
#  max_desync: '3s'
#  disable_startup_check: false
#  disable_failure: false
]=]
end


function createUserDbYml( dst )
	local contents = b64encW80([=[
# Use: authelia crypto hash generate
users:
    john:
        displayname: "John Wick"
        password: "$argon2id$v=19$m=65536,t=3,p=2$BpLnfgDsdfdsgdthgdsdfsdfdg6bUGsDY//8mKUYNZZaR0t4MFFSs+iM"  # aka john
        email: john@example.com
        groups: ["GrafanaViewer", "dev"]
    harry:
        displayname: "Thanos Infinity"
        password: "$argon2id$v=19$m=65536,t=3,p=2$BpLnfgjhfrtretasdfdfghja44sdfdfa/8mKUYNZZaR0t4MFFSs+iM"  # aka harry
        email: thanos@authelia.com
        groups: []
]=])
	dst:write([=[
  \
  && `# createUserDbYml` \
  && usersYml="${appRoot:?}/var/lib/authelia/users.yml"  \
  && <<EOF_Ar8AlO6UXh3kYrj0 base64 -d | $SUDO tee "${usersYml:?}" >/dev/null &&
]=].. contents ..[=[
EOF_Ar8AlO6UXh3kYrj0
true \
]=])
end


function createInitdSkel( dst )
	dst:write([=[
  \
  && `# createInitdSkel` \
  && <<EOF_WlEZR87guI9RGVda base64 -d | tee "${appRoot:?}/etc/init.d/authelia" >/dev/null &&
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

# [why](https://www.authelia.com/reference/guides/templating/#enable-templating)
export X_AUTHELIA_CONFIG_FILTERS=template

start () {
	if test -e "${pidfile:?}" ;then echo "EEXISTS: ${pidfile:?}"; exit 2 ;fi
	(sudo -u "${appUser:?}" -- \
		"${appHome:?}/bin/${img:?}" --config "${appHome:?}/etc/authelia/config.yml") &
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


function fixPermissions( dst )
	dst:write([=[
  && `# fixPermissions` \
  && $SUDO find ']=].. appSecDir ..[=[' -type d -exec chown root:${autheliaGid:?} {} + \
  && $SUDO find ']=].. appSecDir ..[=[' -type f -exec chown root:${autheliaGid:?} {} + \
  && $SUDO find ']=].. appSecDir ..[=[' -type d -exec chmod 550 {} + \
  && $SUDO find ']=].. appSecDir ..[=[' -type f -exec chmod 440 {} + \
  && (cd "${appRoot:?}/var/lib" \
      && $SUDO find authelia -exec chown "${autheliaUid:?}:${autheliaGid:?}" {} + \
     ) \
]=])
end


function packIntoTar( dst )
	dst:write([=[
  && `# packIntoTar` \
  && printf '%s\n' \
       "+${autheliaUid:?}  ${autheliaUser:?}:0" \
     > tar-owner \
  && printf '%s\n' \
       "+${autheliaGid:?}  ${autheliaGrp:?}:0" \
     > tar-group \
  && $SUDO tar --owner=0 --group=0 --owner-map=tar-owner --group-map=tar-group \
       -czf "authelia-${autheliaVersion:?}+${arch:?}.tar" bin etc var \
  && md5sum -b "authelia-${autheliaVersion:?}+${arch:?}.tar" > "authelia-${autheliaVersion:?}+${arch:?}.md5" \
  && sha512sum -b "authelia-${autheliaVersion:?}+${arch:?}.tar" > "authelia-${autheliaVersion:?}+${arch:?}.sha512" \
  && `# Note: compression not worth it` \
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
	createUserDbYml(dst)
	createInitdSkel(dst)
	fixPermissions(dst)
	packIntoTar(dst)
end


main()
