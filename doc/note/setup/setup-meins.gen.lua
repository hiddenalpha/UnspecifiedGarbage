#!/usr/bin/env lua
--[===========================================================================[

  Usual machine setup.

  TODO: INSTALL PRINTER PACKAGES!!

  TODO: Document how to install certbot.

  ## Base system

  Install base system through devuan ISO installers. Usually net installer is
  fine.

  Do NOT install ANY additional bloat! Eg untick ALL extra software like
  desktops etc. Even disable the standard-system-utilities option.

  ]===========================================================================]

-- groups to install:
local wifiUi = true
local webServer = true
local mdnsClient = true
local cups = true
local preferIpv4 = true


function getPkgsToInstall()  --{
    local ret = {}
    for _, p in pairs{
        -- essential tools
        "vim", "net-tools", "openssh-server", "openssh-client", "bash-completion",
        --
        "iptables", "iptables-persistent",
        -- basic CLI
        "vim", "htop", "pv", "openssh-client", "iptables", "iptables-persistent", "xxd", "zip",
        "unzip", "xz-utils", "p7zip-full", "file", "trash-cli", "ncat", "curl", "ntp",
        -- keyboard
        "numlockx",
        -- Basic UI (vim-gtk required for system clipboard)
        "vim-gtk3", "firefox-esr", "pcmanfm", "file-roller", "thunderbird", "chromium", "okular",
        -- software devel
        "git", "sqlite3", "manpages-dev", "gdb", "qemu-utils", "qemu-system-x86",
        "qemu-system-arm", "wireshark", "samba", "tigervnc-viewer", "jq", "universal-ctags",
        "binutils", "adb",
    } do ret[p] = 1 end
    if wifiUi then
        ret["iwgtk"] = 1
    end
    if webServer then
        ret["nginx-light"] = 1
    end
    if mdns then
        ret["avahi-daemon"] = 1
        ret["libnss-mdns"] = 1
        ret["avahi-utils"] = 1
    end
    if media then
        for _, p in pairs{
            "pulseaudio", "pavucontrol", "vlc", "audacity", "eom", "darktable", "gimp", "hugin",
            "lame", "flac", "opus-tools", "ffmpeg", "alsa-utils",
        } do table.insert(ret, p, 1) end
    end
    for _, p in pairs{
        -- crypto
        "keepassxc", "gpg", "gocryptfs",
        -- UI customization
        "gnome-themes-extra", "darkmint-gtk-theme", "dconf-cli",
        -- Office Suite
        "libreoffice-writer", "libreoffice-calc", "libreoffice-draw", "libxrender1", "libgl1",
        "fonts-crosextra-caladea", "fonts-crosextra-carlito", "fonts-dejavu", "fonts-liberation",
        "fonts-liberation2", "fonts-linuxlibertine", "fonts-noto-core", "fonts-noto-mono",
        "fonts-noto-ui-core", "fonts-sil-gentium-basic", "pdftk-java",
        -- Cups Printing
        "cups", "avahi-daemon",
        -- Graphics processing
        "imagemagick", "dcraw",
        -- Low level
        "lm-sensors", "fancontrol", "exfat-fuse", "exfatprogs",
        -- dig, nslookup, nsupdate commands
        "bind9-dnsutils",
        -- Others
        "systemd-sysv", "bc", "rsync", "qrencode", "libxml2-utils", "adb",
        -- GPU
        -- WARN: do NOT use nvidia. See "../nvidia/FUCKTHISSHIT.txt"
        -- TODO: uninstall all other xserver-xorg-video-* pkgs
        "xserver-xorg-video-fbdev", "xserver-xorg-video-nouveau", "xserver-xorg-video-vesa",
        "glx-alternative-mesa", "libgl1-mesa-glx", "libgl1-mesa-dri", "mesa-utils", "libva2",
        "mesa-va-drivers", "libvdpau-va-gl1", "clinfo", "mesa-opencl-icd",
    } do ret[p] = 1 end
    return ret
end --}


function write_vars( dst ) --{
    dst:write([=[
  && SUDO=sudo \
]=])
end --}


function write_installPkgs( dst ) --{
    dst:write([=[
  && `# Install Pkgs ` \
  && now="$(date +%s)" \
  && old="$(date +%s -r "/tmp/l5t512UuA84WHCMC" || echo 0)" \
  && if test "$((now - old))" -gt "$((7*3600))" ;then true \
      && $SUDO apt update \
      && touch "/tmp/l5t512UuA84WHCMC" \
    ;else true \
      && echo Assume apt cache fresh enough \
    ;fi \
  && $SUDO apt install -y --no-install-recommends \
      ]=])
    for pkgNm, _ in pairs(getPkgsToInstall()) do
        dst:write(" ".. pkgNm)
    end
    dst:write(" \\\n")
end --}




