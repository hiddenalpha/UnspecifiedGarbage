/*
 *  openssl asn1parse -i -dlimit 9999
 */

#include "commonKludge.h"

/* System */
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define FLG_isHelp (1<<0)
#define FLG_innIsEof (1<<1)
#define FLG_assumeGpg (1<<2)
#define FLG_INIT (0)

#define FREAD(buf, sz, cnt, ctx) fread(buf, sz, cnt, ctx)

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
    FUNC_hexDump_readChunk,
    FUNC_hexDump_dumpFromBuf,
};


struct AsnDigger {
    unsigned flg;
    long hexCols; /* num hex cols wanted by user */
    uchar type; /* ASN.1 type */
    uchar typeFlg; /* ASN.1 flags from the 'type' octet */
    unsigned len; /* ASN.1 length */
    uchar lenFlg; /* flags from the ASN.1 'length' octet */
    int hexDumpOffs; /* how many bytes we're offset into current value in context of printing it */
    int remainValueBytes; /* how many bytes we still need to process from 'value' */
    FuncToCall funcToCall;
    int typeNameBuf_cap;
    char typeNameBuf[sizeof"subType 0xFF, ObjectIdentifier, constructed"];
    int asciBuf_cap, asciBuf_len;
    char asciBuf[48+1];
    int innBuf_cap, innBuf_len;
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
    printf("%s%s%s", "  \n"
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
            if( iArg >= argc ){ fprintf(stderr,"EINVAL: -c needs value\n"); return -1; }
            errno = 0;
            app->hexCols = strtol(arg, NULL, 0);
            if( errno != 0 ){ fprintf(stderr, "EINVAL: -c: %s\n", strerror(errno)); return -1; }
        }else if( !strcmp(arg, "--gpg") ){
            app->flg |= FLG_assumeGpg;
        }else if( !strcmp(arg, "--no-gpg") ){
            app->flg &= ~FLG_assumeGpg;
        }else{
            fprintf(stderr, "EINVAL: '%s'\n", arg); return -1;
        }
    }
    if( app->hexCols <= 0 || app->hexCols > 48 ){
        fprintf(stderr, "ENOTSUP: %ld hex columns not supported.\n", app->hexCols); return -1;
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
            fprintf(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(err));
            return -err;
        }
    }
    app->type = type[0] & 0x1F;
    app->typeFlg = type[0] & 0xE0;
    app->funcToCall = FUNC_asnLength;
    return 0;
}


static int asnLength( AsnDigger*app ){
    size_t sz;
    int err;
    int_fast16_t numBytesRead = 0;
    uchar len[1];
    int_fast8_t isLongType;

    for(;;){
readNextByte:
        sz = FREAD(len, 1, 1, stdin);
        if( sz != 1 ){
            if( feof(stdin) ){
                app->flg |= FLG_innIsEof;
                IF_DBG(app->funcToCall = FUNC_NONE);
                return 0;
            }else{
                err = errno;
                fprintf(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(err));
                return -err;
            }
        }
        numBytesRead += 1;

        if( numBytesRead == 1 ){
            isLongType = (len[0] & 0x1F) == 0x1F;
            app->len = isLongType ? 0 : (len[0] & 0x1F);
            app->lenFlg = len[0] & 0xE0;
        }
        if( isLongType ){
            if( numBytesRead > sizeof(app->len)*8/7 ){
                fprintf(stderr, "%s ENOTSUP: Cannot handle tag length encoded in more than %d bytes\n",
                    strrchr(__FILE__,'/')+1, numBytesRead-1);
                return -ENOTSUP;
            }else{
                app->len = (app->len << numBytesRead*7) | (len[0] & 0x7F);
                const int_fast8_t hasMoreBytes = len[0] & 0x80;
                if( hasMoreBytes ){
                    goto readNextByte;
                }else{
                    goto setupValueFuncThenReturn;
                }
            }
        }else{
            app->len = len[0] & 0x1F;
            app->lenFlg = len[0] & 0xE0;
            goto setupValueFuncThenReturn;
        }
    }

setupValueFuncThenReturn:
    app->funcToCall = FUNC_asnValue;
    return 0;
}


static int asnValue( AsnDigger*app ){

    constructPrintableTypename(app);
    printf("ASN.1 type 0x%02X, typeFlgs 0x%02X, len %d, lenFlgs 0x%02X (%s)%s",
        app->type, app->typeFlg, app->len, app->lenFlg, app->typeNameBuf, app->len?", value:":"");

    if( app->len == 0 ){
        /* no payload. Ready to go to next tag. */
        printf("\n");
        app->funcToCall = FUNC_asnType;
        return 0;
    }

    /* go process payload */
    app->remainValueBytes = app->len;
    app->hexDumpOffs = 0;
    app->asciBuf_len = 0;
    app->funcToCall = FUNC_hexDump_readChunk;
    return 0;
}


static int hexDump_readChunk( AsnDigger*app ){
    #define MIN(a, b) ((a) < (b) ? (a) : (b))
    #define IS_PRINTABLE(c) (c >= 0x20 && c <= 0x7E)
    int_fast32_t err;

    size_t readLen = MIN(app->remainValueBytes, app->innBuf_cap);
    err = readLen % app->hexCols;
    if( err != 0 && readLen < err ){ /*align buffer to make printing of hexDump easier*/
        readLen -= err; }
    assert(readLen > 0);
    readLen = FREAD(app->innBuf, 1, readLen, stdin);
    if( readLen == 0 ){
        err = errno;
        if( feof(stdin) ){
            app->flg |= FLG_innIsEof;
            IF_DBG(app->funcToCall = FUNC_NONE);
            if( app->remainValueBytes > 0 ){
                fprintf(stderr, "%s STDIN: Unexpected EOF\n", strrchr(__FILE__,'/')+1);
                return -1;
            }
            return 0;
        }else{
            fprintf(stderr, "%s STDIN: %s\n", strrchr(__FILE__,'/')+1, strerror(err));
            return -1;
        }
    }
    assert(app->remainValueBytes >= readLen);
    app->innBuf_len = readLen;
    app->remainValueBytes -= readLen;
    app->funcToCall = FUNC_hexDump_dumpFromBuf;
    return 0;
}


