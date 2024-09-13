#if 0 /* Template for QuickNDirty builds */

  && CC=gcc \
  && LD=gcc \
  && OBJDUMP=objdump \
  && BINEXT= \
  && SRCFILE="src/path/to/input.c" \
  && OBJFILE="/tmp/HDG4zsUwy697siH6" \
  && OUTFILE="build/bin/out${BINEXT?}" \
  && CFLAGS="-nostdlib -Wall -Wextra -Werror -pedantic -fmax-errors=1 -Iinclude" \
  && LDFLAGS="-Wl,-nostdlib,-dn,-lgarbage,-lcJSON,-lmbedtls,-lmbedx509,-lmbedcrypto,-lexpat,-dy,-lpthread,-lgcc,-Lbuild/lib,-Limport/lib" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o "${OBJFILE:?}" "${SRCFILE:?}" ${CFLAGS:?} \
  && ${LD:?} -o "${OUTFILE:?}" "${OBJFILE:?}" ${LDFLAGS:?} \
  && bullshit=$(${OBJDUMP?} -p "${OUTFILE:?}"|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm "${OUTFILE:?}"; false; fi \

  Shitty systems maybe need adaptions like:

  && LDFLAGS="-Wl,-lws2_32,-l:libwinpthread.a" \

#endif
