#!/usr/bin/env lua
--[===========================================================================[

  Prints for gateleen a provisioning (POSIX shell) script to stdout.

  TODO: Move 'Example Run' into generated README.
  TODO: Test if this works.
  TODO: use devuan in place of alpine.

  ]===========================================================================]

local main


function aptInstall( dst )
	dst:write([=[
  && `# wurgh... what a terrible hack! Unbelievable that there is no proper ` \
  && `# way to do this. The days of clean software are counted! From now on,` \
  && `# it will only become worse day by day.` \
  && $SUDO dpkg-divert --add --rename /sbin/start-stop-daemon \
  && $SUDO ln -fs /bin/true /sbin/start-stop-daemon \
  && $SUDO RUNLEVEL=1 apt install --no-install-recommends -y \
       curl maven nodejs npm redis openjdk-17-jre-headless \
  && $SUDO rm /sbin/start-stop-daemon \
  && $SUDO dpkg-divert --remove --rename /sbin/start-stop-daemon \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e \\\n")
    dst:write([=[
  && SUDO=sudo \
  && gateleenGitTag="v2.1.23" \
  && workDir="${PWD:?}" \
  && cacheDir="/var/tmp" \
  \
]=])
	aptInstall(dst)
    dst:write([=[
  \
  && curl -sSL https://github.com/swisspush/gateleen/archive/refs/tags/"${gateleenGitTag:?}".tar.gz > "${cacheDir:?}/gateleen-${gateleenGitTag:?}.tgz" \
  && `# Corporation specific setup ` \
  && `# TODO Configure proxy ` \
  && `# TODO Configure "/home/user/.npmrc" ` \
  && `# TODO Configure "/home/user/.m2/settings.xml" ` \
  && `# Make ` \
  && mkdir -p "${workDir:?}/gateleen" \
  && cd       "${workDir:?}/gateleen" \
  && tar --strip-components 1 -xf "${cacheDir:?}/gateleen-${gateleenGitTag:?}.tgz" \
  && (cd gateleen-hook-js && npm install) \
  && mkdir -p gateleen-hook-js/node/node_modules/npm/bin \
  && ln -s /usr/bin/node gateleen-hook-js/node/node \
  && printf "require('/usr/share/nodejs/npm/lib/cli.js')\n" | tee gateleen-hook-js/node/node_modules/npm/bin/npm-cli.js >/dev/null \
  && mvn install -PpublicRepos -DskipTests -Dskip.installnodenpm -pl gateleen-hook-js \
  && mvn verify -PpublicRepos -DfailIfNoTests=false -pl '!gateleen-test,!gateleen-hook-js' \
      '-Dtest=!HookHandlerTest,!ReleaseLockLuaScriptTests,!RedisCacheStorageTest,!QueueCircuitBreakerCloseCircuitLuaScriptTests,!QueueCircuitBreakerUpdateStatsLuaScriptTests,!QueueCircuitBreakerReOpenCircuitLuaScriptTests,!QueueCircuitBreakerGetAllCircuitsLuaScriptTests,!QueueCircuitBreakerHalfOpenCircuitsLuaScriptTests,!RemoveExpiredQueuesLuaScriptTests,!StartQueueTimerLuaScriptTests' \
  && mkdir "${workDir:?}/classpath" \
  && (cd gateleen-playground && mvn dependency:copy-dependencies \
      -DexcludeScope=provided -DoutputDirectory="${workDir:?}/classpath/.") \
  && cp gateleen-playground/target/gateleen-playground-*.jar "${workDir:?}/classpath/." \
  && mkdir -p "${workDir:?}/etc" "${workDir:?}/var/lib/redis" \
  && printf >"${workDir:?}/etc/redis.conf" '%s\n' \
      'save ""' \
      'appendonly yes' \
      'appendfilename appendonly.aof' \
  && `# Squeeze those funny "static files" into redis` \
  && (cd "${workDir:?}/var/lib/redis" && redis-server "${workDir:?}/etc/redis.conf" \
      & java -cp "${workDir:?}/classpath/"'*' org.swisspush.gateleen.playground.Server \
      & sleep 3 \
     ) \
  && (cd "${workDir:?}/gateleen" && mvn deploy -PuploadStaticFiles) \
  && (pkill -INT java || sleep 3 && pkill -TERM java || sleep 3 && pkill -9 java) \
  && $SUDO pkill -INT redis-server \
  && $SUDO apt clean \
  && sleep 1 \
  && cd "${workDir:?}/gateleen" \
  && mvn clean \
  && cd "${workDir:?}" \
  && cat <<EOF_C9x5sSZd3ro74O3m|tee README >/dev/null &&

  An example run:

  && ip a | grep inet \\
  && (true \\
     && (cd "${workDir:?}/var/lib/redis" && redis-server "${workDir:?}/etc/redis.conf") \\
        & true \\
     && cd "${workDir:?}" \\
     && java -cp "${workDir:?}/classpath/"'*' org.swisspush.gateleen.playground.Server \\
     ) \\

EOF_C9x5sSZd3ro74O3m
true \
  && printf '\n  DONE\n\n' \
]=])
end


main()
