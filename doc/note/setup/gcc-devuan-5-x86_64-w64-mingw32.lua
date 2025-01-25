#!/usr/bin/env lua


function main()
    local dst = io.stdout
    dst:write([=[
#!/bin/sh
set -e \
  && SUDO=sudo \
  && $SUDO apt update \
  && $SUDO apt install --no-install-recommends -y \
         make  gcc-mingw-w64-x86-64-posix  \
  && printf '\n  DONE\n\n' \
]=])
end


main()
