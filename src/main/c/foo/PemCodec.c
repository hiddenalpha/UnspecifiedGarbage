
#include "commonKludge.h"

/* System */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    int buf_len;
    unsigned char buf[BUF_CAP];
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


static int decodeB64UpToDash( PemCodec*app ){
    int err;
    size_t sz;
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
        goto endFn;
    }else{
        fprintf(stderr, "Unexpected octet 0x%02X in b64 stream\n", app->buf[0]);
        err = -1; goto endFn;
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
        err = -errno; goto endFn;
    }

    goto readFourInputOctets; /* aka loop */

    err = 0;
endFn:
    return err;
}


static int decodePem( PemCodec*app ){
    int err;
    size_t sz;

    sz = fread(app->buf, 11, 1, stdin);
    if( sz != 1 ){
        const char *fmt = feof(stdin)
            ? "Unexpected EOF while reading PEM header: %s\n"
            : "Cannot read PEM header: %s\n";
        fprintf(stderr, fmt, strerror(errno));
        err = -1; goto endFn;
    }

    if( memcmp(app->buf, "-----BEGIN ", 11) ){
        fprintf(stderr, "EINVAL: No valid PEM header found\n");
        err = -1; goto endFn;
    }

    /* read until EOL */
    int numDashesInSequence = 0;
    for(;;){
        sz = fread(app->buf, 1, 1, stdin);
        if( sz != 1 ){
            const char *fmt = feof(stdin)
                ? "Unexpected EOF while reading PEM header: %s\n"
                : "Cannot read PEM header: %s\n";
            fprintf(stderr, fmt, strerror(errno));
            err = -1; goto endFn;
        }
        if( app->buf[0] == '\n' ){
            if( numDashesInSequence != 5 ){
                fprintf(stderr, "EINVAL: No valid PEM header found\n");
                err = -1; goto endFn;
            }
            break;
        }
        if( app->buf[0] == '-' ){
            numDashesInSequence += 1;
        }else{
            numDashesInSequence = 0;
        }
    }

    if( (err=decodeB64UpToDash(app)) < 0 ){ goto endFn; }

    /* readEndOfPemLine. 1st dash got already consumed in func above */
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
        err = -1; goto endFn;
    }

    err = 0;
endFn:
    return err;
}


int main( int argc, char**argv ){
    int err;
    PemCodec app;
    #define app (&app)

    if( (err=parseArgs(argc, argv, app)) != 0 ){ goto endFn; }

    if( app->isHelp ){ printHelp(app); err = 0; goto endFn; }

    if( app->mode == MODE_ENCODE ){
        fprintf(stderr, "ENOTSUP: PEM Encode not implented yet\n");
        err = -1; goto endFn;
    }else{
        assert(app->mode == MODE_DECODE);
        err = decodePem(app);
        goto endFn;
    }

endFn:
    return !!err;
    #undef app
}

