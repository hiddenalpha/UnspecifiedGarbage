#!/usr/bin/env lua
--[===========================================================================[

  POSIX shell script generator to setup my gcc x86_64-linux-gnu build machine.

  ]===========================================================================]

function main()
    local dst = io.stdout
    dst:write([=[
#!/bin/sh
set -e \
  \
  && SUDO=sudo \
  \
  && $SUDO apt update \
  && $SUDO apt install --no-install-recommends -y \
       cifs-utils binutils make gcc libc6-dev \
       gdb valgrind \
]=])
end


main()
