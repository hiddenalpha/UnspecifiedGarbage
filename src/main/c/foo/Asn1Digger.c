
#include "commonKludge.h"

/* System */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define FLG_isHelp (1<<0)
#define FLG_innIsEof (1<<1)
#define FLG_assumeGpg (1<<2)
#define FLG_INIT (0)

#define FREAD(buf, sz, cnt, ctx) fread(buf, sz, cnt, ctx)
#define FPRINTF(...) fprintf(__VA_ARGS__)
#define PRINTF(...) FPRINTF(stdout, __VA_ARGS__)

#ifndef NDEBUG
#   define IF_DBG(expr) expr;
#else
#   define IF_DBG(expr)
#endif


typedef  enum FuncToCall  FuncToCall;
typedef  struct AsnDigger  AsnDigger;


enum FuncToCall {
    FUNC_NONE=0,
    FUNC_asnType,
    FUNC_asnLength,
    FUNC_asnValue,
    FUNC_readChunkForHexDump,
    FUNC_appendHexDump,
};


struct AsnDigger {
    unsigned flg;
    long hexCols;
    uchar type; /* ASN.1 type */
    unsigned len; /* ASN.1 length */
    int hexDumpOffs; /* how many bytes we're offset into current value in context of printing it */
    int remainValueBytes; /* how many bytes we still need to process from 'value' */
    FuncToCall funcToCall;
    int typeNameBuf_cap;
    char typeNameBuf[sizeof"subType 0xFF, ContextSpecific, constructed"];
    int asciBuf_cap, asciBuf_len;
    char asciBuf[48+1];
    int innBuf_cap;
    uchar innBuf[1<<15];
};


/* BEG func fwd decls */
static void constructPrintableTypename( AsnDigger*app );
/* END func fwd decls */


//static size_t myFread( void*restrict buf, size_t sz, size_t cnt, FILE*restrict cls ){
//    size_t ret = fread(buf, sz, cnt, cls);
//    fprintf(stderr, "fread(buf, %llu, %llu, cls) -> %llu\n", sz, cnt, ret);
//    return ret;
//}


static void printHelp(){
    PRINTF("%s%s%s", "  \n"
        "  ", strrchr(__FILE__,'/')+1, "  @  " STRQUOT(PROJECT_VERSION) "\n"
        "  \n"
        "  Print ASN.1 from stdin to a textual representation on stdout.\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "      -c <num>\n"
        "          Number of columns to use for hex-dumps. Defaults to 16.\n"
        "  \n"
        "      --gpg\n"
        "          Assume GPG and print additional info for it.\n"
        "  \n");
}


static int parseArgs( int argc, char**argv, AsnDigger*app ){
    app->flg = FLG_INIT;
    app->hexCols = 16;
    for( int iArg=1 ; iArg<argc ; ++iArg ){
        const char *arg = argv[iArg];
        if(0){
        }else if( !strcmp(arg,"--help") ){
            app->flg |= FLG_isHelp; return 0;
        }else if( !strcmp(arg,"-c") ){
            arg = argv[++iArg];
            if( iArg >= argc ){ FPRINTF(stderr,"EINVAL: -c needs value\n"); return -1; }
            errno = 0;
            app->hexCols = strtol(arg, NULL, 0);
            if( errno != 0 ){ FPRINTF(stderr, "EINVAL: -c: %s\n", strerror(errno)); return -1; }
        }else if( !strcmp(arg, "--gpg") ){
            app->flg |= FLG_assumeGpg;
        }else if( !strcmp(arg, "--no-gpg") ){
            app->flg &= ~FLG_assumeGpg;
        }else{
            FPRINTF(stderr, "EINVAL: '%s'\n", arg); return -1;
        }
    }
    if( app->hexCols <= 0 || app->hexCols > 48 ){
        FPRINTF(stderr, "ENOTSUP: %ld hex columns not supported.\n", app->hexCols); return -1;
    }
    return 0;
}


//static unsigned char* ucharPtrOfcharPtr( char*c ){ return (void*)c; }
//static char* charPtrOfucharPtr( unsigned char*c ){ return (void*)c; }


