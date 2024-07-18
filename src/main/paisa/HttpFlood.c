/*

  && CC=gcc \
  && LD=gcc \
  && OBJDUMP=true \
  && BINEXT= \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-lcustom_pthread,-dy,-lws2_32,-Limport/lib" \

  && CC=x86_64-w64-mingw32-gcc \
  && LD=x86_64-w64-mingw32-gcc \
  && OBJDUMP=x86_64-w64-mingw32-objdump \
  && BINEXT=.exe \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-l:libwinpthread.a,-dy,-lws2_32,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/9VECAKxQAgBbIgIA src/main/paisa/HttpFlood.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/HttpFlood$BINEXT /tmp/9VECAKxQAgBbIgIA ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/HttpFlood$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/HttpFlood$BINEXT; false; fi \

 */

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <pthread.h> /*TODO remove*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if __WIN32
#   include <windows.h>
#endif

#include "Garbage.h"


#define STR_QUOT_(s) #s
#define STR_QUOT(s) STR_QUOT_(s)
#define LOGERR(...) fprintf(stderr, __VA_ARGS__);
#define MUTEX_T pthread_mutex_t
#define MUTEX_INIT pthread_mutex_init
#define MUTEX_LOCK pthread_mutex_lock
#define MUTEX_UNLOCK pthread_mutex_unlock

#if !NDEBUG
#   define REGISTER
#   define LOGDBG(...) fprintf(stderr, __VA_ARGS__);
#else
#   define REGISTER register
#   define LOGDBG(...)
#endif

#define FLG_isHelp (1<<0)


typedef  struct App  App;

/* TODO remove as soon libgarbage is new enough */
//#define Garbage_HttpMsg_Hdr Garbage_HttpClientReq_Hdr


#define App_mAGIC 0x375B0200
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    int port, nclients, pauseMs;
    int numReqDone;
    int printProgressEveryMs;
    struct timespec progressPrintedAt;
    char const *host;
    char const *path;
    char const *mthd;
    struct GarbageEnv **env;
    struct Garbage_ThreadPool **thrdPool;
    struct Garbage_SocketMgr **socketMgr;
    MUTEX_T progressMutx;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


char* strerrname(int);
static void sendAnotherRequest( int, void*app_ );


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  hiddenalphas HTTP load gen utility (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Doh.. Who doesn't know them? Those funny bugs which only happen in\n"
        "  production. Only when enough load is present. At least I had to hunt\n"
        "  a lot of them. Even that tool has lots of imperfections, it still\n"
        "  is a good help to me to reproduce such bugs locally.\n"
        "  \n"
        "  WARN: This is a debugging tool! Do ONLY use it in isolated\n"
        "        environments and on your own risk!\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    --host <ip|hostname>\n"
        "        Eg:  127.0.0.1\n"
        "  \n"
        "    --port <int>\n"
        "        Eg:  8080\n"
        "  \n"
        "    --path <str>\n"
        "        Eg:  /whatever/you/want/to/test\n"
        "  \n"
        "    --nclients <int>\n"
        "        How many clients to emulate. Defaults to 1.\n"
        "  \n"
        "    --pause <int>\n"
        "        Milliseconds to wait after a request has completed before\n"
        "        starting another one. Defaults to 1000ms (aka one second).\n"
        "  \n"
        "    --progress <int>\n"
        "      How often (in seconds) the actual progress should be printed.\n"
        "      Defaults to 3.\n"
        "  \n"
    );
}


