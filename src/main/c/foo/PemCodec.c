/*

TODO move to some kind of makefile

  true \
    && CFLAGS="-Wall -std=c99 -Werror -fmax-errors=3" \
    && `# CFLAGS="-Wall -std=c99 -Werror -fmax-errors=3 -ggdb -O0 -g3" ` \
    && BINEXT= \
    && CC=x86_64-w64-mingw32-gcc \
    && (mkdir build build/bin || true) \
    && ${CC:?} -o build/bin/pem-codec${BINEXT} ${CFLAGS} src/main/c/foo/PemCodec.c \
    && true

*/

/* System */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define STRQUOT_ASDFASDF(s) #s
#define STRQUOT(s) STRQUOT_ASDFASDF(s)
#ifndef PROJECT_VERSION
#   define PROJECT_VERSION 0.0.0-SNAPSHOT
#endif
#define BUF_CAP (1<<15)


typedef  struct PemCodec  PemCodec;


enum Mode {
    MODE_NONE = 0,
    MODE_ENCODE,
    MODE_DECODE,
};


struct PemCodec {
    int isHelp; /* TODO flg */
    enum Mode mode; /* one of "ENCODE" or "DECODE" */
    unsigned char buf[BUF_CAP];
    int buf_len;
};


static void printHelp(){
    printf("%s%s%s", "  \n"
        "  ", strrchr(__FILE__,'/')+1, "  @  " STRQUOT(PROJECT_VERSION) "\n"
        "  \n"
        "  encode/decode PEM (PrivacyEnhancedMail) from stdin to stdout.\n"
        "  \n"
        "  HINT: Encode is not yet implemented.\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "      -d     decode\n"
        "  \n");
}


static int parseArgs( int argc, char**argv, PemCodec*app ){
    app->isHelp = 0;
    app->mode = MODE_ENCODE;
    if( argc == 1 ){ fprintf(stderr, "EINVAL: Args missing\n"); return -1; }
    for( int iArg=1 ; iArg<argc ; ++iArg ){
        const char *arg = argv[iArg];
        if(0){
        }else if( !strcmp(arg,"--help") ){
            app->isHelp = !0; return 0;
        }else if( !strcmp(arg,"-d") ){
            app->mode = MODE_DECODE;
        }else{
            fprintf(stderr, "EINVAL: '%s'\n", arg); return -1;
        }
    }
    return 0;
}


static int decode( PemCodec*app ){
    int err;
    size_t sz;

    sz = fread(app->buf, 11, 1, stdin);
    if( sz != 1 ){
        assert(!fprintf(stderr, "fread: %s  %s:%d\n", strerror(errno), __FILE__, __LINE__)); return -1;
    }

    if( memcmp(app->buf, "-----BEGIN ", 11) ){
        fprintf(stderr, "EINVAL: No valid PEM header found\n");
        return -EINVAL;
    }

    /* read until EOL */
    int numDashesInSequence = 0;
    for(;;){
        sz = fread(app->buf, 1, 1, stdin);
        if( sz != 1 ){
            assert(!fprintf(stderr, "TODO %llu  %s:%d\n", sz, __FILE__, __LINE__));
        }
        if( app->buf[0] == '\n' ){
            if( numDashesInSequence != 5 ){
                fprintf(stderr, "EINVAL: No valid PEM header found\n");
                return -1;
            }
            break;
        }
        if( app->buf[0] == '-' ){
            numDashesInSequence += 1;
        }else{
            numDashesInSequence = 0;
        }
    }

    /* decode b64 */
    int iByte;
    int sextets[4];
readFourInputOctets:
    iByte = 0;
readNextInputOctet:
    sz = fread(app->buf, 1, 1, stdin);
    if( sz != 1 ){ assert(!"TODO_20230825155237"); }

    /* TODO may use switch-case instead */
    if(0){
    }else if( app->buf[0] >= 'A' && app->buf[0] <= 'Z' ){
        sextets[iByte] = app->buf[0] - 65;
    }else if( app->buf[0] >= 'a' && app->buf[0] <= 'z' ){
        sextets[iByte] = app->buf[0] - 71;
    }else if( app->buf[0] >= '0' && app->buf[0] <= '9' ){
        sextets[iByte] = app->buf[0] + 4;
    }else if( app->buf[0] == '+' ){
        sextets[iByte] = 63;
    }else if( app->buf[0] == '/' ){
        sextets[iByte] = 64;
    }else if( app->buf[0] == '=' ){
        sextets[iByte] = 0;
    }else if( app->buf[0] == '\n' ){ /* ignore newlines */
        goto readNextInputOctet;
    }else if( app->buf[0] == '-' ){ /* EndOf b64 data */
        goto readEndOfPemLine;
    }else{
        assert(!"TODO_20230825155655");
    }

    if( ++iByte < 4 ) goto readNextInputOctet; /* aka loop */

    /* output as the three original binary octets */
    err = printf("%c%c%c",
        ( sextets[0]        << 2) | (sextets[1] >> 4) ,
        ((sextets[1] & 0xF) << 4) | (sextets[2] >> 2) ,
        ((sextets[2] & 0x3) << 6) |  sextets[3]
    );
    if( err < 0 ){
        err = errno;
        fprintf(stderr, "printf: %s\n", strerror(errno));
        return -errno;
    }

    goto readFourInputOctets; /* aka loop */

readEndOfPemLine:
    /* 1st dash got already consumed above */
    sz = fread(app->buf, 8, 1, stdin);
    if( sz != 1 || memcmp(app->buf, "----END ", 8)){
        assert(fprintf(stderr, "sz=%llu\n", sz));
        goto warnAndDrain;
    }
    /* assume rest of trailer is ok */
    goto drain;

warnAndDrain:
    fprintf(stderr, "WARN: PEM trailer broken\n");

drain:
    sz = fread(app->buf, BUF_CAP, 1, stdin);
    if( sz > 0 ) goto drain;
    if( ferror(stdin) ){
        fprintf(stderr, "fread: %s\n", strerror(errno));
        return -1;
    }

    return 0;
}


int main( int argc, char**argv ){
    int ax;
    PemCodec app;
    #define app (&app)

    if( (ax=parseArgs(argc, argv, app)) != 0 ){ goto endFn; }

    if( app->isHelp ){ printHelp(app); ax = 0; goto endFn; }

    if( app->mode == MODE_ENCODE ){
        fprintf(stderr, "ENOTSUP: PEM Encode not implented yet\n");
        ax = -1; goto endFn;
    }else{
        assert(app->mode == MODE_DECODE);
        ax = decode(app);
        goto endFn;
    }

endFn:
    return !!ax;
    #undef app
}

