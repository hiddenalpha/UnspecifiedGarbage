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
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h> /*TODO remove*/

#include "Garbage.h"

#define FLG_isHelp (1<<0)
#define FLG_isEof (1<<1)
#define FLG_needMore (1<<2)
#define FLG_isNoMoreEntries (1<<3)
#define FLG_isDedupe (1<<4)
#define FLG_isInit_patrnLogBegin (1<<5)

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
    int lowestSrcIdx;
    int numRefillsRunning, numLogMarksRunning;
    regex_t patrnLogBegin;
    Source *sources;
    int sources_len, sources_cap;
    char *lastWrittenMsg;
    int lastWrittenMsg_cap, lastWrittenMsg_len;
    struct GarbageEnv **env;
    struct Garbage_ThreadPool **thrdPool;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


#define Source_mAGIC 0x4CFC41C3
struct Source {
    int mAGIC;
    int flg;
    App *app; /*parent-ptr*/
    char *filePath;
    FILE *fd;
    char *innBuf;
    int innBuf_beg, innBuf_end, innBuf_cap;
    int logBeg, logEnd; /*idx into innBuf where current log entry begins/ends */
};


char* strerrname(int);
static void refillSrcBuffers( void*app_ );


#if !NDEBUG
static pthread_t evLoopThrd;
#endif


static void printHelp( char const*argv0 ){
    fprintf(stdout, "%s%s%s%s%s",
        "  \n"
        "  Merge log files (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Merges log files based on the ISO timestamp (eg 2024-12-31T23:59:59)\n"
        "  which has to be the very first thing in every log entry. Further,\n"
        "  the timestamp MUST be in the same timezone for all log files.\n"
        "  \n"
        "  Example usage:\n"
        "  \n"
        "    ", strrchr(argv0,'/')+1, " one.log two.log n.log > merged.log\n"
        "  \n"
        "  A '-' (dash) can be used as ONE of the inputs to use stdin.\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    --no-dedupe\n"
        "      By default this tool tries to de-duplicate log entries. This is\n"
        "      because it allows to merge overlapping log files. For example\n"
        "      if the same log file gets backed up several times but in\n"
        "      different points in time, those log files will be the same at\n"
        "      the beginning, but will differ towards the end. Therefore usually\n"
        "      this de-duplication is what the tool author needs. If this\n"
        "      feature looks like a bug in your use-case, you can disable it\n"
        "      by using this option.\n"
        "  \n"
    );
}


static int parseArgs( App*app, int argc, char**argv ){
    REGISTER int iA = 0;
    int isStrictlyNonOpt = 0;
    app->flg |= FLG_isDedupe;
nextArg:;
    char *arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( isStrictlyNonOpt ){ goto onNonOpt; }
    if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg, "--no-dedupe") ){
        app->flg &= ~FLG_isDedupe;
    }else if( !strcmp(arg, "--") ){
        isStrictlyNonOpt = 1;
    }else{
        goto onNonOpt;
    }
    goto nextArg;
onNonOpt:
    if( app->sources_cap < app->sources_len +1 ){
        app->sources_cap += 4;
        void *tmp = realloc(app->sources, app->sources_cap*sizeof*app->sources);
        if( tmp == NULL ){ LOGERR("%s: realloc()\n", strerrname(errno)); return -1; }
        app->sources = tmp;
    }
    memset(app->sources + app->sources_len, 0, sizeof*app->sources); assert((void*)0 == NULL);
    app->sources[app->sources_len].mAGIC = Source_mAGIC;
    app->sources[app->sources_len].app = app;
    app->sources[app->sources_len].filePath = arg;
    app->sources_len += 1;
    goto nextArg;
verify:
    if( argc <= 1 ){ LOGERR("EINVAL: Zero-arg-nonsense. Tell me what you want please.\n"); return -1; }
    if( app->sources_len == 0 ){
        LOGDBG("[WARN ] Zero input files given. If you're searching for a no-op cmd use 'true'.\n");
    }
    return 0;
}


