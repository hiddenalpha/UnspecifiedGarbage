
# Some tinkering about how I could do backup.
#
# Inspired by:
#   https://linuxconfig.org/how-to-create-incremental-backups-using-rsync-on-linux
#
# mount /dev/sdx1 /mnt/x
#

set -o errexit
set -o pipefail

readonly NOW_SHORT="$(date -u '+%Y%m%d-%H%M%S')"
readonly DIR_FROM="/home/${USER:?}/."
readonly DST_PREFIX="${DIR_FROM:?}"
readonly DIR_TO="/mnt/x/ROOT_DIR/bkup-rsync/tux-six"
readonly BACKUP_PATH="${DIR_TO}/${NOW_SHORT}"
readonly LATEST_LINK="${DIR_TO}/latest"


printHelp () {
    printf "\n\
  TODO write help page\n\
  \n";
}


parseArgs () {
    local arg0="$0"
    local isExample="false"
    while [ $# -gt 0 ]; do
        local arg="$1"
        if false; then
            true
        elif [ "$arg" == "--help" ]; then
            printHelp; return 1
        elif [ "$arg" == "--example" ]; then
            isExample="true";
        else
            echo "Unexpected arg: $arg"; return 1
        fi
        shift 1
    done
    if ! $isExample; then echo >&2 "Bad args"; return 1; fi
    return 0
}


run () {
    if [ ! -e "${DIR_TO:?}" ]; then
        echo >&2 "Backup root dir does not exist. Abort."
        return 1
    fi
    mkdir -p "${BACKUP_PATH:?}/${DST_PREFIX:?}"
    rsync --archive --verbose \
        --link-dest "${LATEST_LINK:?}/${DST_PREFIX:?}" \
        --filter=':- .gitignore' \
        --exclude=".git/COMMIT_EDITMSG" \
        --exclude=".git/FETCH_HEAD" \
        --exclude=".git/ORIG_HEAD" \
        --exclude=".git/branches" \
        --exclude=".git/hooks/*.sample" \
        --exclude=".git/index" \
        --exclude=".git/info" \
        --exclude=".git/logs" \
        --exclude=".git/objects" \
        --exclude=".git/packed-refs" \
        --exclude=".git/refs/remotes" \
        --exclude=".git/refs/tags" \
        --exclude=".idea" \
        --exclude="/.NERDTreeBookmarks" \
        --exclude="/.Xauthority" \
        --exclude="/.bash_history" \
        --exclude="/.config/VirtualBox/HostInterfaceNetworking-vboxnet0-Dhcpd.leases*" \
        --exclude="/.config/VirtualBox/HostInterfaceNetworking-vboxnet0-Dhcpd.log*" \
        --exclude="/.config/VirtualBox/VBoxSVC.log*" \
        --exclude="/.config/VirtualBox/compreg.dat" \
        --exclude="/.config/VirtualBox/selectorwindow.log*" \
        --exclude="/.config/VirtualBox/vbox-ssl-cacertificate.crt" \
        --exclude="/.config/VirtualBox/xpti.dat" \
        --exclude="/.config/libreoffice" \
        --exclude="/.config/GIMP" \
        --exclude="/.config/JetBrains" \
        --exclude="/.gdb_history" \
        --exclude="/.lesshst" \
        --exclude="/.profile" \
        --exclude="/.vimrc" \
        --exclude="/.xsession-errors" \
        --exclude="/.xsession-errors.old" \
        --exclude="/mnt" \
        --exclude="/.android" \
        --exclude="/.cache" \
        --exclude="/.config/chromium" \
        --exclude="/.config/inkscape" \
        --exclude="/.local/share" \
        --exclude="/.m2/repository" \
        --exclude="/.mozilla/firefox" \
        --exclude="/.squirrel-sql" \
        --exclude="/.viking-maps" \
        --exclude="/Downloads" \
        --exclude="/crashdumps" \
        --exclude="/images" \
        --exclude="/projects/apple/cups" \
        --exclude="/projects/gnu" \
        --exclude="/projects/lua" \
        --exclude="/projects/misc/OpenSSL" \
        --exclude="/projects/misc/OpenVPN" \
        --exclude="/projects/misc/busybox" \
        --exclude="/projects/misc/cgit" \
        --exclude="/projects/misc/dash" \
        --exclude="/projects/misc/endlessh" \
        --exclude="/projects/misc/jssc" \
        --exclude="/projects/misc/libqrencode" \
        --exclude="/projects/misc/mbedtls" \
        --exclude="/projects/misc/openbox" \
        --exclude="cee-misc-lib/external" \
        --exclude="cee-misc-lib/tmp" \
        --exclude="/tmp" \
        --exclude="/virtualbox-*" \
        --exclude="/vmshare" \
        "${DIR_FROM:?}" \
        "${BACKUP_PATH:?}/${DST_PREFIX}" \
        ;
    rm "${LATEST_LINK}"
    ln --symbolic "${BACKUP_PATH}" "${LATEST_LINK}"
}


main () {
    parseArgs "$@"
    if [ $? -ne 0 ]; then exit 2; fi
    run
}


main "$@"
