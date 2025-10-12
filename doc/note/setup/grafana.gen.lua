--[============================================================================[

  Grafana re-packaging script. Does NOT build, but re-pack only.

  ]============================================================================]

local grafanaVersion = "12.0.0"
local grafanaArch = "amd64" -- amd64, arm64
local grafanaUser = "grafana"
local grafanaHome = "/opt/grafana-".. grafanaVersion
local domain = "grafana.example.com"
local grafanaListenPort = 3000
local publicProxyPort = 4443
local autheliaPort = 443

function vars( dst )
	dst:write([=[
  \
  && `# vars` \
  && SUDO=sudo \
  && grafanaVersion=']=].. grafanaVersion ..[=[' \
  && grafanaArch=]=].. grafanaArch ..[=[ \
  && frserVersion=3.5.0 \
  && grafanaUser=]=].. grafanaUser ..[=[ \
  && grafanaGrp=grafana \
  && grafanaTgz="grafana-${grafanaVersion:?}.linux-${grafanaArch:?}.tar.gz" \
  && grafanaTgzUrl="https://dl.grafana.com/oss/release/${grafanaTgz:?}" \
  && grafanaHome=']=].. grafanaHome ..[=[' \
  && grafanaUid=64798 \
  && grafanaGid=64798 \
  && frserZip="frser-sqlite-datasource-${frserVersion:?}.zip" \
  && frserUrl="https://github.com/fr-ser/grafana-sqlite-datasource/releases/download/v${frserVersion:?}/${frserZip:?}" \
  && workDir="." \
  && cacheDir="/var/tmp" \
]=])
end


-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/base64.lua)
function b64enc( s )local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'return((s:gsub('.',function(x)local r,b='',x:byte()for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and'1'or'0')end return r;end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(x)if(#x<6)then return''end local c=0 for i=1,6 do c=c+(x:sub(i,i)=='1'and 2^(6-i)or 0)end return b:sub(c+1,c+1) end)..({'','==','='})[#s%3+1])end

-- [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/wrap.lua)
function wrap( s )s=s:gsub("(........................................................................)","%1\n"):gsub("\n$","")if s:byte(s:len())~=0x10 then s=s.."\n"end return s end


function b64wrap( s )return wrap(b64enc(s)) end


function ensureAppUserExists( dst )
	dst:write([=[
  \
  && `# ensureAppUserExists` \
  && passwd="${workDir:?}/etc/passwd" \
  && mkdir -p "$(dirname "${passwd:?}")" \
  && (test -e "${passwd:?}" || touch "${passwd:?}") \
  && if ! grep -E "^${grafanaUser:?}:" "${passwd:?}" >/dev/null ;then true \
     && printf '%s:x:%s:%s::/var/lib/grafana:/bin/false\n' \
          "${grafanaUser:?}" "${grafanaUid:?}" "${grafanaGid:?}" \
        >> "${passwd:?}" \
    ;fi \
  && group="${workDir:?}/etc/group" \
  && mkdir -p "$(dirname "${group:?}")" \
  && (test -e "${group:?}" || touch "${group:?}") \
  && if ! grep -E "^${grafanaGrp:?}:" "${group:?}" > /dev/null ;then true \
      && printf '%s:x:%s:\n' \
           "${grafanaGrp:?}" "${grafanaGid:?}" \
         >> "${group:?}" \
    ;fi \
]=])
end