static int parseArgs( App*app, int argc, char**argv ){
    REGISTER int iA = 0;
    app->nclients = 1;
    app->pauseMs = 1000;
    app->printProgressEveryMs = 3000;
nextArg:;
    char *arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg, "--host") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        app->host = arg;
    }else if( !strcmp(arg, "--port") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        char *endptr;
        app->port = strtol(arg, &endptr, 0);
        if( endptr == arg || *endptr != '\0' ){ errno = EINVAL; }
        if( errno ){ LOGERR("%s: %s %s\n", strerrname(errno), argv[iA-1], arg); return-1; }
        if( app->port <= 0 || app->port > 0xFFFF ){ LOGERR("ERANGE: port %d\n", app->port); return-1; }
    }else if( !strcmp(arg, "--path") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        app->path = arg;
    }else if( !strcmp(arg, "--nclients") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        char *endptr;
        app->nclients = strtol(arg, &endptr, 0);
        if( endptr == arg || *endptr != '\0' ){ errno = EINVAL; }
        if( errno ){ LOGERR("%s: %s %s\n", strerrname(errno), argv[iA-1], arg); return-1; }
        if( app->nclients < 1 ){ LOGERR("ERANGE: %s %s\n", argv[iA-1], arg); return-1; }
    }else if( !strcmp(arg, "--pause") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        char *endptr;
        app->pauseMs = strtol(arg, &endptr, 0);
        if( endptr == arg || *endptr != '\0' ){ errno = EINVAL; }
        if( errno ){ LOGERR("%s: %s %s\n", strerrname(errno), argv[iA-1], arg); return-1; }
        if( app->pauseMs < 0 ){ LOGERR("ERANGE: --pause %s\n", arg); return-1; }
    }else if( !strcmp(arg, "--progress") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        char *endptr;
        app->printProgressEveryMs = strtol(arg, &endptr, 0);
        if( endptr == arg || *endptr != '\0' ){ errno = EINVAL; }
        if( errno ){ LOGERR("%s: %s %s\n", strerrname(errno), argv[iA-1], arg); return-1; }
        if( app->printProgressEveryMs < 1 ){ LOGERR("ERANGE: --pause %s\n", arg); return-1; }
        if( app->printProgressEveryMs >= INT_MAX/1000 ){ LOGERR("ERANGE: --pause %s\n", arg); return-1; }
        app->printProgressEveryMs *= 1000;
    }else{
        LOGERR("EINVAL: %s\n", arg); return-1;
    }
    goto nextArg;
verify:
    if( argc <= 1 ){ LOGERR("EINVAL: Zero-arg-nonsense. Tell me what you want please.\n"); return -1; }
    if( app->host == NULL ){ LOGERR("EINVAL: --host missing\n"); return-1; }
    if( app->port == 0 ){ LOGERR("EINVAL: --port missing\n"); return-1; }
    if( app->path == NULL ){ LOGERR("EINVAL: --path missing\n"); return-1; }
    return 0;
}


static void onError( int eno, void*mentorCls ){
    LOGDBG("assert(onError() != %s)  %s:%d\n", strerrname(-eno), __FILE__, __LINE__); abort();
}


static void onRspHdr(
    const char*proto, int proto_len, int rspCode, const char*phrase, int phrase_len,
    const struct Garbage_HttpMsg_Hdr*hdrs, int hdrs_cnt,
    struct Garbage_HttpClientReq**req, void*mentorCls
){
    if( rspCode != 200 && rspCode != 404 ){
        LOGDBG("  %.*s %d %.*s\n", proto_len, proto, rspCode, phrase_len, phrase);
        //for( int iH = 0 ; iH < hdrs_cnt ; ++iH ){
        //    LOGDBG("  %.*s: %.*s\n", hdrs[iH].key_len, hdrs[iH].key, hdrs[iH].val_len, hdrs[iH].val);
        //}
    }
}


static void onRspBody( const char*buf, int buf_len, struct Garbage_HttpClientReq**req, void*mentorCls ){
    //LOGDBG("  BodyChunk{ len=%d }\n", buf_len);
}


static void onRspDone( struct Garbage_HttpClientReq**req, void*app_ ){
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    //LOGDBG("  EndOfResponse{}\n");
    (*req)->unref(req);
    err = MUTEX_LOCK(&app->progressMutx); assert(err == 0);
    app->numReqDone += 1;
    err = MUTEX_UNLOCK(&app->progressMutx); assert(err == 0);
    (*app->env)->setTimeoutMs(app->env, app->pauseMs, sendAnotherRequest, app);
}