static void writeLowestEntryToDst( void*app_ ){
    REGISTER int err;
    //LOGDBG("[TRACE] %s\n", __func__);
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(pthread_equal(evLoopThrd, pthread_self()));
    #define MAX(a, b) (((a) > (b)) * (a) + (((a) <= (b)) * (b)))
    #define MIN(a, b) (((a) < (b)) * (a) + (((a) >= (b)) * (b)))
    #define SRC (&app->sources[app->lowestSrcIdx])
    #define TXT (SRC->innBuf + SRC->logBeg)
    #define CNT (SRC->logEnd - SRC->logBeg)
    assert(SRC->logBeg <= SRC->logEnd);
    err = MIN(app->lastWrittenMsg_len, SRC->logEnd - SRC->logBeg);
    if( (app->flg & FLG_isDedupe) && err > 0
        && !memcmp(app->lastWrittenMsg, SRC->innBuf + SRC->logBeg, err)
    ){
        goto refillSourcesAgain;
    }
    /* publish */
    fprintf(stdout, "%.*s\n", CNT, TXT);
    /* take a copy for later reference */
    if( app->lastWrittenMsg_cap < CNT ){
        app->lastWrittenMsg_cap = MAX(CNT, 4096);
        void *tmp = realloc(app->lastWrittenMsg, app->lastWrittenMsg_cap*sizeof*app->lastWrittenMsg);
        if( tmp == NULL ){ LOGERR("%s: realloc()\n", strerrname(errno)); app->exitCode = -1; return; }
        app->lastWrittenMsg = tmp;
    }
    memcpy(app->lastWrittenMsg, TXT, CNT);
    app->lastWrittenMsg_len = CNT;
refillSourcesAgain:
    /* mark entry as consumed*/
    SRC->innBuf_beg = SRC->logBeg = SRC->logEnd;
    /* continue with more input */
    refillSrcBuffers(app);
    #undef MAX
    #undef MIN
    #undef SRC
    #undef TXT
    #undef CNT
}


static void findOldestLogEntryFromAllHeads( void*app_ ){
    #define MIN(a, b) (((a) < (b)) * (a) + (a >= b) * (b))
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(pthread_equal(evLoopThrd, pthread_self()));
    app->lowestSrcIdx = 0;
    for(;; ++app->lowestSrcIdx ){
        if( app->lowestSrcIdx >= app->sources_len ){
            //LOGDBG("[DEBUG] Done\n");
            app->exitCode = 0; return;
        }
        if( app->sources[app->lowestSrcIdx].flg & FLG_isNoMoreEntries ) continue;
        break;
    }
    for( err = 1 ; err < app->sources_len ; ++err ){
        #define SRC (app->sources + err)
        #define THAT_BUF (app->sources[err].innBuf)
        #define THAT_LOGBEG (app->sources[err].logBeg)
        #define THAT_CNT (app->sources[err].logEnd - app->sources[err].logBeg)
        #define OTHR_BUF (app->sources[app->lowestSrcIdx].innBuf)
        #define OTHR_LOGBEG (app->sources[app->lowestSrcIdx].logBeg)
        #define OTHR_CNT (app->sources[app->lowestSrcIdx].logEnd - app->sources[app->lowestSrcIdx].logBeg)
        if( SRC->flg & FLG_isNoMoreEntries ){ continue; }
        int diff = memcmp(THAT_BUF + THAT_LOGBEG, OTHR_BUF + OTHR_LOGBEG, MIN(THAT_CNT, OTHR_CNT));
        if( diff < 0 ){ app->lowestSrcIdx = err; }
        #undef SRC
        #undef THAT_BUF
        #undef THAT_CNT
        #undef OTHR_BUF
        #undef OTHR_CNT
    }
    (*app->env)->enqueBlocking(app->env, writeLowestEntryToDst, app);
    #undef MIN
}


static void markLogEntryForSourceDone( void*src_ ){
    Source*const src = src_; assert(src->mAGIC == Source_mAGIC);
    App*const app = src->app; assert(app->mAGIC == App_mAGIC);
    app->numLogMarksRunning -= 1;
    (*app->env)->delAwaitToken(app->env);
    if( src->flg & FLG_needMore ){ app->flg |= FLG_needMore; } /*propagate*/
    if( app->numLogMarksRunning > 0 || app->exitCode ){
        return;
    }
    if( app->flg & FLG_needMore ){ /* check needMore on ALL sources */
        app->flg &= ~FLG_needMore;
        (*app->env)->enqueBlocking(app->env, refillSrcBuffers, app);
        return;
    }
    (*app->env)->enqueBlocking(app->env, findOldestLogEntryFromAllHeads, app);
}