function storeKnownHashes( dst )
	dst:write([=[
  \
  && `# storeKnownHashes` \
  && base64 -d <<EOF_HuYRzPq|gzip -d|$SUDO tee "${cacheDir:?}/MD5SUM" > /dev/null &&
H4sIAG9YFmgAA7NITjZKSko1TEoxMTNMMjJKNEkxtrAwNDAzNDYwSLM0V9BKKypOLdItLszJLEnVTUks
SSzOLy1KTtU11jPVM9CryizgAgAYIIuCRAAAAA==
EOF_HuYRzPq
true \
  && <<EOF_cPnZuN base64 -d|gzip -d|$SUDO tee "${cacheDir:?}/SHA256SUM" >/dev/null &&
H4sIAGiZGmgAA3XPu2qDMQwF4L1P0bmQH8mWLPtxdA2FJkNoofTp407N0GwCCX3nKFjwWBVkCztoYDYG
GcCOGG1yJHXhada7V2uIVNRMEyplqL++nW9aetUT4tEOOD7er1/fJ71dBh2fejvOPy8qKSgmc7/MLoYk
a1E50GAO5aJObUJiAXrapJzVp6tUZAHDM+MSf0aL0BqLB+HCIEcbCS6hgsPVsqqv6WMPwSQ7ClgtbEN2
GZj90fgV/u1hXMjZlttE9ka5xY5pqobS1oAZy4kGDNvB954bTXfbFy0X5zPjsccd9Nw/XpABAAA=
EOF_cPnZuN
true \
]=])
end


function dload( dst )
	dst:write([=[
  \
  && `# dload` \
  && verify () (cd "${cacheDir:?}" && grep -E "${grafanaVersion:?}.*${grafanaArch:?}" SHA256SUM|sha256sum -c -) \
  && if verify ;then true ;else true \
      && (cd "${cacheDir:?}" && curl -LO "${grafanaTgzUrl:?}") \
      && verify \
    ;fi \
  && verify () (cd "${cacheDir:?}" && grep "${frserZip:?}" MD5SUM|md5sum -c -) \
  && if verify ;then true ;else true \
      && (cd "${cacheDir:?}" && curl -LO "${frserUrl:?}") \
      && verify \
    ;fi
]=])
end


function getGrafanaConfig()
    return [=[
[paths]
# HINT: relative to "]=].. grafanaHome ..[=["
# TODO: could we use absolute paths instead?
data = var/lib
plugins = plugins
logs = /var/log/grafana

[server]
domain = ]=].. domain .."\n"..[=[
root_url = https://%(domain)s:]=].. publicProxyPort ..[=[/grafana/
read_timeout = 2

[database]
type = sqlite3
path = grafana.db
wal = true
#query_retries = 0

[environment]
local_file_system_available = false

[remote_cache]
# TODO maybe we should use a redis
#type = redis
#connstr = addr=127.0.0.1:6379,pool_size=100,db=0,ssl=false
#prefix = grafana:

[dataproxy]
row_limit = 1000000

[analytics]
reporting_enabled = false
check_for_updates = false
check_for_plugin_updates = false
feedback_links_enabled = false

[security]
# TODO maybe should be 'true' for my use-case?
disable_initial_admin_creation = true
# default admin user, created on startup
admin_user = admin
# default admin password, can be changed before first start of grafana, or in profile settings
admin_password = XjMoquizkmlp4BgSecMiXBa2h9PJCI6YcSClnzhjctCwAVuT
# default admin email, created on startup
admin_email = grafana@localhost
disable_gravatar = true
cookie_samesite = strict
allow_embedding = false

[snapshots]
enabled = false
external_enabled = false
external_snapshot_url = 
public_mode = false

[users]
default_language = en-US

[sso_settings]
configurable_providers =

[auth]
#disable_login_form = false
#oauth_auto_login = false

[auth.anonymous]
enabled = false
#org_name = Main Org.
#org_role = Viewer
#hide_version = true

[auth.basic]
enabled = false

[auth.ldap]
enabled = false
active_sync_enabled = false

[auth.generic_oauth]
enabled = true
name = SingleSignOn
icon = signin
client_id = grafana
# TODO client_secret = insecure_secret
scopes = openid profile email grafana
empty_scopes = false
allow_assign_grafana_admin = true
# TODO auth_url = https://auth.example.com:]=].. publicProxyPort ..[=[/api/oidc/authorization
# TODO token_url = https://auth.example.com:]=].. autheliaPort ..[=[/api/oidc/token
# TODO api_url = https://auth.example.com:]=].. autheliaPort ..[=[/api/oidc/userinfo
#tls_skip_verify_insecure = false
use_pkce = true
login_attribute_path = preferred_username
name_attribute_path = name
#groups_attribute_path = groups
role_attribute_strict = true
skip_org_role_sync = false
role_attribute_path = role


[smtp]
enabled = false

[log]
mode = console file
level = warn
filters =
user_facing_default_error = "Fehler Details siehe grafana server logs"

[log.file]
format = text
log_rotate = true
max_lines = 100000
max_size_shift = 25
daily_rotate = false
max_days = 720

[quota]
enabled = true
org_user = 10
org_dashboard = 100
org_data_source = 10
org_api_key = 10
org_alert_rule = 100
user_org = 10
global_user = 10
global_org = 10
global_dashboard = 42
global_api_key = 100
global_session = -1
global_alert_rule = 100
global_file = 1000
global_correlations = -1
alerting_rule_group_rules = 100
alerting_rule_evaluation_results = -1

[profile]
enabled = true

[plugins]
plugin_admin_enabled = false
plugin_admin_external_manage_enabled = false

[date_formats]
full_date = YYYY-MM-DD HH:mm:ss
interval_second = HH:mm:ss
interval_minute = HH:mm
interval_hour = DD MMM HH:mm
interval_day = DD MMM
interval_month = MMM YYYY
interval_year = YYYY
]=]
end


