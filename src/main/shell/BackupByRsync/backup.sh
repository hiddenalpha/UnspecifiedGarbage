
# Some tinkering about how I could do backup.
#
# Inspired by:
#   https://linuxconfig.org/how-to-create-incremental-backups-using-rsync-on-linux
#
# mount /dev/sdx1 /mnt/x
#

set -o errexit

readonly NOW_SHORT="$(date -u '+%Y%m%d-%H%M%S')"
readonly DIR_FROM="/home/${USER:?}/."
readonly DST_PREFIX="${DIR_FROM:?}"
#readonly DIR_TO="/mnt/x/ROOT_DIR/bkup-rsync/tux-six"
readonly BACKUP_PATH="${DIR_TO:?}/${NOW_SHORT:?}"


printHelp () {
    printf "\n\
  Sorry, no help page. Dig into source to see what happens\n\
  \n";
}


parseArgs () {
    local arg0="$0"
    local isYolo="false"
    while [ $# -gt 0 ]; do
        local arg="$1"
        if false; then
            true
        elif [ "$arg" = "--help" ]; then
            printHelp; return 1
        elif [ "$arg" = "--yolo" ]; then
            isYolo="true";
        else
            echo "Unexpected arg: $arg"; return 1
        fi
        shift 1
    done
    if ! $isYolo; then echo >&2 "Bad args"; return 1; fi
    return 0
}


run () {
    if [ ! -e "${DIR_TO:?}" ]; then
        echo >&2 "Backup root dir does not exist. Abort."
        return 1
    fi
    mkdir -p "${BACKUP_PATH:?}/${DST_PREFIX:?}"
    rsync --archive --verbose \
        --link-dest "${DIR_TO}/latest/${DST_PREFIX:?}" \
        --filter=':- .gitignore' \
        --exclude=".git/branches" \
        --exclude=".git/COMMIT_EDITMSG" \
        --exclude=".git/FETCH_HEAD" \
        --exclude=".git/hooks/*.sample" \
        --exclude=".git/index" \
        --exclude=".git/info" \
        --exclude=".git/logs" \
        --exclude=".git/objects" \
        --exclude=".git/ORIG_HEAD" \
        --exclude=".git/packed-refs" \
        --exclude=".git/refs/remotes" \
        --exclude=".git/refs/tags" \
        --exclude=".git/modules/*/COMMIT_EDITMSG" \
        --exclude=".git/modules/*/FETCH_HEAD" \
        --exclude=".git/modules/*/hooks/*.sample" \
        --exclude=".git/modules/*/logs" \
        --exclude=".git/modules/*/objects" \
        --exclude=".git/modules/*/refs/remotes" \
        --exclude=".git/modules/*/refs/tags" \
        --exclude=".idea" \
        --exclude="/.android" \
        --exclude="/.bash_history" \
        --exclude="/.cache" \
        --exclude="/.config/chromium" \
        --exclude="/.config/GIMP" \
        --exclude="/.config/inkscape" \
        --exclude="/.config/JetBrains" \
        --exclude="/.config/libreoffice" \
        --exclude="/.config/VirtualBox/compreg.dat" \
        --exclude="/.config/VirtualBox/HostInterfaceNetworking-vboxnet0-Dhcpd.leases*" \
        --exclude="/.config/VirtualBox/HostInterfaceNetworking-vboxnet0-Dhcpd.log*" \
        --exclude="/.config/VirtualBox/selectorwindow.log*" \
        --exclude="/.config/VirtualBox/vbox-ssl-cacertificate.crt" \
        --exclude="/.config/VirtualBox/VBoxSVC.log*" \
        --exclude="/.config/VirtualBox/xpti.dat" \
        --exclude="/.eclipse" \
        --exclude="/.gdb_history" \
        --exclude="/.git-credentials" \
        --exclude="/.gmrun_history" \
        --exclude="/.lesshst" \
        --exclude="/.local/share" \
        --exclude="/.local/srv" \
        --exclude="/.m2/repository" \
        --exclude="/mnt" \
        --exclude="/.mozilla/firefox" \
        `# TODO exclude either "/.mysave" or "/mysave" ` \
        --exclude="/.NERDTreeBookmarks" \
        --exclude="/.recently-used" \
        --exclude="/.recoll" \
        --exclude="/.sh_history" \
        --exclude="/.sqlite_history" \
        --exclude="/.squirrel-sql" \
        --exclude="/.viking-maps" \
        --exclude="/.viminfo" \
        --exclude="/.viminfo.tmp" \
        --exclude="/.Xauthority" \
        --exclude="/.xsession-errors" \
        --exclude="/.xsession-errors.old" \
        --exclude="/crashdumps" \
        --exclude="/Downloads" \
        --exclude="/images" \
        --exclude="/mnt" \
        --exclude="/post-läbi-migration-2025" `#TODO cleanup` \
        --exclude="/projects/forks" \
        --exclude="/tmp" \
        --exclude="/virtualbox-*" \
        --exclude="/VirtualBox VMs" \
        --exclude="/vm-qemu" \
        --exclude="/vm-share" \
        --exclude="/vmshare" \
        "${DIR_FROM:?}" \
        "${BACKUP_PATH:?}/${DST_PREFIX}" \
        ;
    (cd "${DIR_TO:?}" &&
        rm -f latest &&
        ln --symbolic "${NOW_SHORT:?}" latest
    )
}


main () {
    parseArgs "$@"
    if [ $? -ne 0 ]; then exit 2; fi
    run
}


main "$@"
