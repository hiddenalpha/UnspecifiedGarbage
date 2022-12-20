#
# Maven build env.
#
# Use this to share your hosts repository with the container:
#
#   -v "$HOME/.m2/repository:/data/maven/.m2/repository"
#

ARG PARENT_IMAGE=alpine:3.16.0
FROM $PARENT_IMAGE

ARG PKGS_TO_ADD="maven"
ARG PKGS_TO_DEL=""
ARG PKGINIT="true"
ARG PKGADD="apk add"
ARG PKGDEL="true"
ARG PKGCLEAN="true"

WORKDIR /work

RUN true \
    && $PKGINIT \
    && $PKGADD $PKGS_TO_ADD \
    && sed -i "s,</settings>,  <localRepository>/data/maven/.m2/repository</localRepository>\n</settings>,g" /usr/share/java/maven-3/conf/settings.xml \
    && mkdir /data /data/maven \
    && chown 1000:1000 /data/maven \
    && chown 1000:1000 /work \
    && $PKGDEL $PKGS_TO_DEL \
    && $PKGCLEAN \
    && true

USER 1000:1000

CMD ["sleep", "36000"]

