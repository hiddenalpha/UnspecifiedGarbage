#
# Debian with C++ compiler.
#

ARG PARENT_IMAGE=debian:buster-20220622-slim
FROM $PARENT_IMAGE

RUN true \
    && apt update \
    && apt install -y --no-install-recommends \
         g++ make \
    && apt clean \
    && true

USER 1000:1000
WORKDIR /work
CMD ["sleep", "36000"]