static int hexDump_dumpFromBuf( AsnDigger*app ){

    int_fast32_t err;
    const int_fast8_t isFirstRun = app->remainValueBytes == (app->len - app->innBuf_len);

    if( (app->flg & FLG_assumeGpg) && isFirstRun ){
        if( app->type == 0x95 ){
            printf("\nGPG secret key packet, version %d", app->innBuf[1]);
        }else if( app->type == 0x99 && app->len == 1 && app->innBuf[0] == 0x0D ){
            puts("\nGPG certificate");
        }
    }

    /* print hex column */
    int iChr;
    for( iChr=0 ; iChr < app->innBuf_len ; ++iChr,++app->hexDumpOffs ){
        if( app->hexDumpOffs % app->hexCols == 0 ){
            /* start next hexDump line */
            printf("  %.*s\n  %08X:", app->asciBuf_len, app->asciBuf, app->hexDumpOffs);
            app->asciBuf_len = 0;
        }
        printf(" %02X", app->innBuf[iChr]);
        /* cache ASCI part (right column of hex-dump) to write it later at EOL */
        app->asciBuf[app->asciBuf_len++] = IS_PRINTABLE(app->innBuf[iChr]) ? app->innBuf[iChr] : '.';
    }

    /* print asci column */
    if( app->asciBuf_len > 0 ){
        err = iChr % app->hexCols;
        for(; err < app->hexCols ; ++err ){ printf("   "); } /* fill hexDump space on last line */
        printf("  %.*s\n", app->asciBuf_len, app->asciBuf); /* print asci chars */
        app->asciBuf_len = 0;
    }

    if( app->remainValueBytes == 0 ){
        app->funcToCall = FUNC_asnType; /* done here. Go read next asn tag. */
    }else{
        app->funcToCall = FUNC_hexDump_readChunk; /* there's more data for current tag */
    }

    return 0;
    #undef MIN
    #undef IS_PRINTABLE
}


static void constructPrintableTypename( AsnDigger*app ){
    int err;
    switch( app->type ){
        case 0x00: memcpy(app->typeNameBuf, "EndOfContent", 13); break;
        case 0x02: memcpy(app->typeNameBuf, "Integer", 8); break;
        case 0x04: memcpy(app->typeNameBuf, "OctetString", 12); break;
        case 0x05: memcpy(app->typeNameBuf, "null", 5); break;
        case 0x06: memcpy(app->typeNameBuf, "ObjectIdentifier", 17); break;
        case 0x08: memcpy(app->typeNameBuf, "External", 9); break;
        case 0x0C: memcpy(app->typeNameBuf, "Utf8String", 11); break;
        case 0x0F: memcpy(app->typeNameBuf, "Reserved!!", 11); break;
        case 0x10: memcpy(app->typeNameBuf, "Sequence", 9); break;
        case 0x12: memcpy(app->typeNameBuf, "NumericString", 14); break;
        case 0x13: memcpy(app->typeNameBuf, "PrintableString", 16); break;
        case 0x18: memcpy(app->typeNameBuf, "GeneralizedTime", 16); break;
        case 0x1C: memcpy(app->typeNameBuf, "UniversalString", 16); break;
        case 0x1D: memcpy(app->typeNameBuf, "CharacterString", 16); break;
        case 0x23: memcpy(app->typeNameBuf, "OID-IRI", 8); break;
        default:
            /* construct some generified name with help of passed buffer */
            const char *tagClass;
            if(      (app->typeFlg & 0xC0) == 0 ){ tagClass = "Universal"; }
            else if( (app->typeFlg & 0x40) == 0 ){ tagClass = "Application"; }
            else if( (app->typeFlg & 0x80) == 0 ){ tagClass = "ContextSpecific"; }
            else{                          tagClass = "Private"; }
            const char *primOrConstr = (app->typeFlg & 0x20) ? "constructed" : "primitive";
            int isLongType = app->type == 0x1F;
            if( isLongType ){
                err = snprintf(app->typeNameBuf, app->typeNameBuf_cap, "LongType, %s, %s",
                    tagClass, primOrConstr);
                assert(err < app->typeNameBuf_cap);
            }else{
                err = snprintf(app->typeNameBuf, app->typeNameBuf_cap, "subType 0x%02X, %s, %s",
                    app->type, tagClass, primOrConstr);
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
            case FUNC_hexDump_readChunk: err = hexDump_readChunk(app); break;
            case FUNC_hexDump_dumpFromBuf: err = hexDump_dumpFromBuf(app); break;
            default:
                IF_DBG(fprintf(stderr,"Whops %d  %s:%d\n", app->funcToCall, __FILE__, __LINE__));
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
    app->innBuf_len = 0;

    if( (err=parseArgs(argc, argv, app)) != 0 ){ goto endFn; }

    if( app->flg & FLG_isHelp ){ printHelp(app); err = 0; goto endFn; }

    FUCK_BROKEN_SYSTEMS();

    err = run(app);

endFn:
    return !!err;
    #undef app
}



