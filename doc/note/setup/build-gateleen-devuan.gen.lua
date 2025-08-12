#!/usr/bin/env lua
--[===========================================================================[

  Prints for gateleen a provisioning (POSIX shell) script to stdout.

  WARN: RestStorage used in gateleen-2.1.23 seems broken (thats why the
  patch got introduced)

  ]===========================================================================]

local gateleenVersion="2.1.23"


function aptInstall( dst )
	dst:write([=[
  && `# wurgh... what a terrible hack! Unbelievable that there is no proper ` \
  && `# way to do this. The days of clean software are counted! From now on,` \
  && `# it will only become worse day by day.` \
  && $SUDO dpkg-divert --add --rename /sbin/start-stop-daemon \
  && $SUDO ln -fs /bin/true /sbin/start-stop-daemon \
  && $SUDO RUNLEVEL=1 apt install --no-install-recommends -y \
       curl maven nodejs npm redis openjdk-17-jre-headless patch \
  && $SUDO rm /sbin/start-stop-daemon \
  && $SUDO dpkg-divert --remove --rename /sbin/start-stop-daemon \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e \\\n")
    dst:write([=[
  && SUDO=sudo \
  && gateleenGitTag="v]=].. gateleenVersion ..[=[" \
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
  && base64 -d <<EOF_xMV8eqhxI64v4aB3|$SUDO tee "${workDir:?}/fixstuff.patch" >/dev/null &&
LS0tIHBvbS54bWwJdjIuMS4yMworKysgcG9tLnhtbApAQCAtNzksOCArNzksOCBAQAogICAgICAgICA8
bW9kLW1ldHJpY3MudmVyc2lvbj4zLjAuMDwvbW9kLW1ldHJpY3MudmVyc2lvbj4KICAgICAgICAgPG5l
dHdvcmtudC52ZXJzaW9uPjAuMS4xNTwvbmV0d29ya250LnZlcnNpb24+CiAgICAgICAgIDxyZXN0LWFz
c3VyZWQudmVyc2lvbj40LjQuMDwvcmVzdC1hc3N1cmVkLnZlcnNpb24+Ci0gICAgICAgIDxyZWRpc3F1
ZXMudmVyc2lvbj4zLjEuMDwvcmVkaXNxdWVzLnZlcnNpb24+Ci0gICAgICAgIDxyZXN0LXN0b3JhZ2Uu
dmVyc2lvbj4zLjEuMTwvcmVzdC1zdG9yYWdlLnZlcnNpb24+CisgICAgICAgIDxyZWRpc3F1ZXMudmVy
c2lvbj40LjEuMTQ8L3JlZGlzcXVlcy52ZXJzaW9uPgorICAgICAgICA8cmVzdC1zdG9yYWdlLnZlcnNp
b24+My4xLjk8L3Jlc3Qtc3RvcmFnZS52ZXJzaW9uPgogICAgICAgICA8c3ByaW5nZnJhbWV3b3JrLnZl
cnNpb24+NS4zLjI3PC9zcHJpbmdmcmFtZXdvcmsudmVyc2lvbj4KICAgICAgICAgPHNsZjRqLnZlcnNp
b24+Mi4wLjEwPC9zbGY0ai52ZXJzaW9uPgogICAgICAgICA8cXVhcnR6LnZlcnNpb24+Mi4zLjI8L3F1
YXJ0ei52ZXJzaW9uPgo=
EOF_xMV8eqhxI64v4aB3
true \
  && patch < ../fixstuff.patch \
  && mvn install -PpublicRepos -DskipTests -Dskip.installnodenpm -pl gateleen-hook-js \
  && mvn verify -PpublicRepos -DfailIfNoTests=false -pl '!gateleen-test,!gateleen-hook-js' \
      '-Dtest=!DeltaHandlerTest,!HookHandlerTest,!QueueCircuitBreakerCloseCircuitLuaScriptTests,!QueueCircuitBreakerGetAllCircuitsLuaScriptTests,!QueueCircuitBreakerHalfOpenCircuitsLuaScriptTests,!QueueCircuitBreakerReOpenCircuitLuaScriptTests,!QueueCircuitBreakerUpdateStatsLuaScriptTests,!RedisCacheStorageTest,!ReleaseLockLuaScriptTests,!RemoveExpiredQueuesLuaScriptTests,!StartQueueTimerLuaScriptTests' \
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
