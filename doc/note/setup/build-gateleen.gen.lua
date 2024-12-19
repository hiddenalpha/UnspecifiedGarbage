#!/usr/bin/env lua
--[===========================================================================[

  Prints for gateleen a provisioning (POSIX shell) script to stdout.

  TODO: Move 'Example Run' into generated README.
  TODO: Test if this works.
  TODO: use devuan in place of alpine.

  ]===========================================================================]

local main


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e\n")
    dst:write([=[true \
  && PKGS_TO_ADD="curl maven nodejs npm redis openjdk11-jre-headless" \
  && SUDO="${HOME:?}/.local/bin/mysudo" \
  && PKGINIT=true \
  && PKGADD="$SUDO apk add" \
  && PKGCLEAN=true \
  && mkdir -p "${HOME:?}/.local/bin" \
  && printf '%s\n' '#!/bin/sh' 'printf "Sudo "' 'su root -c "$(echo "$@")"' > "${HOME:?}/.local/bin/mysudo" \
  && chmod u+x "${HOME:?}/.local/bin/mysudo" \
  \
  && `# Generic` \
  && GATELEEN_GIT_TAG="v1.3.28" \
  && WORKDIR="/${HOME:?}/work" \
  && CACHE_DIR="/var/tmp" \
  \
  && `# Setup Dependencies & get sources` \
  && ${PKGINIT:?} \
  && ${PKGADD:?} ${PKGS_TO_ADD?} \
  && curl -sSL https://github.com/swisspush/gateleen/archive/refs/tags/"${GATELEEN_GIT_TAG:?}".tar.gz > "${CACHE_DIR:?}/gateleen-${GATELEEN_GIT_TAG:?}.tgz" \
  && `# Corporation specific setup ` \
  && `# TODO Configure proxy ` \
  && `# TODO Configure "/home/user/.npmrc" ` \
  && `# TODO Configure "/home/user/.m2/settings.xml" ` \
  && `# Make ` \
  && mkdir -p "${WORKDIR:?}/gateleen" && cd "${WORKDIR:?}/gateleen" \
  && tar --strip-components 1 -xf "${CACHE_DIR:?}/gateleen-${GATELEEN_GIT_TAG:?}.tgz" \
  && (cd gateleen-hook-js && npm install) \
  && mkdir -p gateleen-hook-js/node/node_modules/npm/bin \
  && ln -s /usr/bin/node gateleen-hook-js/node/node \
  && printf "require('/usr/lib/node_modules/npm/lib/cli.js')\n" | tee gateleen-hook-js/node/node_modules/npm/bin/npm-cli.js >/dev/null \
  && mvn install -PpublicRepos -DskipTests -Dskip.installnodenpm -pl gateleen-hook-js \
  && mvn install -PpublicRepos -DfailIfNoTests=false \
      -pl '!gateleen-test,!gateleen-hook-js' \
      '-Dtest=!ReleaseLockLuaScriptTests,!RedisCacheStorageTest,!DeltaHandlerTest,!QueueCircuitBreakerCloseCircuitLuaScriptTests,!QueueCircuitBreakerGetAllCircuitsLuaScriptTests,!QueueCircuitBreakerHalfOpenCircuitsLuaScriptTests,!QueueCircuitBreakerReOpenCircuitLuaScriptTests,!QueueCircuitBreakerUpdateStatsLuaScriptTests,!RemoveExpiredQueuesLuaScriptTests,!StartQueueTimerLuaScriptTests' \
  && mkdir "${WORKDIR:?}/classpath" \
  && (cd gateleen-playground && mvn dependency:copy-dependencies \
      -DexcludeScope=provided -DoutputDirectory="${WORKDIR:?}/classpath/.") \
  && cp gateleen-playground/target/gateleen-playground-*.jar "${WORKDIR:?}/classpath/." \
  && mkdir "${WORKDIR:?}/etc" "${WORKDIR:?}/redis-state" \
  && printf >"${WORKDIR:?}/etc/redis.conf" '%s\n' \
      'save ""' \
      'appendonly yes' \
      'appendfilename appendonly.aof' \
  && `# Squeeze those funny "static files" into redis` \
  && (cd "${WORKDIR:?}/redis-state" && redis-server "${WORKDIR:?}/etc/redis.conf" \
      & java -cp "${WORKDIR:?}/classpath/"'*' org.swisspush.gateleen.playground.Server \
      & sleep 3 \
     ) \
  && (cd "${WORKDIR:?}/gateleen" && mvn deploy -PuploadStaticFiles) \
  && (pkill -INT java || sleep 3 && pkill -TERM java || sleep 3 && pkill -9 java) \
  && pkill -INT redis-server \
  && $PKGDEL $PKGS_TO_DEL \
  && $PKGCLEAN \
  && sleep 3 \
  && (cd "${WORKDIR:?}/gateleen" && mvn clean) \
  && printf '\n  DONE\n\n' \

## Example Run
true <<EOF

  && ip a | grep inet \
  && (true \
     && (cd "${WORKDIR:?}/redis-state" && redis-server "${WORKDIR:?}/etc/redis.conf") \
        & true \
     && cd ~ \
     && java -cp "${WORKDIR:?}/classpath/"'*' org.swisspush.gateleen.playground.Server \
     ) \

EOF
]=])
end


main()