function installGrafana( dst )
	dst:write([=[
  \
  && `# installGrafana` \
  && mkdir -p \
       "${workDir:?}/unpack" \
       "${workDir:?}/bin" \
       "${workDir:?}/etc/grafana" \
       "${workDir:?}/etc/init.d" \
       "${workDir:?}/etc/nginx/sites-available" \
       "${workDir:?}/var/lib/grafana" \
       "${workDir:?}/var/log/grafana" \
  && (cd unpack && tar --strip-components=1 -xf "${cacheDir:?}/${grafanaTgz:?}") \
  && base64 -d <<EOF_aXNLhBH|tee "${workDir:?}/etc/grafana/grafana.ini" >/dev/null &&
]=].. b64wrap(getGrafanaConfig()) ..[=[
EOF_aXNLhBH
true \
  && <<EOF_NyHaO9ES base64 -d|tee "${workDir:?}/etc/nginx/sites-available/grafana" >/dev/null &&
]=]..b64wrap(getGrafanaNginxSite())..[=[
EOF_NyHaO9ES
true \
  && <<EOF_YS1PAeob base64 -d|tee "${workDir:?}/etc/init.d/grafana" >/dev/null &&
]=].. b64wrap(getGrafanaSysVInitScript()) ..[=[
EOF_YS1PAeob
true \
  && mv -t "${workDir:?}/bin/." \
       unpack/bin/grafana unpack/bin/grafana-cli unpack/bin/grafana-server \
  && `# TODO are those files even needed?` \
  && mv -t "${workDir:?}/." \
       unpack/conf  unpack/docs  unpack/LICENSE  unpack/NOTICE.md  unpack/npm-artifacts \
       unpack/plugins-bundled unpack/public  unpack/README.md  unpack/storybook  unpack/VERSION \
]=])
end


