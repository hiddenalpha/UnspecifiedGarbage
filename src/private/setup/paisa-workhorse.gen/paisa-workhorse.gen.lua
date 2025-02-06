#!/usr/bin/env lua
--[===========================================================================[

  Prints Provisioning (POSIX shell) script for "paisa-workhorse" to stdout.

  Intended to be used with "http://devuan.org/".

  lua -W "${pathToThisFile:?}" | dos2unix | ssh "${vm:?}" -t 'cat > /var/tmp/setup && cp /var/tmp/setup /tmp/setup'

  [isa kube/config](https://gitit.post.ch/projects/ISA/repos/wsl-playbooks/raw/roles/isa/files/kube/config?at=refs%2Fheads%2Fmaster)
  [Some other kube/config](https://artifactory.tools.post.ch/artifactory/generic-kubernetes-local/EKS/Int/eks-int-m01cn0001/config)

  [How to run kubectl Commands in my Namespace](https://wikit.post.ch/x/kIeTZg)

  KEEP! MIT DEM GEHTS! (vo mattiphil 2024-12-19:
  (https://artifactory.tools.post.ch/artifactory/generic-kubernetes-local/EKS/Int/eks-int-m15cn0001/config)

  [übersicht, namespaces, etc](https://deployment-eks-int-m15cn0001.eks.aws.pnetcloud.ch/applications?view=list&showFavorites=false&proj=&sync=&autoSync=&health=&namespace=&cluster=&labels=)

  ]===========================================================================]
-- Customize your install here ------------------------------------------------

local yourPhysicalHostname = "w00o2z"
local proxy_url = "http://10.0.2.2:3128/"
local proxy_no  = "localhost,pnet.ch,post.ch,tools.post.ch,gitit.post.ch,pnetcloud.ch,eu-central-1.eks.amazonaws.com,"..assert(yourPhysicalHostname)

-- Features
local redisHouston  = { setup = true ,  enable = true ,  port = 6389, pass = "isarulez", }
local redisEagle    = { setup = true ,  enable = true ,  port = 6399, pass = false, }
local redisVolatile = { setup = true ,  enable = false,  port = 6379, pass = false, }

local cmdSudo = "sudo"
local kubectlVersion = "1.31"
local kubeloginVersion = "0.1.6"
local argocdVersion = "2.11.7"
local getaddrinfoVersion = "0.0.2"
local cacheDir = "/var/tmp"
local kubeConfigFile = "eks-int-m15cn0001"
local kubeConfigUrl = "https://artifactory.tools.post.ch/artifactory/generic-kubernetes-local/EKS/Int/eks-int-m15cn0001/config"
local ceeMiscLibVersion = false -- "0.0.5-330-g2b037a5"

-- EndOf Customization --------------------------------------------------------

local main
local __FILE__, __DIR__ = arg[0], (arg[0]:gsub("^(.+)[/\\][^/\\]+$", "%1"))


-- [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/wrap.lua)
-- Very primitive, but works. So who cares, please write it yourself..
function wrap99( str )
    str = str
        :gsub("(...................................................................................................)", "%1\n")
        :gsub("\n$", "")
    if str:byte(str:len()) ~= 0x10 then str = str.."\n" end
    return str
end


-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/fileAsB64Gz.lua)
function fileAsB64Gz( filePath, dst )
    local f = io.popen("cat \"".. filePath .."\" | gzip | base64 -w99")  assert(f)
    local buf = f:read("a")
    f:close();
    assert(buf ~= "H4sIAAAAAAAAAwMAAAAAAAAAAAA=\n", "see stderr for details")
    dst:write(buf)
end


-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/base64.lua)
function b64enc( src )
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((src:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#src%3+1])
end


function writeVariables( dst )
    dst:write([=[
  && SUDO=']=].. cmdSudo ..[=[' \
  && ARCH=x86_64-linux-gnu \
  && fuckCerts=--insecure \
  && proxy_url="]=].. proxy_url ..[=[" \
  && proxy_no="]=].. proxy_no ..[=[" \
  && cacheDir=']=].. cacheDir ..[=[' \
  && repoDir="${cacheDir:?}/repo" \
  && argocdVersion=]=].. argocdVersion ..[=[ \
  && getaddrinfoVersion=]=].. getaddrinfoVersion ..[=[ \
  && kubeloginVersion=]=].. kubeloginVersion ..[=[ \
  && kubeConfigUrl=']=].. kubeConfigUrl ..[=[' \
  && kubeConfigFile=']=].. kubeConfigFile ..[=[' \
]=])
    if ceeMiscLibVersion then dst:write([=[
  && ceeMiscLibVersion=]=].. (ceeMiscLibVersion or"") ..[=[ \
  && ceeMiscLibUrl="http://hiddenalpha.ch/assets/dloads/CeeMiscLib-${ceeMiscLibVersion:?}+${ARCH:?}.tgz" \
  && ceeMiscLibLocal="$(basename "${ceeMiscLibUrl:?}")" \
]=])end
end


function writeGenericShellFuncs( dst )
    dst:write([=[
  && dloadIfMissing () { true \
      && dst="${1:?}" \
      && uri="${2:?}" \
      && if test -e "${dst:?}" ;then true \
          && printf 'EEXISTS: Skip dload: %s\n' "${dst:?}" \
        ;else true \
          && printf 'Dload  "%s"  (%s)\n' "${dst:?}" "${uri:?}" \
          && curl -Lo "${dst:?}" "${uri:?}" \
        ;fi \
  } \
  && dloadInsecureIfMissing () { true \
      && dst="${1:?}" \
      && uri="${2:?}" \
      && if test -e "${dst:?}" ;then true \
          && printf 'EEXISTS: Skip dload: %s\n' "${dst:?}" \
        ;else true \
          && printf 'Dload  "%s"  (%s)\n' "${dst:?}" "${uri:?}" \
          && curl --insecure -Lo "${dst:?}" "${uri:?}" \
        ;fi \
  } \
  && aptUpdateForce () { true \
      && $SUDO apt update \
      && touch "/tmp/w14AAE0xAACLfAAA" \
    ;} \
  && aptUpdateMaybe () { true \
      && now="$(date +%s)" \
      && old="$(date +%s -r "/tmp/w14AAE0xAACLfAAA" || echo 0)" \
      && if test "$((now - old))" -gt "$((7*3600))" ;then true \
          && aptUpdateForce \
        ;else true \
          && echo apt cache looks fresh enough \
        ;fi \
    ;} \
]=])
end


function writeProxySettings( dst )
    dst:write([=[
  && `# Proxy settings ` \
  && printf %s\\n \
        "export no_proxy=${proxy_no?}" \
        "export https_proxy=${proxy_url:?}" \
        "export http_proxy=${proxy_url:?}" \
        "export NO_PROXY=${proxy_no?}" \
        "export HTTPS_PROXY=${proxy_url:?}" \
        "export HTTP_PROXY=${proxy_url:?}" \
     | $SUDO tee -a /etc/environment >/dev/null \
  && export "no_proxy=${proxy_no?}" \
  && export "https_proxy=${proxy_url:?}" \
  && export "http_proxy=${proxy_url:?}" \
  && export "NO_PROXY=${proxy_no?}" \
  && export "HTTPS_PROXY=${proxy_url:?}" \
  && export "HTTP_PROXY=${proxy_url:?}" \
  && if test ! -e /etc/apt/apt.conf.d/80proxy ;then true \
      && printf %s\\n \
            'Acquire::http::proxy "'"${proxy_url:?}"'";' \
            'Acquire::https::proxy "'"${proxy_url:?}"'";' \
         | $SUDO tee -a /etc/apt/apt.conf.d/80proxy > /dev/null \
    ;fi \
]=])
end


function writeSwapSetup( dst )
    dst:write([=[
  && `# Add some swap ` \
  && SWAP_MIB=$((12*1024)) `# aka 12GiB ` \
  && $SUDO dd if=/dev/zero of=/swapfile1 bs=$((1024*1024)) count="${SWAP_MIB:?}" \
  && $SUDO chmod 0600 /swapfile1 \
  && $SUDO mkswap /swapfile1 \
  && printf '/swapfile1  none  swap  sw,nofail,user  0  0\n' | $SUDO tee -a /etc/fstab > /dev/null \
]=])
end


function writeAptConfigUglyWorkarounds( dst )
    dst:write([=[
  && printf %s\\n \
       '// FUCK those annoying TLS intercepting proxies!' \
       'Acquire::https::Verify-Peer "false";' \
       'Acquire::https::Verify-Host "false";' \
     | $SUDO tee -a /etc/apt/apt.conf.d/80fixnonsense > /dev/null \
]=])
end


function writePkgInstallation( dst )
    local pkgs = { ["net-tools"]=1, ["vim"]=1, ["curl"]=1, ["nfs-common"]=1, ["htop"]=1,
        ["ncat"]=1, ["git"]=1, ["ca-certificates"]=1, ["tmux"]=1, ["awscli"]=1,
        ["openjdk-17-jdk-headless"]=1, ["maven"]=1, ["podman"]=1, ["bash-completion"]=1,
        ["lua5.4"]=1, ["trash-cli"]=1, }
    if redisHouston.setup or redisEagle.setup or redisVolatile.setup then
        pkgs["redis-server"] = 1
        pkgs["redis-tools"] = 1
    end
    dst:write([=[
  && `# Install packages ` \
  && aptUpdateMaybe \
  && $SUDO RUNLEVEL=1 apt install -y --no-install-recommends \
       ]=])
    local lineLen, pkgsList, alreadyAdded = 7, {}, {}
    for k, v in pairs(pkgs) do table.insert(pkgsList, k) end
    table.sort(pkgsList)
    for _, pkgName in ipairs(pkgsList) do
        if alreadyAdded[pkgName] then goto nextPkg end
        alreadyAdded[pkgName] = true
        lineLen = lineLen + pkgName:len() + 1
        if lineLen >= 78 then dst:write(" \\\n       ") lineLen = 6 + pkgName:len() + 1 end
        dst:write(" ".. pkgName)
        ::nextPkg::
    end
    dst:write(" \\\n")
end


function writeHiddenalphaToolsInstallation( dst )
    -- download
    dst:write([=[
  && `# Install custom tools` \
]=])
    if ceeMiscLibVersion then dst:write([=[
  && dloadIfMissing "${repoDir:?}/${ceeMiscLibLocal:?}" "${ceeMiscLibUrl:?}" \
  && if test "$(cd "${repoDir:?}" && grep -i "${ceeMiscLibVersion:?}" "${cacheDir:?}"/SHA256SUM | sha256sum --ignore-missing -c - |grep -E ' OK$'|wc -l)" -ne 1 ;then true \
      && printf 'ERROR: CeeMiscLib download checksum mismatch\n' && false \
    ;fi \
]=])end if getaddrinfoVersion then dst:write([=[
  && dloadInsecureIfMissing "${repoDir:?}/getaddrinfo-${getaddrinfoVersion:?}+${ARCH:?}.tgz" "https://github.com/hiddenalpha/getaddrinfo-cli/releases/download/v${getaddrinfoVersion:?}/getaddrinfo-${getaddrinfoVersion:?}+${ARCH:?}.tgz" \
  && if test "$(cd "${repoDir:?}" && grep "getaddrinfo-.*${getaddrinfoVersion:?}" "${cacheDir:?}/MD5SUM" | md5sum --ignore-missing -c - |grep -E ' OK$'|wc -l)" -ne 1 ;then true \
      && printf 'ERROR: getaddrinfo download checksum mismatch\n' && false \
    ;fi \
]=])end
    -- install
    if getaddrinfoVersion then dst:write([=[
  && $SUDO mkdir -p "/opt/getaddrinfo-${getaddrinfoVersion:?}" \
  && (cd /opt/getaddrinfo-${getaddrinfoVersion:?} && $SUDO tar xf "${repoDir:?}/getaddrinfo-${getaddrinfoVersion:?}+${ARCH:?}.tgz") \
  && mkdir -p ~/.local/bin \
  && ln -s "/opt/getaddrinfo-${getaddrinfoVersion:?}/bin/getaddrinfo" ~/.local/bin/getaddrinfo \
]=])end if ceeMiscLibVersion then dst:write([=[
  && $SUDO mkdir -p "/opt/CeeMiscLib-${ceeMiscLibVersion}" \
  && (cd "/opt/CeeMiscLib-${ceeMiscLibVersion:?}" && $SUDO tar xf "${repoDir:?}/${ceeMiscLibLocal:?}") \
  && mkdir -p ~/.local/bin \
  && (cd ~/.local/bin \
      && for E in /opt/CeeMiscLib-"${ceeMiscLibVersion:?}"/bin/* ;do true \
          && ln -s "$E" \
        ;done) \
]=])end
end


function writeRedisSetup( dst ) --{
    if not redisHouston.setup and not redisEagle.setup and not redisVolatile.setup then
        return
    end
    dst:write([=[
  && `# Disable default redis-server ` \
  && ($SUDO service redis-server stop || true) \
  && ($SUDO update-rc.d redis-server remove || true) \
  && $SUDO mkdir -p /etc/redis \
  && `# Create redis-houston.conf ` \
  && <<EOF base64 -d |
]=])
    dst:write(wrap99(b64enc([=[
# 
# redis-server config adapted for PaISA Houston.
# 
bind 0.0.0.0
port ]=].. redisHouston.port .."\n"..[=[
protected-mode no
tcp-backlog 511
timeout 0
tcp-keepalive 0
daemonize yes
pidfile /run/redis/houston/redis-houston.pid
loglevel notice
logfile /var/log/redis/redis-houston.log
databases 16
always-show-logo no
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
save ""
dbfilename dump.rdb
rdb-del-sync-files no
dir /var/lib/redis/houston
appendonly yes
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync no
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 10
auto-aof-rewrite-min-size 1024mb
slowlog-log-slower-than 10000
slowlog-max-len 128
notify-keyspace-events ""
set-max-intset-entries 512
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
]=].. (redisHouston.pass and "requirepass ".. redisHouston.pass.."\n"or"") ..[=[
lua-time-limit 5000
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-entries 512
list-max-ziplist-value 64
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
shutdown-on-sigint "now force"
shutdown-on-sigterm "now force"
    ]=])))
    dst:write([=[
EOF
    $SUDO tee /etc/redis/redis-houston.conf >/dev/null \
  && if $SUDO test ! -s /etc/redis/redis-houston.conf ;then false ;fi \
  && `# Create redis-eagle.conf ` \
  && <<EOF base64 -d |
]=])
    dst:write(wrap99(b64enc([=[
# 
# redis-server config adapted for PaISA Eagle.
# 
bind 0.0.0.0
port ]=].. redisEagle.port .."\n"..[=[
protected-mode no
tcp-backlog 511
timeout 0
tcp-keepalive 0
daemonize yes
pidfile /run/redis/eagle/redis-eagle.pid
loglevel notice
logfile /var/log/redis/redis-eagle.log
databases 16
always-show-logo no
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
stop-writes-on-bgsave-error yes
save ""
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
rdb-del-sync-files no
dir /var/lib/redis/eagle
appendonly yes
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync no
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 10
auto-aof-rewrite-min-size 1024mb
slowlog-log-slower-than 10000
slowlog-max-len 128
notify-keyspace-events ""
set-max-intset-entries 512
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
]=].. (redisEagle.pass and("requirepass ".. redisEagle.pass .."\n")or"") ..[=[
lua-time-limit 5000
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-entries 512
list-max-ziplist-value 64
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
]=])))
    dst:write([=[
EOF
    $SUDO tee /etc/redis/redis-eagle.conf >/dev/null \
  && if $SUDO test ! -s /etc/redis/redis-eagle.conf ;then false ;fi \
  && `# Create redis-volatile.conf ` \
  && <<EOF base64 -d |
]=])
    dst:write(wrap99(b64enc([=[
# 
# redis-server config adapted for PaISA Eagle.
# 
bind 0.0.0.0
port ]=].. redisVolatile.port ..[=[
protected-mode no
tcp-backlog 511
timeout 0
tcp-keepalive 0
daemonize yes
pidfile /run/redis/volatile/redis-volatile.pid
loglevel notice
logfile /var/log/redis/redis-volatile.log
databases 16
always-show-logo no
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
stop-writes-on-bgsave-error yes
dir /var/lib/redis/eagle
save ""
appendonly no
slowlog-log-slower-than 10000
slowlog-max-len 128
notify-keyspace-events ""
set-max-intset-entries 512
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
]=].. (redisVolatile.pass and "requirepass "..redisVolatile.pass.."\n"or"") ..[=[
lua-time-limit 5000
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-entries 512
list-max-ziplist-value 64
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
]=])))
    dst:write([=[
EOF
    $SUDO tee /etc/redis/redis-volatile.conf >/dev/null \
  && if $SUDO test ! -s /etc/redis/redis-volatile.conf ;then false ;fi \
  && `# Configure logging ` \
  && <<EOF base64 -d | $SUDO tee /etc/logrotate.d/redis-houston >/dev/null &&
]=])
    dst:write(wrap99(b64enc([=[
/var/log/redis/redis-houston*.log {
        weekly
        missingok
        rotate 4
        compress
        notifempty
        delaycompress
}
]=])))
    dst:write([=[
EOF
true \
  && <<EOF base64 -d | $SUDO tee /etc/logrotate.d/redis-eagle >/dev/null &&
]=])
    dst:write(wrap99(b64enc([=[
/var/log/redis/redis-eagle*.log {
        weekly
        missingok
        rotate 4
        compress
        notifempty
        delaycompress
}
]=])))
    dst:write([=[
EOF
true \
  && <<EOF base64 -d | $SUDO tee /etc/logrotate.d/redis-volatile >/dev/null &&
]=])
    dst:write(wrap99(b64enc([=[
/var/log/redis/redis-volatile*.log {
        weekly
        missingok
        rotate 4
        compress
        notifempty
        delaycompress
}
]=])))
    dst:write([=[
EOF
true \
  && `# Register redis-houston service ` \
  && <<EOF_uQAAAOgdAABpQAAA base64 -d|gzip -d|$SUDO tee /etc/init.d/redis-houston >/dev/null &&
]=])
    fileAsB64Gz(__DIR__.."/redis-houston.initd", dst)
    dst:write([=[
EOF_uQAAAOgdAABpQAAA
true \
  && `# Register redis-eagle service ` \
  && <<EOF base64 -d|gzip -d|$SUDO tee /etc/init.d/redis-eagle >/dev/null &&
]=])
    fileAsB64Gz(__DIR__.."/redis-eagle.initd", dst)
    dst:write([=[
EOF
true \
  && `# Register redis-volatile service ` \
  && <<EOF base64 -d | gzip -d | $SUDO tee /etc/init.d/redis-volatile >/dev/null &&
]=])
    fileAsB64Gz(__DIR__.."/redis-volatile.initd", dst)
    dst:write([=[
EOF
true \
  && `# Tune file permissions, etc ` \
  && $SUDO chmod 755 /etc/init.d/redis-houston /etc/init.d/redis-eagle /etc/init.d/redis-volatile \
  && $SUDO mkdir -p /var/lib/redis/houston /var/lib/redis/eagle /var/lib/redis/volatile \
  && $SUDO chown redis:redis /var/lib/redis/houston /var/lib/redis/eagle /var/lib/redis/volatile \
]=])
    dst:write((redisHouston.enable)
        and("  && $SUDO update-rc.d redis-houston defaults \\\n")
        or ("  && $SUDO update-rc.d redis-houston remove \\\n"))
    dst:write((redisEagle.enable)
        and("  && $SUDO update-rc.d redis-eagle defaults \\\n")
        or ("  && $SUDO update-rc.d redis-eagle remove \\\n"))
    dst:write((redisVolatile.enable)
        and("  && $SUDO update-rc.d redis-volatile defaults \\\n")
        or ("  && $SUDO update-rc.d redis-volatile remove \\\n"))
end --}


function writeAliases( dst ) --{
    dst:write([=[
  && <<EOF_lTMAAGs7AA | base64 -d >> "/home/${USER:?}/.bashrc" &&
]=])
    dst:write(wrap99(b64enc([=[
alias     kubeprod='kubectl --context=eks-prod-m15cp0001 -n isa-houston-prod'
alias  kubepreprod='kubectl --context=eks-prod-m15cp0001 -n isa-houston-preprod'
alias      kubeint='kubectl --context=eks-int-m15cn0001  -n isa-houston-int'
alias     kubetest='kubectl --context=eks-int-m15cn0001  -n isa-houston-test'
alias kubesnapshot='kubectl --context=eks-int-m15cn0001  -n isa-houston-snapshot'
]=])))
    dst:write([=[
EOF_lTMAAGs7AA
true \
]=])
end --}


function writeKubectlAptConfig( dst ) --{
    dst:write([=[
  && `# In "theory", kubectl (via kubernetes-client) would be available via` \
  && `# proper system packaging tools. But like most break-it-all-the-` \
  && `# time-bullshit-software, also kubectl needs to be workarounded...` \
  && `# GRRRR... Fu** this shitty non-pkg managed shit software!` \
  && aptUpdateMaybe && $SUDO apt install --no-install-recommends -y gpg \
  && `# EndOf GRRRR` \
  && curl -fL ${fuckCerts?} https://pkgs.k8s.io/core:/stable:/v]=].. kubectlVersion ..[=[/deb/Release.key \
     | gpg --batch --dearmor | $SUDO tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null \
  && if $SUDO test ! -s /etc/apt/keyrings/kubernetes-apt-keyring.gpg ;then echo ERR_hUAAAARMAADwAgAA && false ;fi \
  && $SUDO chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
  && printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v]=].. kubectlVersion ..[=[/deb/ /\n' \
     | $SUDO tee /etc/apt/sources.list.d/kubernetes.list >/dev/null \
  && $SUDO chmod 644 /etc/apt/sources.list.d/kubernetes.list \
  && aptUpdateForce \
]=])
end --}


function writeAwsToolsInstallation( dst )
    dst:write--[[install argocd]]([=[
  && `# Install AWS related tools ` \
  && dloadInsecureIfMissing "${repoDir:?}/argocd-${argocdVersion:?}+linux-amd64" "https://github.com/argoproj/argo-cd/releases/download/v${argocdVersion:?}/argocd-linux-amd64" \
  && $SUDO mkdir -p "/opt/argocd-${argocdVersion:?}/bin" \
  && (cd /opt/argocd-${argocdVersion:?}/bin && $SUDO cp "${repoDir:?}/argocd-${argocdVersion:?}+linux-amd64" .) \
  && $SUDO chmod 0655 "/opt/argocd-${argocdVersion:?}/bin/argocd-${argocdVersion:?}+linux-amd64" \
  && mkdir -p ~/.local/bin \
  && (cd ~/.local/bin && ln -s /opt/argocd-${argocdVersion:?}/bin/argocd-${argocdVersion:?}+linux-amd64 argocd) \
]=])dst:write--[[install kubelogin]]([=[
  && kubeloginUrl="https://github.com/Azure/kubelogin/releases/download/v${kubeloginVersion:?}/kubelogin-linux-amd64.zip" \
  && printf %s\\n "Dload '${kubeloginUrl:?}'" \
  && rspCode=$(cd "${repoDir:?}" && curl -L --insecure -O -w '%{http_code}\n' "${kubeloginUrl:?}") \
  && if test "${rspCode?}" -ne "200" ;then true \
      && printf "kubelogin dload failed:\n%s\n" "${rspCode?}" && false \
    ;fi \
  && if test "$(cd "${repoDir:?}" && sha256sum --ignore-missing -c "${cacheDir:?}"/SHA256SUM |grep -E ' OK$'|wc -l)" -ne 1 ;then true \
      && printf 'ERROR: kubelogin download checksum mismatch\n' && false \
    ;fi \
  && $SUDO mkdir -p /opt/kubelogin-"${kubeloginVersion:?}/bin" /tmp/fuckstupidpackaging \
  && (cd /tmp/fuckstupidpackaging && $SUDO rm -rf * && $SUDO unzip "${repoDir:?}/kubelogin-*.zip") \
  && $SUDO mv "$(ls -d /tmp/fuckstupidpackaging/bin/*/kubelogin)" /opt/kubelogin-"${kubeloginVersion:?}/bin/." \
  && $SUDO chown root:root /opt/kubelogin-"${kubeloginVersion:?}"/bin/kubelogin \
  && $SUDO chmod 655 /opt/kubelogin-"${kubeloginVersion:?}"/bin/kubelogin \
  && mkdir -p ~/.local/bin \
  && ln -s /opt/kubelogin-"${kubeloginVersion:?}"/bin/kubelogin ~/.local/bin/. \
]=])dst:write--[[config]]([=[
  && mkdir "/home/${USER:?}/.kube" \
  && printf %s\\n "Dload '${kubeConfigUrl:?}'" \
  && rspCode=$(curl -sSL -o /home/${USER:?}/.kube/"${kubeConfigFile:?}" -w '%{http_code}\n' "${kubeConfigUrl:?}") \
  && if test "${rspCode?}" -ne "200" ;then true \
      && printf "kube/config dload failed:\n%s\n" "${rspCode?}" && false \
    ;fi \
  && if test -e "/home/${USER:?}/.kube/config" ;then true \
      && mv /home/${USER:?}/.kube/config /home/${USER:?}/.kube/config-$(date +%s).old \
    ;fi \
  && cp /home/${USER:?}/.kube/"${kubeConfigFile:?}" /home/${USER:?}/.kube/config \
]=])
end


function writeHostShareSetup( dst )
    dst:write([=[
  && $SUDO mkdir -p /c && $SUDO ln -s /mnt/cdrive/work /c/work \
  && $SUDO mkdir /mnt/cdrive \
  && (printf '/mnt/cdrive/work  /c/work  none  noauto,bind,user  0  0\n') | $SUDO tee -a /etc/fstab >/dev/null \
  && (printf '//10.0.2.2:/c  /mnt/cdrive  nfs  noauto,vers=3,user  0  0\n') | $SUDO tee -a /etc/fstab >/dev/null \
]=])
end


function writeKnownHashes( dst )
    dst:write([=[
  && `# Known hashes ` \
  && mkdir -p "${cacheDir:?}" "${repoDir:?}" \
  && printf %s\\n \
       'e990013d2d658dd19ef2731bc9387d4ed88c60097d5364ac2d832871f2fc17d5 *kubelogin-linux-amd64.zip' \
       'ca47b335ee7433eca7d839ece328498944427b4f83f99de919ea26e8d7f07ee4 *CeeMiscLib-0.0.5-306-g99d785d+aarch64-linux-gnu.tgz' \
       'ec1077009965ee1c4681a043a74803ef96185590421af02b6ae8d877a793cf9d *CeeMiscLib-0.0.5-306-g99d785d+x86_64-linux-gnu.tgz' \
       '2d070cb39e06098373387984ef8d56635cded6e6bad4c8f8b36e9320b3a60511 *CeeMiscLib-0.0.5-306-g99d785d+x86_64-w64-mingw32.tgz' \
       '88f4143fd7d9579846e2294f1c87fc78f43264d8f0d4149e68c2367bcba44a86 *CeeMiscLib-0.0.5-330-g2b037a5+x86_64-linux-gnu.tgz' \
       '65fd69b505f2a62e741f15aa49ce64e4a58e9a8b6918308890de7da60f5be953 *CeeMiscLib-0.0.5-330-g2b037a5+x86_64-w64-mingw32.tgz' \
       '2085ada7dcbd7feaeefe40aa81ef6e0893e4944160f9db88e5fd159b26566a76 *CeeMiscLib-0.0.5-330-g2b037a5+aarch64-linux-gnu.tgz' \
     | $SUDO tee "${cacheDir:?}"/SHA256SUM > /dev/null \
  && printf %s\\n \
       'b97fbffbebfe73e6e75371bdbc032a4f *getaddrinfo-0.0.2+x86_64-linux-gnu.tgz' \
       '200e49e0046b42f35f6dfc12d7ad93fc *getaddrinfo-0.0.2+x86_64-w64-mingw32.tgz' \
       '6981e10f59385fe974ebd0c8e7432516 *getaddrinfo-0.0.2+x86_64-alpine-linux-musl.tgz' \
       'c6c789fc990b8aa18dbb8800b8417d06 *getaddrinfo-0.0.2+aarch64-linux-gnu.tgz' \
     | $SUDO tee "${cacheDir:?}"/MD5SUM > /dev/null \
]=])
end


function writeEmbeddedReadme( dst )
    dst:write("  && <<EOF base64 -d | gzip -d | tee /home/${USER:?}/README.txt &&\n")
    fileAsB64Gz(__DIR__.."/inline-readme.txt", dst)
    dst:write("EOF\ntrue \\\n")
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\ntrue \\\n")
    writeVariables(dst)
    writeGenericShellFuncs(dst)
    writeKnownHashes(dst)
    writeProxySettings(dst)
    writeAptConfigUglyWorkarounds(dst)
    writeKubectlAptConfig(dst)
    writePkgInstallation(dst)
    writeSwapSetup(dst)
    writeAwsToolsInstallation(dst)
    writeHiddenalphaToolsInstallation(dst)
    writeRedisSetup(dst)
    writeAliases(dst)
    --writeHostShareSetup(dst)
    dst:write([=[
  && printf 'export PATH="%s/.local/bin:$PATH"\n' ~ >> ~/.bashrc \
  && export PATH="/home/${USER?}/.local/bin:$PATH" \
  && printf 'export MAVEN_OPTS="--add-opens jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.desktop/java.awt.font=ALL-UNNAMED"\n' | $SUDO tee -a /etc/environment > /dev/null \
]=])
    writeEmbeddedReadme(dst)
    dst:write("  && printf '\\n  DONE. Setup completed.\\n\\n' \\\n\n")
end


main()

