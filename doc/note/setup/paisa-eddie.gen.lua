#!/usr/bin/env lua
--[===========================================================================[

  Prints a (POSIX shell) setup script to stdout.

  Sets up a RHEL9 Eddie VM.

  WARN: Setup script will assign uid 1000 to user "isa"!

  ]===========================================================================]
-- Customize your setup here: -------------------------------------------------

local env_PROXY_URL = "http://10.0.2.2:3128/"
local env_PROXY_NO  = "127.0.0.1,localhost,10.0.2.2,10.0.2.15"
local env_PAISA_ENV = "test"
-- keys on fedora/RHEL MUST be at least 3072 bits.
local isaSshPubKey = nil

-- EndOf Customizations -------------------------------------------------------

local main


function main()
    local dst = io.stdout
    assert(not(isaSshPubKey:find("'")))
    dst:write("#!/bin/sh\nset -e\n")
    dst:write([=[true \
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
  && $SUDO chown root:app /mnt/data/fenchurch \
  && $SUDO chmod 775 /mnt/data/fenchurch \
  && $SUDO chgrp ${appGid:?} /data/instances \
  && $SUDO chmod 775 /data/instances \
  && mkdir -p /home/isa/.ssh \
  && printf %s\\n ']=].. isaSshPubKey ..[=[' >> /home/isa/.ssh/authorized_keys \
  && find /home/isa/.ssh $SUDO chown ${isaUid:?}:${isaGid:?} /home/isa/.ssh \
  && find /home/isa/.ssh -type d $SUDO chmod 700 /home/isa/.ssh \
  && find /home/isa/.ssh -type f $SUDO chmod 600 /home/isa/.ssh \
  && `# Inject some inlien documentation ` \
  && printf %s\\n \
         '' \
         '  TODO: setup *isa-docker* network' \
         '  TODO: setup *isa-vehicle* network' \
         '' \
         '  ## Additional packages, helpful for some debugging scenarios' \
         '' \
         '  && $SUDO dnf install -y java-11-openjdk-devel.x86_64' \
         '  && $SUDO dnf install -y nss-mdns avahi avahi-tools' \
         '' \
     | $SUDO tee /home/isa/README.txt >/dev/null \
  && $SUDO chown ${isaUid:?}:${isaGid:?} /home/isa/README.txt \
  && `# [docker networking](https://gitit.post.ch/projects/ISA/repos/wowbagger-puppetconfig/browse/site/profile/templates/container-networking-setup.sh.erb) ` \
  && $SUDO podman network create \
         --driver=bridge \
         --subnet=192.168.198.0/25 \
         `# --opt com.docker.network.driver.mtu=<%= @mtu %> ` \
         `# --opt com.docker.network.bridge.enable_icc=true ` \
         `# --opt com.docker.network.bridge.enable_ip_masquerade=false ` \
         `# --opt com.docker.network.bridge.host_binding_ipv4=0.0.0.0 ` \
         --opt "com.docker.network.bridge.name=isa-docker" \
         isa-docker \
  && $SUDO podman network create \
         --driver=macvlan \
         --subnet=192.168.10.0/24 \
         --gateway=192.168.10.1 \
         --ip-range=192.168.10.8/29 \
         --opt parent=ens3 \
         isa-vehicle \
  && `# Force-replace isa related users/groups. ` \
  && $SUDO sed -i -E 's/^(%wheel\s+ALL=\(ALL\)\s+)(ALL\s*)$/\1NOPASSWD:\2/' /etc/sudoers \
  && $SUDO mv /etc/sudoers-FBsAAJpmAAA5ewAA /etc/sudoers \
  && <<EOF $SUDO sh - &&
true \
  && cat /etc/passwd \
     | grep -v -E '^isa:' \
     | grep -v -E '^[^:]*:[^:]*:'${isaUid:?}':' \
     | tee /etc/passwd-9D8AAONcAADpbAAA >/dev/null \
  && cat /etc/group \
     | grep -v -E '^app:' \
     | grep -v -E '^[^:]*:[^:]*:'${appGid:?}':' \
     | tee /etc/group-Y2MAAOIIAABeCQAA >/dev/null \
  && mv /etc/group-Y2MAAOIIAABeCQAA /etc/passwd \
  && printf "isa:x:${isaUid:?}:${isaGid:?}:isa:/home/isa:/bin/bash\n" | tee -a /etc/passwd >/dev/null \
  && printf "isa:x:${isaUid:?}:\n" | tee -a /etc/group >/dev/null \
  && cat /etc/group \
     | sed -E 's/^(wheel:.*:)$/\1isa/' | sed -E 's/^(wheel:.*[^:])$/\1,isa/' \
     | tee /etc/group-PQcAAEApAABzQwAA >/dev/null \
  && mv /etc/group-PQcAAEApAABzQwAA /etc/group \
  && printf %s\\n \
       "app:x:${appGid:?}:isa" \
     | tee -a /etc/group >/dev/null \
  && echo 'isa:12345' | $SUDO chpasswd \
  && true
EOF
true \
  && cat /home/isa/README.txt \
  && printf '\n  DONE :)\n\n' \
]=])
end


main()

