#
# openjdk java 1.8 runtime environment.
#

ARG PARENT_IMAGE=alpine:3.16.0
FROM $PARENT_IMAGE

ARG PKGS_TO_ADD="openjdk8-jre"
ARG PKGS_TO_DEL=""
ARG PKGINIT="true"
ARG PKGADD="apk add"
ARG PKGDEL="true"
ARG PKGCLEAN="true"

WORKDIR /work

RUN true \
    && $PKGINIT \
    && $PKGADD $PKGS_TO_ADD \
    && $PKGDEL $PKGS_TO_DEL \
    && $PKGCLEAN \
    && true

USER 1000:1000

CMD ["sleep", "36000"]

