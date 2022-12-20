#
# Debian with tools for java-native-interface development.
#

ARG PARENT_IMAGE=debian:buster-20220622-slim
FROM $PARENT_IMAGE

ENV \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

RUN true \
    && apt update \
    && apt install -y --no-install-recommends \
         g++ make openjdk-11-jdk-headless \
    && apt clean \
    && true

USER 1000:1000
WORKDIR /work
CMD ["sleep", "36000"]