static void sendAnotherRequest( int eno, void*app_ ){
    assert(eno == 0);
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    //LOGDBG("[TODO ] Use port %d, nclients %d, pauseMs %d, host '%s', path '%s'\n",
    //    app->port, app->nclients, app->pauseMs, app->host, app->path);
    static struct Garbage_HttpClientReq_Mentor mentor = {
        .pushIoTask = NULL,
        .sockAcquire = NULL,
        .sockRelease = NULL,
        .sockSend = NULL,
        .sockFlush = NULL,
        .sockRecv = NULL,
        .onError = onError,
        .onRspHdr = onRspHdr,
        .onRspBody = onRspBody,
        .onRspDone = onRspDone,
    };
    struct Garbage_HttpClientReq **req = NULL;
    req = (*app->env)->newHttpClientReq(app->env, &mentor, app, &(struct Garbage_HttpClientReq_Opts){
        .mthd = app->mthd,
        .host = app->host,
        .url = app->path,
        .port = app->port,
        //struct Garbage_HttpClientReq_Hdr *hdrs;
        //int hdrs_cnt;
    });
    assert(req != NULL);
    (*req)->resume(req);
}


static void periodicallyPrintProgress( int eno, void*app_ ){
    REGISTER int err = eno;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    assert(err == 0);
    err = MUTEX_LOCK(&app->progressMutx); assert(err == 0);
    int numReqDone = app->numReqDone;
    app->numReqDone = 0;
    err = MUTEX_UNLOCK(&app->progressMutx); assert(err == 0);
    struct timespec now;
    err = clock_gettime(CLOCK_REALTIME, &now); assert(err == 0);
    float durationMs = 0;
    durationMs += (now.tv_sec - app->progressPrintedAt.tv_sec) * 1000.f;
    durationMs += (now.tv_nsec - app->progressPrintedAt.tv_nsec) / 1000000.f;
    float donePerSec = (numReqDone) / durationMs * 1000;
    app->progressPrintedAt = now;
    time_t nowEpchSec = time(NULL);
    char nowStr[24];
    err = strftime(nowStr, sizeof nowStr, "%Y-%m-%d_%H:%M:%SZ", gmtime(&nowEpchSec));
    assert(err < sizeof nowStr);
    if( durationMs > 10000000.f ){
        LOGDBG("%s  Let %d clients, all %dms, do '%s %s:%d%s'\n",
            nowStr, app->nclients, app->pauseMs, app->mthd, app->host, app->port, app->path);
    }else{
        LOGDBG("%s  %7d req/sec\n", nowStr, (int)(donePerSec+.99999f));
    }
    (*app->env)->setTimeoutMs(app->env, app->printProgressEveryMs, periodicallyPrintProgress, app_);
}


static void initStuff( void*app_ ){
    #define MIN(a, b) (((a) < (b)) * (a) + ((a) >= (b)) * (b))
    REGISTER int err;
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    err = MUTEX_INIT(&app->progressMutx, NULL); /*TODO unref*/
    assert(err == 0);
    static struct Garbage_ThreadPool_Mentor tpMentorVt = {
        .foo = NULL,
    }, *tpMentor = &tpMentorVt;
    struct Garbage_ThreadPool_Opts tpOpts = {
        /* FIXME Using at least same as nSources for now bcause async io is not yet impl
         * in libgarbage. */
        .numThrds = MIN(1, app->nclients),
    };
    app->thrdPool = (*app->env)->newThreadPool(app->env, &tpMentor, &tpOpts);
    (*app->thrdPool)->start(app->thrdPool);
    app->socketMgr = (*app->env)->newSocketMgr(app->env, &(struct Garbage_SocketMgr_Opts){
        .blockingIoWorker = app->thrdPool,
    });
    periodicallyPrintProgress(0, app);
    for( int i=0 ; i < app->nclients ; ++i ){
        sendAnotherRequest(0, app);
    }
    #undef MIN
}


#if __WIN32
static void initBullshit( void ){
    REGISTER int err;
    WSADATA lpWSAData;
    err = WSAStartup(htons(0x0100), &lpWSAData);
    if( err ){ LOGDBG("%s: WSAStartup()\n", strerrname(err)); abort(); }
}
#endif


int main( int argc, char**argv ){
#if __WIN32
    initBullshit();
#endif
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->mAGIC = App_mAGIC;
    app->exitCode = -1;
    app->mthd = "GET";
    if( parseArgs(app, argc, argv) ){ goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->env = GarbageEnv_ctor(app->envMemory, sizeof app->envMemory);
    assert(app->env != NULL);
    app->exitCode = 0;
    (*app->env)->enqueBlocking(app->env, initStuff, app);
    (*app->env)->runUntilDone(app->env);
    (*app->thrdPool)->joinBlocking(app->thrdPool);
endFn:
    return !!app->exitCode;
    #undef app
}


