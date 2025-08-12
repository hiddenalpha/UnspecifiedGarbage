#!/bin/sh
#
# Source:
# http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/shell/common/nextFreeGroupId.sh
#

set -e \
  && nextFreeGroupId () { true \
      && i=1 \
      && while true ;do true \
          && exists="$(grep -E '^[^:]+:[^:]+:'"${i:?}"':' /etc/group || true)" \
          && if test -z "${exists?}" ;then break ;fi \
          && i="$((i + 1))" \
        ;done \
      && echo "${i:?}" \
    ;} \

nextFreeGroupId