static void markLogEntryForSourceByArg( void*src_ ){
    #define MAX(a, b) (((a) > (b)) * (a) + ((a) <= (b)) * (b))
    REGISTER int err;
    Source*const src = src_; assert(src->mAGIC == Source_mAGIC);
    App*const app = src->app; assert(app->mAGIC == App_mAGIC);
    assert(!pthread_equal(evLoopThrd, pthread_self()));
    #define SRC src
    #define BUF (src->innBuf)
    #define BEG (src->innBuf_beg)
    #define END (src->innBuf_end)
    #define LOGBEG (src->logBeg)
    #define LOGEND (src->logEnd)
    /*find begin of this log entry*/
    for( err = BEG ;; ++err ){
        if( err >= END ){
            if( SRC->flg & FLG_isEof ){
                /* no more entries */
                SRC->flg |= FLG_isNoMoreEntries;
                goto endFn;
            }
            assert(!(SRC->flg & FLG_isEof));
            SRC->flg |= FLG_needMore;
            goto endFn;
        }
        if( (err - BEG > 0 && err - BEG > 0 && BUF[err -1] != '\n')
          || BUF[err +0] != '2'
          || BUF[err +1] != '0'
        ){ continue; }
        /* shitty APIs take zero-term strings grml... */
        char bkup = BUF[END-1]; BUF[END-1] = '\0';
        if( regexec(&app->patrnLogBegin, BUF + err, 0, NULL, 0) ){
            BUF[END-1] = bkup;
            continue;
        }
        BUF[END-1] = bkup;
        LOGBEG = err;
        err += 1;
        break;
    }
    /*find end of log entry (aka begin of the next one) */
    for(;; ++err ){
        if( err >= END ){ /* need more lookahead data */
            if( SRC->flg & FLG_isEof ){
                //LOGDBG("[DEBUG] There is no more data for src[%d]. This means"
                //    " we can report %d as the log-entry end.\n", app->iSrc, err);
                LOGEND = err -1; /* -1, aka drop trailing LF */
                break;
            }
            SRC->flg |= FLG_needMore;
            goto endFn;
        }
        assert(err - BEG > 0);
        if(  BUF[err -1] != '\n'
          || BUF[err +0] != '2'
          || (END - err > 0 && BUF[err +1] != '0')
        ){ continue; }
        /* shitty APIs take zero-term strings grml... */
        char bkup = BUF[END-1]; BUF[END-1] = '\0';
        if( regexec(&app->patrnLogBegin, BUF + err, 0, NULL, 0) ){
            BUF[END-1] = bkup;
            continue;
        }
        BUF[END-1] = bkup;
        LOGEND = err -1; /* -1, aka drop trailing LF */
        err += 1;
        break;
    }
endFn:
    (*app->env)->enqueBlocking(app->env, markLogEntryForSourceDone, src);
    #undef SRC
    #undef MAX
    #undef BUF
    #undef BEG
    #undef END
    #undef LOGBEG
    #undef LOGEND
}


static void markLogEntriesForeachSource( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(pthread_equal(evLoopThrd, pthread_self()));
    if( app->sources_len == 0 ){
        assert(!"TODO_54b5675910784c91d25e6178712012ac");
    }else for( err = 0 ; err < app->sources_len ; ++err ){
        (*app->thrdPool)->enque(app->thrdPool,
            markLogEntryForSourceByArg, app->sources + err);
        app->numLogMarksRunning += 1;
        (*app->env)->addAwaitToken(app->env);
    }
}


static void onOneRefillDone( void*app_ ){
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(pthread_equal(evLoopThrd, pthread_self()));
    app->numRefillsRunning -= 1;
    (*app->env)->delAwaitToken(app->env);
    if( app->numRefillsRunning > 0 || app->exitCode ) return;
    (*app->env)->enqueBlocking(app->env, markLogEntriesForeachSource, app);
}