static int asnType( AsnDigger*app ){
    size_t sz;
    int err;
    uchar type[1];
    sz = FREAD(type, 1, 1, stdin);
    if( sz != 1 ){
        err = errno;
        if( feof(stdin) ){
            app->flg |= FLG_innIsEof;
            IF_DBG(app->funcToCall = FUNC_NONE);
            return 0;
        }else{
            FPRINTF(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(err));
            return -err;
        }
    }
    app->type = type[0];
    app->funcToCall = FUNC_asnLength;
    return 0;
}


static int asnLength( AsnDigger*app ){
    size_t sz;
    int err;
    uchar len[1];
    sz = FREAD(len, 1, 1, stdin);
    if( sz != 1 ){
        if( feof(stdin) ){
            app->flg |= FLG_innIsEof;
            IF_DBG(app->funcToCall = FUNC_NONE);
            return 0;
        }else{
            err = errno;
            FPRINTF(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(err));
            return -err;
        }
    }
    assert(len[0] < 0x7F && "TODO_20230829164221");
    app->len = len[0];
    app->funcToCall = FUNC_asnValue;
    return 0;
}


static int asnValue( AsnDigger*app ){

    constructPrintableTypename(app);
    PRINTF("ASN.1 type 0x%02X, len %d (%s), value:", app->type, app->len, app->typeNameBuf);

    if( app->len == 0 ){
        /* no payload. Ready to go to next tag. */
        app->funcToCall = FUNC_asnType;
        return 0;
    }

    /* go process payload */
    app->remainValueBytes = app->len;
    app->funcToCall = FUNC_readChunkForHexDump;
    return 0;
}


static int readChunkForHexDump( AsnDigger*app ){
    #define MIN(a, b) ((a) < (b) ? (a) : (b))
    #define IS_PRINTABLE(c) (c >= 0x20 && c <= 0x7E)
    int err;

    size_t readLen = FREAD(app->innBuf, 1, MIN(app->remainValueBytes, app->innBuf_cap), stdin);
    if( readLen == 0 ){
        err = errno;
        if( feof(stdin) ){
            app->flg |= FLG_innIsEof;
            IF_DBG(app->funcToCall = FUNC_NONE);
            if( app->remainValueBytes > 0 ){
                FPRINTF(stderr, "%s STDIN: Unexpected EOF\n", strrchr(__FILE__,'/')+1);
                return -1;
            }
            return 0;
        }else{
            FPRINTF(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(err));
            return -1;
        }
    }
    assert(app->remainValueBytes >= readLen);
    app->remainValueBytes -= readLen;
    app->funcToCall = FUNC_appendHexDump;
    return 0;
}


static int appendHexDump( AsnDigger*app ){

    if( app->flg & FLG_assumeGpg ){
        if( app->type == 0x95 ){
            PRINTF("\nGPG secret key packet, version %d", app->innBuf[1]);
        }else if( app->type == 0x99 && app->len == 1 && app->innBuf[0] == 0x0D ){
            puts("\nGPG certificate");
        }
    }

    assert(!"TODO_20230829200858");
    /* 1st buffer already loaded above. So begin at printing step. */
//    goto printNewline;
//
//readNexChunk:
//    if( app->remainValueBytes == 0) goto TODO_20230829193554;
//    readLen = FREAD(app->innBuf, 1, MIN(app->remainValueBytes, app->innBuf_cap), stdin);
//    if( readLen == 0 ){
//        err = errno;
//        if( feof(stdin) ){
//            assert(!ferror(stdin));
//            FPRINTF(stderr, "%s STDIN: Unexpected EndOfFile\n", strrchr(__FILE__,'/')+1);
//            app->flg |= FLG_innIsEof;
//        }else{
//            assert(ferror(stdin));
//            FPRINTF(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(errno));
//        }
//        return -1;
//    }
//    assert(app->remainValueBytes >= readLen);
//    app->remainValueBytes -= readLen;
//
//printNewline:
//    assert(app->asciBuf_len % app->hexCols == 0);
//    PRINTF("  %.*s\n  %08X:", app->asciBuf_len, app->asciBuf, app->hexDumpOffs);
//    app->asciBuf_len = 0;
//
//printHexCol:
//    for(; iInn - innOff < readLen ; ++iInn,++app->hexDumpOffs ){
//        PRINTF(" %02X", app->buf[iInn]);
//        /* cache ASCI part (right column of hex-dump) to write it later at EOL */
//        app->buf[app->asciBuf_len++] = IS_PRINTABLE(app->buf[iInn]) ? app->buf[iInn] : '.';
//    }
//
//printAsciCol:
//    if( app->asciBuf_len > 0 && (iInn-innOff>=readLen || app->hexDumpOffs % app->hexCols == 0) ){
//        err = (iInn - innOff) % app->hexCols;
//        for(; err < app->hexCols ; ++err ){ PRINTF("   "); }
//        PRINTF("  %.*s\n", app->asciBuf_len, app->buf);
//        app->asciBuf_len = 0;
//    }
//
//    app->funcToCall = FUNC_asnType;
    return 0;
    #undef MIN
    #undef IS_PRINTABLE
}


