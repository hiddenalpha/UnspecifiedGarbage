/*

  && CC=gcc \
  && LD=gcc \
  && OBJDUMP=objdump \
  && BINEXT= \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-lcustom_pthread,-dy,-lws2_32,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/UJ0lnr5UIy1so7Rc src/main/paisa/LogMerge.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/LogMerge$BINEXT /tmp/UJ0lnr5UIy1so7Rc ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/LogMerge$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/LogMerge$BINEXT; false; fi \

 */

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Garbage.h"

#define FLG_isHelp (1<<0)

#define STR_QUOT_(s) #s
#define STR_QUOT(s) STR_QUOT_(s)
#define LOGERR(...) fprintf(stderr, __VA_ARGS__);

#if !NDEBUG
#   define REGISTER
#   define LOGDBG(...) fprintf(stderr, __VA_ARGS__);
#else
#   define REGISTER register
#   define LOGDBG(...)
#endif


typedef  struct App  App;


#define App_mAGIC 0xB6AF5A16
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    int iSrc;
    char **sources;
    int sources_cap, sources_len;
    FILE **srcFds;
    int srcFds_cap, srcFds_len;
    char **srcBufs;
    int *srcBufsOff, *srcBufsLen, *srcBufsCap;
    int srcBufs_cap, srcBufs_len;
    struct GarbageEnv **env;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


char* strerrname(int);


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  Fetch houston logs (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Example usage:\n"
        "    this -- one.log two.log n.log > merged.log\n"
        "  \n"
        "  HINT: double-dash required\n"
        //"  Options:\n"
        //"  \n"
        //"    -n <str>, --namespace <str>\n"
        //"      Namespace to use.\n"
        "  \n"
    );
}


static int parseArgs( App*app, int argc, char**argv ){
    REGISTER int iA = 0;
nextOpt:;
    char *arg = argv[++iA];
    if( arg == NULL ){
        goto verify;
    }else if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp;
    }else if( !strcmp(arg, "--") ){
        goto nextNonOpt;
    }else{
        LOGERR("EINVAL: %s\n", arg);
        return -1;
    }
    goto nextOpt;
nextNonOpt:;
    arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( app->sources_cap < app->sources_len +1 ){
        app->sources_cap += 4;
        void *tmp = realloc(app->sources, app->sources_cap*sizeof*app->sources);
        if( tmp == NULL ){ LOGERR("%s: realloc()\n", strerrname(errno)); return -1; }
        app->sources = tmp;
    }
    app->sources[app->sources_len] = arg;
    app->sources_len += 1;
    goto nextNonOpt;
verify:
    if( argc <= 1 ){ LOGERR("EINVAL: Zero args is not enough\n"); return -1; }
    return 0;
}


static void refillBufferForNextSource( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    app->iSrc += 1;
    if( app->iSrc >= app->sources_len ){ assert(!"TODO_bAXZbjYvpNcZpalr"); }
    /* shift to buffer begin (if easily possible) */
    #define BUF (app->srcBufs[app->iSrc])
    #define CAP (app->srcBufsCap[app->iSrc])
    #define OFF (app->srcBufsOff[app->iSrc])
    #define LEN (app->srcBufsLen[app->iSrc])
    #define CNT (app->srcBufsLen[app->iSrc] - app->srcBufsOff[app->iSrc])
    #define FD (app->srcFds[app->iSrc])
    /*shift to buf begin if no overlap*/
    if( OFF > CNT ){
        memcpy(BUF, BUF + OFF, CNT);
        LEN -= OFF; OFF = 0;
    }
    /*fill remaining space (if any) */
    if( CAP > LEN ){
        err = fread(BUF + OFF, 1, CAP - LEN, FD);
        if( ferror(FD) ) assert(!"TODO_CuO1jsDccRYGGNsT");
        LEN += err;
    }
    /* loop to next src */
    (*app->env)->enqueBlocking(app->env, refillBufferForNextSource, app);
    #undef BUF
    #undef CAP
    #undef OFF
    #undef LEN
    #undef CNT
    #undef FD
}


static void openSrcFiles( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    LOGDBG("[DEBUG] Sources are:\n");
    for( err = 0 ; err < app->sources_len ; ++err ){
        LOGDBG("[DEBUG] - %s\n", app->sources[err]); }
    LOGDBG("[DEBUG] EndOf sources\n");
    /* open a handle for every input */
    app->srcFds_cap = app->sources_len;
    app->srcFds = malloc(app->srcFds_cap*sizeof*app->srcFds);
    if( app->srcFds ==  NULL ){
        LOGDBG("assert(malloc() errno != %d)  %s:%d\n", errno, __FILE__, __LINE__); abort(); }
    app->srcBufsOff = malloc(app->sources_len*sizeof*app->srcBufsOff);
    if( app->srcBufsOff ==  NULL ){
        LOGDBG("assert(malloc() errno != %d)  %s:%d\n", errno, __FILE__, __LINE__); abort(); }
    app->srcBufsLen = malloc(app->sources_len*sizeof*app->srcBufsLen);
    if( app->srcBufsLen ==  NULL ){
        LOGDBG("assert(malloc() errno != %d)  %s:%d\n", errno, __FILE__, __LINE__); abort(); }
    app->srcBufsCap = malloc(app->sources_len*sizeof*app->srcBufsCap);
    if( app->srcBufsCap ==  NULL ){
        LOGDBG("assert(malloc() errno != %d)  %s:%d\n", errno, __FILE__, __LINE__); abort(); }
    app->srcBufs_cap = app->srcBufs_len = app->sources_len;
    app->srcBufs = malloc(app->srcBufs_cap*sizeof*app->srcBufs);
    if( app->srcBufs ==  NULL ){
        LOGDBG("assert(malloc() errno != %d)  %s:%d\n", errno, __FILE__, __LINE__); abort(); }
    for( err = 0 ; err < app->sources_len ; ++err ){
        app->srcFds[err] = fopen(app->sources[err], "rb");
        if( app->srcFds[err] == NULL ){
            LOGERR("%s: fopen(%s)\n", strerrname(errno), app->sources[err]);
            app->exitCode = -1; return;
        }
        app->srcBufsCap[err] = 8192;
        app->srcBufs[err] = malloc(app->srcBufsCap[err]*sizeof*app->srcBufs[err]);
    }
    app->iSrc = -1;
    (*app->env)->enqueBlocking(app->env, refillBufferForNextSource, app);
}


int main( int argc, char**argv ){
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->mAGIC = App_mAGIC;
    app->exitCode = -1;
    if( parseArgs(app, argc, argv) ){ goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->env = GarbageEnv_ctor(app->envMemory, sizeof app->envMemory);
    assert(app->env != NULL);
    app->exitCode = 0;
    (*app->env)->enqueBlocking(app->env, openSrcFiles, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}