static void refillBufferForSourceByArg( void*src_ ){
    REGISTER int err;
    Source *src = src_; assert(src->mAGIC == Source_mAGIC);
    App*const app = src->app; assert(app->mAGIC == App_mAGIC);
    assert(!pthread_equal(evLoopThrd, pthread_self()));
    #define BUF (src->innBuf)
    #define CAP (src->innBuf_cap)
    #define BEG (src->innBuf_beg)
    #define END (src->innBuf_end)
    #define CNT (src->innBuf_end - src->innBuf_beg)
    #define FD  (src->fd)
    if( BEG > CNT  && CNT > 0 ){
        //LOGDBG("[TRACE] memcpy(0x%lX, 0x%lX, %d)\n", (uintptr_t)BUF, (uintptr_t)BUF + BEG, CNT);
        memcpy(BUF, BUF + BEG, CNT);
        /*need to update all our refs we have into buf*/
        if( src->logBeg > 0 ){ src->logBeg -= BEG; }
        if( src->logEnd > 0 ){ src->logEnd -= BEG; }
        END -= BEG; BEG = 0;
    }
    /*fill remaining space (if any) */
    if( CAP > END && !(src->flg & FLG_isEof) ){
        err = fread(BUF + END, 1, CAP - END, FD);
        if( ferror(FD) ) assert(!"TODO_CuO1jsDccRYGGNsT");
        if( feof(FD) ){ src->flg |= FLG_isEof; }
        END += err;
    }else if( src->flg & FLG_needMore ){
        assert(!feof(FD)); /*Fix other code. There is no more data*/
        if( CNT > 0xFFFFFF ){ /*WTF how large is this log entry?!?*/
            LOGDBG("[ERROR] Unable to detect log entry within %d bytes in \"%s\"\n",
                CNT, src->filePath);
            app->exitCode = -1; return;
        }
        /* Add some more buffer and start over */
        src->flg &= ~FLG_needMore;
        src->innBuf_cap += 4096;
        void *tmp = realloc(src->innBuf, src->innBuf_cap*sizeof*src->innBuf);
        if( tmp == NULL ){ LOGDBG("%s: realloc()\n", strerrname(errno)); app->exitCode = -1; return; }
        src->innBuf = tmp;
        refillBufferForSourceByArg(src);
        return;
    }
    /* report this one done */
    (*app->env)->enqueBlocking(app->env, onOneRefillDone, app);
    #undef BUF
    #undef CAP
    #undef BEG
    #undef END
    #undef CNT
    #undef FD
}


static void refillSrcBuffers( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(pthread_equal(evLoopThrd, pthread_self()));
    if( app->sources_len == 0 ){
        return; /* no files given we could read */
    }else for( err = 0 ; err < app->sources_len ; ++err ){
        (*app->thrdPool)->enque(app->thrdPool,
            refillBufferForSourceByArg, app->sources + err);
        app->numRefillsRunning += 1;
        (*app->env)->addAwaitToken(app->env);
    }
}


static void openSrcFiles( void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(pthread_equal(evLoopThrd, pthread_self()));
    /* prepare state for sources */
    for( err = 0 ; err < app->sources_len ; ++err ){
        app->sources[err].fd = !strcmp(app->sources[err].filePath, "-")
            ? stdin
            : fopen(app->sources[err].filePath, "rb") ;
        if( app->sources[err].fd == NULL ){
            LOGERR("%s: fopen(%s)\n", strerrname(errno), app->sources[err].filePath);
            app->exitCode = -1; return;
        }
        app->sources[err].innBuf_cap = 1<<16;
        app->sources[err].innBuf = malloc(
            app->sources[err].innBuf_cap*sizeof*app->sources[err].innBuf);
    }
    refillSrcBuffers(app);
}


static void initStuff( void*app_ ){
    #define MIN(a, b) (((a) < (b)) * (a) + ((a) >= (b)) * (b))
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    err = regcomp(&app->patrnLogBegin,
        "^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9][T_ ][0-9][0-9]:[0-9][0-9]:[0-9][0-9][^0123456789]",
        REG_EXTENDED);
    if( err ){
        char emsg[64]; regerror(err, NULL, emsg, sizeof emsg);
        LOGERR("%s: regcomp()\n", emsg);
        app->exitCode = -1; return;
    }else{
        app->flg |= FLG_isInit_patrnLogBegin;
    }
    if( app->sources_len > 0 ){
        static struct Garbage_ThreadPool_Mentor tpMentorVt = {
            .foo = NULL,
        }, *tpMentor = &tpMentorVt;
        struct Garbage_ThreadPool_Opts tpOpts = {
            /* TODO MIN(MAX(1, numSrc), 32). Using at least same as nSources for now to
             * prevent deadlocks due to libgarbage having very short task queues. */
            .numThrds = app->sources_len,
        };
        app->thrdPool = (*app->env)->newThreadPool(app->env, &tpMentor, &tpOpts);
        (*app->thrdPool)->start(app->thrdPool);
    }
    (*app->env)->enqueBlocking(app->env, openSrcFiles, app);
    #undef MIN
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
    (*app->env)->enqueBlocking(app->env, initStuff, app);
#if !NDEBUG
    evLoopThrd = pthread_self();
#endif
    (*app->env)->runUntilDone(app->env);
    (*app->thrdPool)->joinBlocking(app->thrdPool);
endFn:
    if( app->flg & FLG_isInit_patrnLogBegin ){ regfree(&app->patrnLogBegin); }
    return !!app->exitCode;
    #undef app
}

