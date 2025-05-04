--[============================================================================[

  Grafana Install

  ]============================================================================]

local grafanaVersion = "11.2.0"
local grafanaHome = "/opt/grafana-".. grafanaVersion
local domain = "example.com"

function vars( dst )
	dst:write([=[
  \
  && `# vars` \
  && SUDO=sudo \
  && grafanaVersion=']=].. grafanaVersion ..[=[' \
  && grafanaArch="linux-$(a="$(uname -r)" && a=${a##*-} && echo $a)" \
  && grafanaTgz="grafana-${grafanaVersion:?}.${grafanaArch:?}.tar.gz" \
  && grafanaTgzUrl="https://dl.grafana.com/oss/release/${grafanaTgz:?}" \
  && grafanaHome=']=].. grafanaHome ..[=[' \
  && grafanaUser=grafana \
  && grafanaGrp=grafana \
  && frserVersion=3.5.0 \
  && frserZip="frser-sqlite-datasource-${frserVersion:?}.zip" \
  && frserUrl="https://github.com/fr-ser/grafana-sqlite-datasource/releases/download/v${frserVersion:?}/${frserZip:?}" \
  && workDir="/tmp" \
  && cacheDir="/var/tmp" \
]=])
end


-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/base64.lua)
function b64enc( s )local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'return((s:gsub('.',function(x)local r,b='',x:byte()for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and'1'or'0')end return r;end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(x)if(#x<6)then return''end local c=0 for i=1,6 do c=c+(x:sub(i,i)=='1'and 2^(6-i)or 0)end return b:sub(c+1,c+1) end)..({'','==','='})[#s%3+1])end

-- [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/wrap.lua)
function wrap( s )s=s:gsub("(........................................................................)","%1\n"):gsub("\n$","")if s:byte(s:len())~=0x10 then s=s.."\n"end return s end


function b64wrap( s )return wrap(b64enc(s)) end


function ensureUserGrafanaExists( dst )
	dst:write([=[
  \
  && `# ensureUserGrafanaExists` \
  && if ! grep -E "^${grafanaUser}:" /etc/passwd >/dev/null; then echo "No such user '${grafanaUser:?}'"; false; fi \
]=])
end


function storeKnownHashes( dst )
	dst:write([=[
  \
  && `# storeKnownHashes` \
  && printf '%s\n' \
     | tee -a >/dev/null \
  && <<EOF_HuYRzPq base64 -d|gzip -d|$SUDO tee -a "${cacheDir:?}/MD5SUM" >/dev/null &&
H4sIAG9YFmgAA7NITjZKSko1TEoxMTNMMjJKNEkxtrAwNDAzNDYwSLM0V9BKKypOLdItLszJLEnVTUks
SSzOLy1KTtU11jPVM9CryizgAgAYIIuCRAAAAA==
EOF_HuYRzPq
true \
  && <<EOF_cPnZuN base64 -d|gzip -d|$SUDO tee -a "${cacheDir:?}/SHA256SUM" >/dev/null &&
H4sIAKxYFmgAA3XNMQ7CMAwAwJ1XMCM1shM7Tp9jx3aFRBkqkBCvh42JD9wpmHNf08lWbKCOURmkA09E
r4M9qAkPs9Zm1opISdU0IEO6zvNlOzT1rgtiqQXK7Xp/vhY99k7loUfZ3ieVEBST8SWjiSHJulJOoM7s
ykmN6oDABJxhg2JkG1MlPRIY/h27/44PNKtOVcgAAAA=
EOF_cPnZuN
true \
]=])
end


function dload( dst )
	dst:write([=[
  \
  && `# dload` \
  && verify () (cd "${cacheDir:?}" && grep ' .'"${grafanaTgz:?}"'$' SHA256SUM|sha256sum -c -) \
  && if !verify ;then true \
      && (cd "${cacheDir:?}" && curl -LO "${grafanaTgzUrl:?}") \
      && verify \
    ;fi \
  && verify () (cd "${cacheDir:?}" && grep ' .'"${frserZip:?}"'$' MD5SUM|md5sum -c -) \
  && if !verify ;then \
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
domain = ]=].. domain ..[=[
root_url = http://%(domain)s/grafana/
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
#disable_initial_admin_creation = false
# default admin user, created on startup
admin_user = admin
# default admin password, can be changed before first start of grafana, or in profile settings
admin_password = 12345
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

[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer
hide_version = true

[auth.basic]
enabled = true

[auth.ldap]
enabled = false
active_sync_enabled = false

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
enabled = false

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
  && $SUDO mkdir -p \
       /var/log/grafana \
       "${grafanaHome:?}/etc/init.d" \
       "${grafanaHome:?}/var/lib" \
  && cd "${grafanaHome:?}" \
  && $SUDO tar --strip-components=1 -xf "${cacheDir:?}/${grafanaTgz:?}" \
  && $SUDO chown grafana:adm /var/log/grafana \
  && $SUDO chown grafana:grafana "${grafanaHome:?}/var/lib" \
  && base64 -d <<EOF_aXNLhBH|$SUDO tee "${grafanaHome:?}/etc/grafana.ini" >/dev/null &&
]=].. b64wrap(getGrafanaConfig()) ..[=[
EOF_aXNLhBH
true \
  && <<EOF_YS1PAeob base64 -d|$SUDO tee "${grafanaHome:?}/etc/init.d/grafana.skel" >/dev/null &&
]=].. b64wrap(getGrafanaSysVInitScript()) ..[=[
EOF_YS1PAeob
true \
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
appUser=grafana
appHome="]=].. grafanaHome ..[=["
pidfile="/var/run/${img:?}.pid"

start () {
	if test -e "${pidfile:?}" ;then echo "EEXISTS: ${pidfile:?}"; exit 2 ;fi
	(cd "${appHome:?}" && sudo -u "${appUser:?}" -- \
		"${appHome:?}/bin/${img:?}" server --config "${appHome:?}/etc/grafana.ini" \
		2>&1 >> /var/log/grafana/grafana.log
	) &
	childpid=$!
	if test -n "${childpid?}" ;then echo "${childpid:?}" > "${pidfile}" ;fi
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
]=]
end


function installFrserSqlitePlugin( dst )
	dst:write([=[
  \
  && `# installFrserSqlitePlugin` \
  && $SUDO mkdir "${grafanaHome:?}/plugins" \
  && (cd "${grafanaHome:?}/plugins" && $SUDO unzip -q "${cacheDir:?}/${frserZip:?}") \
]=])
end


function main()
	local dst = io.stdout
	dst:write("#!/bin/sh\nset -e \\\n")
	vars(dst)
	ensureUserGrafanaExists(dst)
	storeKnownHashes(dst)
	dload(dst)
	installGrafana(dst)
	installFrserSqlitePlugin(dst)
	dst:write("\n")
end


main()
