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
typedef  struct Source  Source;


#define App_mAGIC 0xB6AF5A16
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    int iSrc;
    Source *sources;
    int sources_len, sources_cap;
    struct GarbageEnv **env;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


struct Source {
    char *filePath;
    FILE *fd;
    char *innBuf;
    int innBuf_beg, innBuf_end, innBuf_cap;
    int logBeg, logEnd; /*idx into innBuf where current log entry begins/ends */
};


char* strerrname(int);


static void printHelp( char const*argv0 ){
    fprintf(stdout, "%s%s%s%s%s",
        "  \n"
        "  Merge log files (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Merges log files based on the ISO timestamp which has to be the very\n"
        "  first thing in every log entry.\n"
        "  \n"
        "  Example usage (HINT: double-dash required):\n"
        "  \n"
        "    ", strrchr(argv0,'/')+1, " -- one.log two.log n.log > merged.log\n"
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
    app->sources[app->sources_len].filePath = arg;
    app->sources_len += 1;
    goto nextNonOpt;
verify:
    if( argc <= 1 ){ LOGERR("EINVAL: Zero args is not enough\n"); return -1; }
    return 0;
}


static void TODO_0f86899eb2eda7503a0e16404ca5a5be( void*app_ ){
    #define MIN(a, b) (((a) < (b)) * (a) + (a >= b) * (b))
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    int lowestSrcIdx = 0;
    for( err = 1 ; err < app->sources_len ; ++err ){
        #define THAT_BUF (app->sources[err].innBuf)
        #define THAT_BEG (app->sources[err].innBuf_beg)
        #define THAT_CNT (app->sources[err].innBuf_end - app->sources[err].innBuf_beg)
        #define OTHR_BUF (app->sources[lowestSrcIdx].innBuf)
        #define OTHR_BEG (app->sources[lowestSrcIdx].innBuf_beg)
        #define OTHR_CNT (app->sources[lowestSrcIdx].innBuf_end - app->sources[lowestSrcIdx].innBuf_beg)
        int diff = memcmp(THAT_BUF + THAT_BEG, OTHR_BUF + OTHR_BEG, MIN(THAT_CNT, OTHR_CNT));
        if( diff < 0 ){ lowestSrcIdx = err; }
        #undef THAT_BUF
        #undef THAT_BEG
        #undef THAT_CNT
        #undef OTHR_BUF
        #undef OTHR_BEG
        #undef OTHR_CNT
    }
    LOGDBG("[DEBUG] Looks like lowest src is idx %d\n", lowestSrcIdx);
    assert(!"TODO_c184bce101f2a862ba34bd2d55e35664");
    #undef MIN
}


static void refillBufferForNextSource( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    app->iSrc += 1;
    if( app->iSrc >= app->sources_len ){
        (*app->env)->enqueBlocking(app->env, TODO_0f86899eb2eda7503a0e16404ca5a5be, app);
        return;
    }
    #define BUF (app->sources[app->iSrc].innBuf)
    #define CAP (app->sources[app->iSrc].innBuf_cap)
    #define BEG (app->sources[app->iSrc].innBuf_beg)
    #define END (app->sources[app->iSrc].innBuf_end)
    #define CNT (app->sources[app->iSrc].innBuf_end - app->sources[app->iSrc].innBuf_beg)
    #define FD  (app->sources[app->iSrc].fd)
    /*shift to buf begin if no overlap*/
    if( BEG > CNT ){
        memcpy(BUF, BUF + BEG, CNT);
        /*need to update all our refs we have into buf*/
        if( app->sources[app->iSrc].logBeg > 0 ){ app->sources[app->iSrc].logBeg -= BEG; }
        if( app->sources[app->iSrc].logEnd > 0 ){ app->sources[app->iSrc].logEnd -= BEG; }
        END -= BEG; BEG = 0;
    }
    /*fill remaining space (if any) */
    if( CAP > END ){
        err = fread(BUF + END, 1, CAP - END, FD);
        if( ferror(FD) ) assert(!"TODO_CuO1jsDccRYGGNsT");
        END += err;
    }
    /* loop to next src */
    (*app->env)->enqueBlocking(app->env, refillBufferForNextSource, app);
    #undef BUF
    #undef CAP
    #undef BEG
    #undef END
    #undef CNT
    #undef FD
}


static void openSrcFiles( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    LOGDBG("[DEBUG] Sources are:\n");
    for( err = 0 ; err < app->sources_len ; ++err ){
        LOGDBG("[DEBUG] - %s\n", app->sources[err].filePath); }
    LOGDBG("[DEBUG] EndOf sources\n");
    /* prepare state for sources */
    for( err = 0 ; err < app->sources_len ; ++err ){
        app->sources[err].fd = fopen(app->sources[err].filePath, "rb");
        if( app->sources[err].fd == NULL ){
            LOGERR("%s: fopen(%s)\n", strerrname(errno), app->sources[err].filePath);
            app->exitCode = -1; return;
        }
        app->sources[err].innBuf_cap = 1<<16;
        app->sources[err].innBuf = malloc(
            app->sources[err].innBuf_cap*sizeof*app->sources[err].innBuf);
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
    if( app->flg & FLG_isHelp ){ printHelp(argv[0]); goto endFn; }
    app->env = GarbageEnv_ctor(app->envMemory, sizeof app->envMemory);
    assert(app->env != NULL);
    app->exitCode = 0;
    (*app->env)->enqueBlocking(app->env, openSrcFiles, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}

