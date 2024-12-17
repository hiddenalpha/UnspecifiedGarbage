#!/usr/bin/env lua
--[===========================================================================[

  Prints a (POSIX shell) setup script to stdout.

  Sets up a RHEL9 Eddie VM.

  WARN: Setup script will assign uid 1000 to user "isa"!

  ]===========================================================================]
-- Customize your setup here: -------------------------------------------------

local env_PROXY_URL = "http://10.0.2.2:3128/"
local env_PROXY_NO  = "127.0.0.1,10.0.2.*"
local isaSshPubKey = nil

-- EndOf Customizations -------------------------------------------------------

local main


function main()
    local dst = io.stdout
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
  && $SUDO dnf install -y openssh-server podman \
  && $SUDO dnf remove -y firewalld \
  && $SUDO systemctl enable sshd \
  && $SUDO systemctl start sshd \
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
  && $SUDO chgrp ${appGid:?} /data/instances \
  && $SUDO chmod 775 /data/instances \
  && mkdir -p /home/isa/.ssh \
  && printf %s ']=].. isaSshPubKey ..[=[' >> /home/isa/.ssh/authorized_keys \
  && `# Inject some inlien documentation ` \
  && printf %s\\n \
         '' \
         '## Additional packages, helpful for some debugging scenarios' \
         '' \
         '  && $SUDO dnf install -y java-11-openjdk-devel.x86_64' \
         '  && $SUDO dnf install -y nss-mdns avahi avahi-tools' \
         '  && printf "\n  DONE :)\n\n"' \
         '' \
     | $SUDO tee /home/isa/README.txt >/dev/null \
  && $SUDO chown ${isaUid:?}:${isaGid:?} /home/isa/README.txt \
  && `# Force-replace isa related users/groups. ` \
  && <<EOF $SUDO sh - &&
true \
  `# && cat /etc/passwd ` \
  `#    | grep -v -E '^isa:' ` \
  `#    | grep -v -E '^[^:]*:[^:]*:'${isaUid:?}':' ` \
  `#    | tee /etc/passwd-9D8AAONcAADpbAAA >/dev/null ` \
  `# && cat /etc/group ` \
  `#    | grep -v -E '^app:' ` \
  `#    | grep -v -E '^[^:]*:[^:]*:'${appGid:?}':' ` \
  `#    | tee /etc/group-Y2MAAOIIAABeCQAA >/dev/null ` \
  `# && mv /etc/group-Y2MAAOIIAABeCQAA /etc/passwd ` \
  && printf "isa:x:${isaUid:?}:${isaGid:?}:isa:/home/isa:/bin/bash\n" | tee -a /etc/passwd >/dev/null \
  && printf "isa:x:${isaUid:?}:\n" | tee -a /etc/group >/dev/null \
  && cat /etc/group \
     | sed -E 's/^(wheel:.*:)$/\1isa/' | sed -E 's/^(wheel:.*[^:])$/\1,isa/' \
     | tee /etc/group-PQcAAEApAABzQwAA >/dev/null \
  && mv /etc/group-PQcAAEApAABzQwAA /etc/group \
  && printf %s\\n \
       "app:x:${appGid:?}:isa" \
     | tee -a /etc/group >/dev/null \
  && true
EOF
true \
  && cat /home/isa/README.txt \
  && printf '\n  DONE :)\n\n' \
]=])
end


main()