function getGrafanaSysVInitScript()
    return [=[
### BEGIN INIT INFO
#
# Provides:          grafana
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     3 5
# Default-Stop:      0 1 6
# Short-Description: Grafana
# Description:       Grafana Data Visualization
#
### END INIT INFO

img=grafana
appUser=]=].. grafanaUser ..[=[ 
appHome="]=].. grafanaHome ..[=["
pidfile="/var/run/${img:?}.pid"

start () {
	if test -e "${pidfile:?}" ;then echo "EEXISTS: ${pidfile:?}"; exit 2 ;fi
	(cd "${appHome:?}" && sudo -u "${appUser:?}" -- \
		"${appHome:?}/bin/${img:?}" server --config "${appHome:?}/etc/grafana/grafana.ini" \
		2>&1 > /dev/null
	) &
	childpid=$!
	if test -n "${childpid?}" ;then echo "${childpid:?}" > "${pidfile}" ;fi
	return $e
}

stop () {
	if test ! -e "${pidfile:?}" ;then
		echo "ENOENT: ${pidfile:?}"
		return 0
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
		start)   start  ; e=$? ;;
		stop)    stop   ; e=$? ;;
		reload)  reload ; e=$? ;;
		status)  status ; e=$? ;;
		restart) stop ;sleep 1; start ; e=$? ;;
		*)       echo "ENOTSUP: ${action?}"; e=95 ;;
	esac
	return $e
}

main "$@"
exit $?
]=]
end


function getGrafanaNginxSite()
    return [=[
# "https://grafana.com/tutorials/run-grafana-behind-a-proxy/".
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
upstream grafana {
    server 127.0.0.1:]=].. grafanaListenPort ..[=[;
}
server {
    listen 443 ssl;
    server_name ]=].. domain ..[=[;
    location /grafana {
        rewrite  ^/grafana/(.*)  /$1 break;
        proxy_set_header Host $host;
        proxy_pass http://grafana;
    }
    location /grafana/api/live/ {
        rewrite  ^/grafana/(.*)  /$1 break;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_pass http://grafana;
    }
}
]=]
end


function installFrserSqlitePlugin( dst )
	dst:write([=[
  \
  && `# installFrserSqlitePlugin` \
  && mkdir "${workDir:?}/plugins" \
  && (cd "${workDir:?}/plugins" && unzip -q "${cacheDir:?}/${frserZip:?}") \
]=])
end


function fixPermissions( dst )
	dst:write([=[
  \
  && `# fixPermissions` \
  && $SUDO chown "${grafanaUid:?}:adm" "${workDir:?}"/var/log/grafana \
  && $SUDO find "${workDir:?}/var/lib" -exec chown "${grafanaUid:?}:${grafanaGid:?}" {} + \
]=])
end


function makeTar( dst )
	dst:write([=[
  \
  && `# makeTar` \
  && printf '%s\n' \
       "+${grafanaUid:?}  grafana:0" \
     > tar-owners \
  && printf '%s\n' \
       "adm  adm:0" \
       "+${grafanaUid:?}  grafana:0" \
     > tar-groups \
  && tarFile="grafana-${grafanaVersion:?}+${grafanaArch:?}.tar" \
  && tgzFile="grafana-${grafanaVersion:?}+${grafanaArch:?}.tgz" \
  && md5File="grafana-${grafanaVersion:?}+${grafanaArch:?}.md5" \
  && shaFile="grafana-${grafanaVersion:?}+${grafanaArch:?}.sha512" \
  && tar --owner=0 --group=0 --owner-map=tar-owners --group-map=tar-groups \
       -czf "${tarFile:?}" \
       README.md  LICENSE  NOTICE.md  VERSION  bin  conf  docs  etc  npm-artifacts  plugins \
       plugins-bundled  public  storybook  var \
  && md5sum -b "${tarFile:?}" > "${md5File:?}" \
  && sha512sum -b "${tarFile:?}" > "${shaFile:?}" \
  && `# Note: compression was not worth it` \
]=])
end


function main()
	local dst = io.stdout
	dst:write("#!/bin/sh\nset -e \\\n")
	vars(dst)
	ensureAppUserExists(dst)
	storeKnownHashes(dst)
	dload(dst)
	installGrafana(dst)
	installFrserSqlitePlugin(dst)
	fixPermissions(dst)
	makeTar(dst)
	dst:write("\n")
end


main()
