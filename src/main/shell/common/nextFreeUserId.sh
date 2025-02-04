#!/bin/sh

set -e \
  && nextFreeUserId () { true \
      && i=1 \
      && while true ;do true \
          && exists="$(grep -E '^[^:]+:[^:]+:'"${i:?}"':' /etc/passwd || true)" \
          && if test -z "${exists?}" ;then break ;fi \
          && i="$((i + 1))" \
        ;done \
      && echo "${i:?}" \
    ;} \

nextFreeUserId

