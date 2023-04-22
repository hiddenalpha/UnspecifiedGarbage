# 
# A Gateleen playground instance.
# 

ARG PARENT_IMAGE=alpine:3.16.0
FROM $PARENT_IMAGE

ARG GATELEEN_GIT_TAG=v1.3.28
ARG UID=1000
ARG GID=1000
ARG PKGS_TO_ADD="maven nodejs npm curl redis openjdk11-jre-headless"
#ARG PKGS_TO_DEL="maven nodejs npm"
ARG PKGS_TO_DEL="nodejs npm"
ARG PKGINIT="true"
ARG PKGADD="apk add"
ARG PKGDEL="true"
ARG PKGCLEAN="true"

WORKDIR /work

RUN true \
    && printf 'user:x:%s:%s:user:/work:/bin/sh\n' "${UID:?}" "${GID:?}" >> /etc/passwd \
    && true

RUN true \
    && $PKGINIT && $PKGADD $PKGS_TO_ADD \
    && sed -i "s,</settings>,  <localRepository>/data/maven/.m2/repository</localRepository>\n</settings>,g" /usr/share/java/maven-3/conf/settings.xml \
    && mkdir /data /data/maven /work/gateleen \
    && chown "${UID:?}:${GID:?}" /data/maven /work /work/gateleen \
    && curl -sSL https://github.com/swisspush/gateleen/archive/refs/tags/"$GATELEEN_GIT_TAG".tar.gz > "/tmp/gateleen-$GATELEEN_GIT_TAG.tgz" \
    && cd /work/gateleen \
    && su user -c 'tar --strip-components 1 -xf /tmp/gateleen-"$GATELEEN_GIT_TAG".tgz' \
    && (cd gateleen-hook-js && su user -c 'npm install') \
    && su user -c 'mkdir -p gateleen-hook-js/node/node_modules/npm/bin' \
    && su user -c 'ln -s /usr/bin/node gateleen-hook-js/node/node' \
    && printf "require('/usr/lib/node_modules/npm/lib/cli.js')\n" | su user -c 'tee gateleen-hook-js/node/node_modules/npm/bin/npm-cli.js' >/dev/null \
    && su user -c 'mvn install -PpublicRepos -DskipTests -Dskip.installnodenpm -pl gateleen-hook-js' \
    && su user -c 'mvn install -PpublicRepos -DfailIfNoTests=false \
        -pl !gateleen-test,!gateleen-hook-js \
        -Dtest=!ReleaseLockLuaScriptTests,!RedisCacheStorageTest,!DeltaHandlerTest,!QueueCircuitBreakerCloseCircuitLuaScriptTests,!QueueCircuitBreakerGetAllCircuitsLuaScriptTests,!QueueCircuitBreakerHalfOpenCircuitsLuaScriptTests,!QueueCircuitBreakerReOpenCircuitLuaScriptTests,!QueueCircuitBreakerUpdateStatsLuaScriptTests,!RemoveExpiredQueuesLuaScriptTests,!StartQueueTimerLuaScriptTests' \
    && mkdir /work/classpath \
    && chown "${UID:?}:${GID:?}" /work/classpath \
    && su user -c 'cd gateleen-playground && mvn dependency:copy-dependencies \
        -DexcludeScope=provided -DoutputDirectory=/work/classpath/.' \
    && cp gateleen-playground/target/gateleen-playground-*.jar /work/classpath/. \
    && mkdir /work/etc \
    && printf >/work/etc/redis.conf '%s\n' \
        'save ""' \
        'appendonly yes' \
        'appenddirname "redis-state"' \
        'appendfilename appendonly.aof' \
    && (su user -c 'cd /work && redis-server /work/etc/redis.conf & \
        java -cp '"'/work/classpath/*'"' org.swisspush.gateleen.playground.Server' \
        &  sleep 3) \
    && su user -c 'cd /work/gateleen && mvn deploy -PuploadStaticFiles' \
    && pkill -INT java && pkill -INT redis-server \
    && $PKGDEL $PKGS_TO_DEL \
    && $PKGCLEAN \
    && true

USER "${UID}:${GID}"

#CMD ["sleep", "36000"]
CMD ["sh", "-c", "ip a|grep inet && redis-server /work/etc/redis.conf & java -cp '/work/classpath/*' org.swisspush.gateleen.playground.Server"]

