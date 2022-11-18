#
# Tools for Android development.
#

ARG PARENT_IMAGE=debian:buster-20220622-slim
FROM $PARENT_IMAGE

ARG PKGS_TO_ADD="curl unzip openjdk-11-jdk-headless aapt apksigner zipalign"
ARG PKGS_TO_DEL="curl unzip"
ARG PKGINIT="apt-get update"
ARG PKGADD="apt-get install -y --no-install-recommends"
ARG PKGDEL="apt-get purge -y"
ARG PKGCLEAN="apt-get clean"
ARG PLATFORM_VERSION="22"
ARG BUILD_TOOLS_VERSION="22.0.1"
ARG CMDLINETOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip"

ENV ANDROID_HOME="/usr/lib/android-sdk"
ENV PATH="$PATH:/usr/lib/android-sdk/build-tools/debian:/usr/lib/android-sdk/cmdline-tools/latest/bin:/usr/lib/android-sdk/build-tools/$BUILD_TOOLS_VERSION"

WORKDIR /work

RUN true \
    && $PKGINIT \
    && $PKGADD $PKGS_TO_ADD \
    && (cd /tmp && curl -sSLO "$CMDLINETOOLS_URL") \
    && if test -x /tmp/cmdline-tools; then echo >&2 "[ERROR] /tmp/cmdline-tools already exists"; false; fi \
    && (cd /tmp && unzip $(basename "$CMDLINETOOLS_URL") >/dev/null) \
    && mkdir /usr/lib/android-sdk/cmdline-tools \
    && mkdir /usr/lib/android-sdk/cmdline-tools/latest \
    && mv /tmp/cmdline-tools/* /usr/lib/android-sdk/cmdline-tools/latest/. \
    && yes | sdkmanager --install "platforms;android-$PLATFORM_VERSION" "build-tools;$BUILD_TOOLS_VERSION" \
    # Those for some reason are broken (wrong linker) so use the debian variant.
    && (cd "/usr/lib/android-sdk/build-tools/${BUILD_TOOLS_VERSION:?}" && rm aapt zipalign) \
    && chown 1000:1000 /work \
    && $PKGDEL $PKGS_TO_DEL \
    && $PKGCLEAN \
    && rm -rf /tmp/* \
    && true

USER 1000:1000

CMD ["sleep", "36000"]

