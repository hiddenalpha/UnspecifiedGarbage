#!/usr/bin/env lua
--[===========================================================================[

  Prints a (POSIX shell) setup script to stdout.

  Sets up a RHEL9 Eddie VM.

  WARN: Setup script will assign uid 1000 to user "isa"!

  ]===========================================================================]
-- Customize your setup here: -------------------------------------------------

local env_PROXY_URL = "http://10.0.2.2:31280/" --"http://10.0.2.2:3128/"
local env_PROXY_NO  = "127.0.0.1,10.0.2.*"

-- EndOf Customizations -------------------------------------------------------

local main


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\n")
    dst:write([=[true \
  && SUDO=sudo \
  && PROXY_URL=']=].. env_PROXY_URL ..[=[' \
  && PROXY_NO=']=].. env_PROXY_NO ..[=[' \
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
  && `# Force-replace isa related users/groups. ` \
  && $SUDO cat /etc/passwd \
     | grep -v -E '^isa:' \
     | grep -v -E '^[^:]*:[^:]*:1000:' \
     | $SUDO tee /etc/passwd-9D8AAONcAADpbAAA >/dev/null \
  && $SUDO mv /etc/passwd-9D8AAONcAADpbAAA /etc/passwd \
  && printf 'isa:x:1000:1000:isa:/home/isa:/bin/bash\n' | $SUDO tee -a /etc/passwd >/dev/null \
  && printf 'isa:x:1000:\n' | $SUDO tee -a /etc/group >/dev/null \
  && printf 'app:x:990:isa\n' | $SUDO tee -a /etc/group >/dev/null \
  && `# ` \
  && $SUDO mkdir -p /home/isa \
  && $SUDO chown isa:app /home/isa \
  && $SUDO mkdir -p /data/instances \
  && $SUDO chgrp app /data/instances \
  && $SUDO chmod 775 /data/instances \
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
  && $SUDO chown isa:isa /home/isa/README.txt \
  && printf '\n  DONE :)\n\n' \
]=])
end


main()

