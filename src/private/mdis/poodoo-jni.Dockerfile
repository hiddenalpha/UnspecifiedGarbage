
  && SUDO=sudo \
  && $SUDO podman build -f- -t guguseli:0.0.0-SNAPSHOT . <<EOF &&
FROM docker.tools.post.ch/paisa/alice:04.00.09.00
USER root
RUN true \\
  && SUDO=sudo \\
  && $SUDO apt-get install --no-install-recommends -y gcc libc-dev make \\
  && true
USER isa
EOF
true \