function write_firewallCfg( dst ) --{
    dst:write([=[
  && `# Setup firewall`
  && `# WARN: This snippet may cut-off network connections. Including remote shell! ` \
  && echo "ERROR: firewall needs manual config" && false \
  && printf '# TODO add contents here\n' | $SUDO tee /etc/iptables/src-default >/dev/null \
  && printf '\n[WARN ] Needs more setup: /etc/iptables/src-default\n\n' \
  && printf '%s\n' \
       '## Apply from file' '' \
       'cat /etc/iptables/src-default | $SUDO iptables-restore' '' \
       '## store current session as default' '' \
       '$SUDO iptables-save | $SUDO tee /etc/iptables/rules.v4 > /dev/null' \
       | $SUDO tee /etc/iptables/README >/dev/null \
  && printf '# TODO setup file contents\n' | $SUDO tee /etc/iptables/src-default4 >/dev/null \
  && printf '%s\n' \
       '*filter' '' \
       '# Loopback' \
       '-A INPUT  -i lo -j ACCEPT' \
       '-A OUTPUT -o lo -j ACCEPT' '' \
       '# Log blocked connection attemps' \
       '-A INPUT   -j LOG --log-prefix "Fw6BadInn: " --log-level 6' \
       '-A FORWARD -j LOG --log-prefix "Fw6BadFwd: " --log-level 6' \
       '-A OUTPUT  -j LOG --log-prefix "Fw6BadOut: " --log-level 6' '' \
       '# Disallow any non-whitelisted packets' \
       '-A INPUT   -j DROP' \
       '-A FORWARD -j REJECT' \
       '-A OUTPUT  -j REJECT' '' \
       'COMMIT' | $SUDO tee /etc/iptables/src-default6 >/dev/null \
  && printf '%s\n' \
       '*filter' \
       '-A INPUT   -j ACCEPT' \
       '-A FORWARD -j ACCEPT' \
       '-A OUTPUT  -j ACCEPT' \
       'COMMIT' | $SUDO tee /etc/iptables/src-allowAll4 >/dev/null \
  && $SUDO touch /etc/iptables/src-tmp \
]=])
end --}


function write_installDesktop( dst ) --{
    dst:write([=[
  && `# Install Desktop Env ` \
  && $SUDO apt install --no-install-recommends -y \
       xorg openbox mate-terminal lightdm light-locker feh scrot lxpanel qalculate-gtk \
       gmrun gnome-system-monitor \
  && mkdir ~/.config ~/.config/openbox || true \
  && update-alternatives `# TODO needs args` \
  && echo 'TODO: Populate "/etc/environment" as described by "./etc-environment"' && false \
]=])
end --}


function write_cups( dst ) --{
    dst:write([=[
  && `# Cups Printing ` \
  && cat - /etc/cups/cupsd.conf <<EOF | $SUDO tee /tmp/iRl6YGXzcGZv0Yc26 >/dev/null &&
# Example "/etc/cups/cupsd.conf"
#
# [online doc](https://www.cups.org/doc/man-cupsd.conf.html)
#
ServerAdmin root@localhost
LogLevel warn
#
WebInterface Yes
Listen localhost:631
Listen /run/cups/cups.sock
ServerTokens None
#
DefaultPaperSize A4
MaxJobTime 1800
PreserveJobFiles 86400
DefaultShared Yes
#ServerName example.com
#DNSSDHostName example.com
FilterNice 8
EOF
true \
  && $SUDO mv /tmp/iRl6YGXzcGZv0Yc26 /etc/cups/cupsd.conf \
]=])
end --}


function main() --{
    local dst = io.stdout
    dst:write([=[
#!/bin/sh
set -e
]=])
    write_vars(dst)
    write_installPkgs(dst)
    write_firewallCfg(dst)
    dst:write([=[
  && `# Mount home partition ` \
  && cat <<EOF | tee -a /etc/fstab >/dev/null |
# TODO UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /mnt/nameOfHdd  ext4  noatime  0  2
# TODO /mnt/nameOfHdd/home  /home  none  bind  0  0
EOF
true \
  && echo TODO Configure Locale is a manual step: \
  && echo <<EOF
- In "/etc/locale.gen" Enable all of:
  "de_CH.UTF-8 UTF-8", "de_CH ISO-8859-1", "en_DK.UTF-8 UTF-8", "en_DK ISO-8859-1".
- Run "locale-gen".
- Check list with "locale -a".
- Change "/etc/default/locale" contents to:
    LANG=en_DK.UTF-8
    LANGUAGE="en_US:en"
EOF
true \
  && false ` ^^-- manual ` \
]=])
    if preferIpv4 then
        dst:write([=[
  && `# Prefer IPv4 over IPv6 ` \
  && $SUDO sed -i -E 's,^#?(precedence +::ffff:0:0/96 +)[0-9]+$,\1100,' /etc/gai.conf \
]=])
    end
    write_installDesktop(dst)
    if cups then write_cups(dst) end
end --}


main()