static void constructPrintableTypename( AsnDigger*app ){
    int err;
    switch( app->type ){
        case 0x00: memcpy(app->typeNameBuf, "EndOfContent", 13); break;
        case 0x02: memcpy(app->typeNameBuf, "integer", 8); break;
        case 0x04: memcpy(app->typeNameBuf, "octet string", 13); break;
        case 0x0C: memcpy(app->typeNameBuf, "utf8 string", 12); break;
        default:
            /* construct some generified name with help of passed buffer */
            const char *tagClass;
            if(      (app->type & 0xC0) == 0 ){ tagClass = "Universal"; }
            else if( (app->type & 0x40) == 0 ){ tagClass = "Application"; }
            else if( (app->type & 0x80) == 0 ){ tagClass = "ContextSpecific"; }
            else{                          tagClass = "Private"; }
            const char *primOrConstr = (app->type & 0x20) ? "constructed" : "primitive";
            int isLongType = (app->type & 0x1F) == 0x1F;
            if( isLongType ){
                err = snprintf(app->typeNameBuf, app->typeNameBuf_cap, "LongType, %s, %s",
                    tagClass, primOrConstr);
                assert(err < app->typeNameBuf_cap);
            }else{
                err = snprintf(app->typeNameBuf, app->typeNameBuf_cap, "subType 0x%02X, %s, %s",
                    app->type & 0x1F, tagClass, primOrConstr);
                assert(err < app->typeNameBuf_cap);
            }
    }
}


static int run( AsnDigger*app ){
    int err;
    app->funcToCall = FUNC_asnType;
    while( (app->flg & FLG_innIsEof) == 0 ){
        switch( app->funcToCall ){
            case FUNC_asnType: err = asnType(app); break;
            case FUNC_asnLength: err = asnLength(app); break;
            case FUNC_asnValue: err = asnValue(app); break;
            case FUNC_readChunkForHexDump: err = readChunkForHexDump(app); break;
            case FUNC_appendHexDump: err = appendHexDump(app); break;
            default:
                IF_DBG(FPRINTF(stderr,"Whops %d  %s:%d\n", app->funcToCall, __FILE__, __LINE__));
                abort();
        }
        if( err != 0 ){ return err; }
    }
    return 0;
}


int main( int argc, char**argv ){
    int err;
    AsnDigger app;
    #define app (&app)
    app->typeNameBuf_cap = sizeof app->typeNameBuf;
    app->asciBuf_cap = sizeof app->asciBuf;
    app->asciBuf_len = 0;
    app->innBuf_cap = sizeof app->innBuf;

    if( (err=parseArgs(argc, argv, app)) != 0 ){ goto endFn; }

    if( app->flg & FLG_isHelp ){ printHelp(app); err = 0; goto endFn; }

    FUCK_BROKEN_SYSTEMS();

    err = run(app);

endFn:
    return !!err;
    #undef app
}



