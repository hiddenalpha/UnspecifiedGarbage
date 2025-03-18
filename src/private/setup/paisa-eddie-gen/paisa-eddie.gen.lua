#!/usr/bin/env lua
--[===========================================================================[

  Prints a (POSIX shell) setup script to stdout.

  Sets up a RHEL9 Eddie VM.

  WARN: Setup script will assign uid 1000 to user "isa"!

  TODO:

      "/etc/selinux/config":
      - SELINUX=enforcing
      + SELINUX=permissive
      dann reboot

  ]===========================================================================]
-- Customize your setup here: -------------------------------------------------

local env_PROXY_URL = "http://10.0.2.2:3128/"
local env_PROXY_NO  = "127.0.0.1,localhost,10.0.2.2,10.0.2.15"
local env_PAISA_ENV = "test"
local guestHostname = "veddie42"
-- keys on fedora/RHEL MUST be at least 3072 bits.
local isaSshPubKey = nil

-- EndOf Customizations -------------------------------------------------------



-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/base64.lua)
function b64enc( src ) local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
return((src:gsub('.',function(x)local r,b='',x:byte()for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and'1'
or'0') end return r;end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(x)if #x< 6 then return''end
local c=0 for i=1,6 do c=c+(x:sub(i,i)=='1'and 2^(6-i)or 0)end return b:sub(c+1,c+1)end)..({'','=='
,'='})[#src%3+1])end



function write_setupPodmanNetworks( dst )
    -- [docker networking](https://gitit.post.ch/projects/ISA/repos/wowbagger-puppetconfig/browse/site/profile/templates/container-networking-setup.sh.erb)
    dst:write([=[
  && $SUDO podman network create \
         --driver=bridge \
         --subnet=192.168.198.0/25 \
]=])
    -- Hmm? Real eddies seem to have that. But looks not needed somehow?
    --   --opt com.docker.network.driver.mtu=<%= @mtu %>
    --   --opt com.docker.network.bridge.enable_icc=true
    --   --opt com.docker.network.bridge.enable_ip_masquerade=false
    --   --opt com.docker.network.bridge.host_binding_ipv4=0.0.0.0
    dst:write([=[
         --opt "com.docker.network.bridge.name=isa-docker" \
         isa-docker \
  && $SUDO podman network create \
         --driver=macvlan \
         --subnet=192.168.10.0/24 \
         --gateway=192.168.10.1 \
         --ip-range=192.168.10.8/29 \
         --opt parent=ens3 \
         isa-vehicle \
]=])
end


-- Grrrr...
-- www is full of useless shit-advice how to do housekeeping with podman.
-- The only way I found so far, is to just WIPE EVERYTHING. Unluckily,
-- 'everything' includes 'networks' too. So now we need yet another kludge
-- script which allows us to restore our machine occasionly, without
-- wasting time with all this www-bullshit-advice everytime we've a disk
-- space emergency.
function write_saveMyAssPodmanReset( dst )
    local absPath = "/home/isa/.local/bin/podman-force-wipe"
    dst:write([=[
  && $SUDO sh -c 'cd /home/isa && mkdir -p .local/bin && chown '"${isaUid:?}:${isaGid:?}"' .local .local/bin' \
  && <<EOF_oAlBwAA base64 -d | $SUDO tee ]=].. absPath ..[=[ > /dev/null &&
]=])
    local buf = "#!/bin/sh\n# Grrrrr... Why cannot just this tool do its job by itself?\nset -e \\\n"
        ..'  && SUDO=$(if test "$(id -u)" -ne 0 ;then echo sudo ;fi) \\\n'
        .."  && $SUDO podman system prune -a -f \\\n"
    write_setupPodmanNetworks{write=function(t,b)buf=buf..b end}
    dst:write(b64enc(buf) .."\n")
    dst:write([=[
EOF_oAlBwAA
true \
  && $SUDO chmod u+x ]=].. absPath ..[=[ \
]=])
end


function main()
    local dst = io.stdout
    assert(not(isaSshPubKey:find("'")))
    dst:write([=[
#!/bin/sh
# Required min disk space is 24GiB NOPE, 16GiB is not enough, because PaISA
# is include-all-the-framebloat software. Also, to start PaISA, at LEAST 10GiB
# of RAM are required. See also:
# - "https://devrant.com/rants/5107044"
# - "https://medium.com/dinahmoe/escape-dependency-hell-b289de537403"
set -e \
  && SUDO=sudo \
  && PROXY_URL=']=].. env_PROXY_URL ..[=[' \
  && PROXY_NO=']=].. env_PROXY_NO ..[=[' \
  && isaUid=1000 \
  && isaGid=1000 \
  && appGid=990 \
  && if test -n "${PROXY_URL?}" ;then true \
      && printf 'proxy=%s\n' "${PROXY_URL:?}" \
          | $SUDO tee -a /etc/dnf/dnf.conf >/dev/null \
     ;fi \
  && `# Würgaround: dnf --setopt=sslverify=false ` \
  && `# Grrr.... Yet another würgaround: dnf --setopt=zchunk=false ` \
  && $SUDO dnf install -y openssh-server podman nmap-ncat tcpdump \
  && $SUDO dnf remove -y firewalld \
  && $SUDO systemctl enable sshd \
  && $SUDO systemctl start sshd \
  && `# timezone ` \
  && $SUDO ln -f /usr/share/zoneinfo/Europe/Zurich /etc/localtime \
  && printf %s\\n \
       "export PAISA_ENV=]=].. env_PAISA_ENV ..[=[" \
     | $SUDO tee -a /etc/profile >/dev/null \
  && if test -n "${PROXY_URL?}"; then true \
      && printf %s\\n \
           "export http_proxy=\"${PROXY_URL:?}\"" \
           "export https_proxy=\"${PROXY_URL:?}\"" \
           "export no_proxy=\"${PROXY_NO?}\"" \
           "export HTTP_PROXY=\"${PROXY_URL:?}\"" \
           "export HTTPS_PROXY=\"${PROXY_URL:?}\"" \
           "export NO_PROXY=\"${PROXY_NO?}\"" \
         | $SUDO tee -a /etc/profile >/dev/null \
     ;fi \
  && $SUDO mkdir -p /home/isa \
  && $SUDO chown ${isaUid:?}:${appGid:?} /home/isa \
  && $SUDO mkdir -p /data/instances \
  && $SUDO mkdir -p /mnt/data/fenchurch \
  && $SUDO chown root:${appGid:?} /mnt/data/fenchurch \
  && $SUDO chmod 775 /mnt/data/fenchurch \
  && $SUDO chgrp ${appGid:?} /data/instances \
  && $SUDO chmod 775 /data/instances \
  && <<EOF_q34huq398 cat > /home/isa/.bashrc &&

export PS1='[$? \u@\h \W]\\$ '

EOF_q34huq398
true \
  && cp /etc/skel/.bash_profile /home/isa/. \
  && $SUDO mkdir -p /home/isa/.ssh \
  && printf %s\\n ']=].. isaSshPubKey ..[=[' | $SUDO tee -a /home/isa/.ssh/authorized_keys >/dev/null \
  && $SUDO find /home/isa -exec chown ${isaUid:?}:${isaGid:?} {} + \
  && $SUDO find /home/isa/.ssh -type d -exec chmod 700 {} + \
  && $SUDO find /home/isa/.ssh -type f -exec chmod 600 {} + \
  && `# Inject some inline documentation ` \
  && mkdir /home/isa/doc \
  && printf %s\\n \
         '' \
         '  ## Additional packages, helpful for some debugging scenarios' \
         '' \
         '  && $SUDO dnf install -y java-11-openjdk-devel.x86_64' \
         '  && $SUDO dnf install -y nss-mdns avahi avahi-tools' \
         '' \
         '  ## Podman cleanup (handy for disk space issues)' \
         '' \
         '  sudo podman image prune --all --build-cache --external' \
         '  sudo podman volume prune' \
         '  `# vv-- WARN WIPES EVERYTHING, (including networks!) `' \
         '  $SUDO podman system prune -a -f' \
         '' \
     | $SUDO tee /home/isa/doc/README.txt >/dev/null \
  && $SUDO chown ${isaUid:?}:${isaGid:?} /home/isa/doc /home/isa/doc/README.txt \
]=])
    write_setupPodmanNetworks(dst)
    write_saveMyAssPodmanReset(dst)
    dst:write([=[
  && `# Force-replace isa related users/groups. ` \
  && $SUDO cp /etc/sudoers /etc/sudoers-$(date -u +%Y%m%d-%H%M%S).bk \
  && $SUDO sed -i -E 's/^(%wheel\s+ALL=\(ALL\)\s+)(ALL\s*)$/\1NOPASSWD:\2/' /etc/sudoers \
  && <<EOF $SUDO sh - &&
true `# WARN danger zone zere!` \
  && cat /etc/passwd \
     | grep -v -E '^isa:' \
     | grep -v -E '^[^:]*:[^:]*:'${isaUid:?}':' \
     | tee /etc/passwd-9D8AAONcAADpbAAA >/dev/null \
  && cat /etc/group \
     | grep -v -E '^app:' \
     | grep -v -E '^[^:]*:[^:]*:'${appGid:?}':' \
     | tee /etc/group-Y2MAAOIIAABeCQAA >/dev/null \
  && printf "isa:x:${isaUid:?}:${isaGid:?}:isa:/home/isa:/bin/bash\n" | tee -a /etc/passwd-9D8AAONcAADpbAAA >/dev/null \
  && printf "isa:x:${isaUid:?}:\n" | tee -a /etc/group-Y2MAAOIIAABeCQAA >/dev/null \
  && cat /etc/group-Y2MAAOIIAABeCQAA \
     | sed -E 's/^(wheel:.*:)$/\1isa/' | sed -E 's/^(wheel:.*[^:])$/\1,isa/' \
     | tee /etc/group-PQcAAEApAABzQwAA >/dev/null \
  && rm /etc/group-Y2MAAOIIAABeCQAA \
  && printf '%s\n' \
       "app:x:${appGid:?}:isa" \
     | tee -a /etc/group-PQcAAEApAABzQwAA >/dev/null \
  && cat /etc/group-PQcAAEApAABzQwAA > /etc/group \
  && cat /etc/passwd-9D8AAONcAADpbAAA > /etc/passwd \
  && echo 'isa:12345' | chpasswd \
  && hostnamectl set-hostname "]=].. guestHostname ..[=[" \
  && true
EOF
true \
  && $SUDO sed -i -E 's_^SELINUX=enforcing$_SELINUX=permissive_g' /etc/selinux/config \
  && cat /home/isa/README.txt \
  && printf '\n  DONE :)\n\n' \
]=])
end


main()

