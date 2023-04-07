
Additional DeflateAndInflate Notes
==================================

DST=/tmp/meins &&\
IMGDEB=zlib-deb:latest &&\
IMGWIN=zlib-mingw:latest &&\
docker run -v "$PWD:/work" --rm -ti -u `id -u`:`id -g` "${IMGDEB:?}" sh -c 'cd /work && ./configure && make clean && make -e'
mv -t "${DST:?}" dist/DeflateAndInflate-* &&\
docker run --rm -ti -u `id -u`:`id -g` -v "$PWD:/work" "${IMGWIN:?}" sh -c 'cd /work && ./configure && make clean && make -e'
mv -t "${DST:?}" dist/DeflateAndInflate-* &&\

