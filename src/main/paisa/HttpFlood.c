/*

  && CC=gcc \
  && LD=gcc \
  && OBJDUMP=objdump \
  && BINEXT= \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-lcustom_pthread,-dy,-lws2_32,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/9VECAKxQAgBbIgIA src/main/paisa/HttpFlood.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/HttpFlood$BINEXT /tmp/9VECAKxQAgBbIgIA ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/HttpFlood$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/HttpFlood$BINEXT; false; fi \

 */

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h> /*TODO remove*/

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


#define App_mAGIC 0x375B0200
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    int numThrds;
    int port, maxParallel, interReqGapMs;
    char const *host;
    char const *path;
    struct GarbageEnv **env;
    struct Garbage_ThreadPool **thrdPool;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


char* strerrname(int);


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  hiddenalphas HTTP load gen utility (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    --host <ip|hostname>\n"
        "        Eg:  127.0.0.1\n"
        "  \n"
        "    --port <int>\n"
        "        Eg:  7013\n"
        "  \n"
        "    --path <str>\n"
        "        Eg:  /houston/services/nullsink\n"
        "  \n"
        "    --max-parallel <int>\n"
        "        Defaults to 1.\n"
        "  \n"
        "    --inter-request-gap <int>\n"
        "        Milliseconds to wait before starting another request when the\n"
        "        previous one has ended. Defaults to 1000ms (aka one second).\n"
        "  \n"
    );
}


static int parseArgs( App*app, int argc, char**argv ){
    REGISTER int iA = 0;
    app->maxParallel = 1;
    app->interReqGapMs = 1000;
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
        app->port = strtol(arg, NULL, 0);
        if( errno ){ LOGERR("%s: %s\n", strerrname(errno), arg); return-1; }
        if( app->port <= 0 || app->port > 0xFFFF ){ LOGERR("ERANGE: port %d\n", app->port); return-1; }
    }else if( !strcmp(arg, "--path") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        app->path = arg;
    }else if( !strcmp(arg, "--max-parallel") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        app->maxParallel = strtol(arg, NULL, 0);
        if( errno ){ LOGERR("%s: %s\n", strerrname(errno), arg); return-1; }
        if( app->maxParallel < 1 ){ LOGERR("ERANGE: --max-parallel %s\n", arg); return-1; }
    }else if( !strcmp(arg, "--inter-request-gap") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        app->interReqGapMs = strtol(arg, NULL, 0);
        if( errno ){ LOGERR("%s: %s\n", strerrname(errno), arg); return-1; }
        if( app->interReqGapMs < 1 ){ LOGERR("ERANGE: --inter-request-gap %s\n", arg); return-1; }
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


static void pushIoTask( void(*task)(void*arg), void*arg, void*cls ){
    assert(!"TODO_LCYCANB3AgBUHQIA");
}


static void sockAcquire( void*sockaddr, int sockaddr_len, void*mentorCls, void(*onDone)(int retval, void*sock, void*arg), void*arg ){
    assert(!"TODO_VycCAEpaAgC0CgIA");
}


static void sockRelease( void*sock, int mustClose, void*mentorCls ){
    assert(!"TODO_");
}


static void sockSend( void*sock, const void*buf, int buf_len, void*mentorCls, void(*onDone)(int retval, void*arg), void*arg ){
    assert(!"TODO_");
}


static void sockFlush( void*sock, void*mentorCls, void(*onDone)(int,void*arg), void*arg ){
    assert(!"TODO_");
}


static void sockRecv( void*sock, void*buf, int buf_len, void*mentorCls, void(*onDone)(int,void*arg), void*arg ){
    assert(!"TODO_");
}


static void onError( int eno, void*mentorCls ){
    assert(!"TODO_");
}


static void onRspHdr( const char*proto, int proto_len, int rspCode, const char*phrase, int phrase_len, const struct Garbage_HttpClientReq_Hdr*hdrs, int hdrs_cnt, struct Garbage_HttpClientReq**req, void*mentorCls ){
    assert(!"TODO_");
}


static void onRspBody( const char*buf, int buf_len, struct Garbage_HttpClientReq**req, void*mentorCls ){
    assert(!"TODO_");
}


static void onRspDone( struct Garbage_HttpClientReq**req, void*mentorCls ){
    assert(!"TODO_");
}


static void TODO_bRACABpaAgDDXAIA( void*app_ ){
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    LOGDBG("[TODO ] Use port %d, maxParallel %d, interReqGapMs %d, host '%s', path '%s'\n",
        app->port, app->maxParallel, app->interReqGapMs, app->host, app->path);
    static struct Garbage_HttpClientReq_Mentor mentor = {
        .pushIoTask = pushIoTask,
        .sockAcquire = sockAcquire,
        .sockRelease = sockRelease,
        .sockSend = sockSend,
        .sockFlush = sockFlush,
        .sockRecv = sockRecv,
        .onError = onError,
        .onRspHdr = onRspHdr,
        .onRspBody = onRspBody,
        .onRspDone = onRspDone,
    };
    struct Garbage_HttpClientReq_Opts opts = {
        .mthd = "GET",
        .host = app->host,
        .url = app->path,
        .port = app->port,
        //struct Garbage_HttpClientReq_Hdr *hdrs;
        //int hdrs_cnt;
    };
    (void)mentor; (void)opts;
    //struct Garbage_HttpClientReq **req = NULL;
    //req = (*app->env)->newHttpClientReq(app->env, &mentor, app, &opts);
    //(*req)->resume(req);
    app->exitCode = -1;
}


static void initStuff( void*app_ ){
    #define MIN(a, b) (((a) < (b)) * (a) + ((a) >= (b)) * (b))
    App*const app = app_; assert(app->mAGIC == App_mAGIC);
    static struct Garbage_ThreadPool_Mentor tpMentorVt = {
        .foo = NULL,
    }, *tpMentor = &tpMentorVt;
    struct Garbage_ThreadPool_Opts tpOpts = {
        /* TODO MIN(MAX(1, numSrc), 32). Using at least same as nSources for now to
         * prevent deadlocks due to libgarbage having very short task queues. */
        .numThrds = app->numThrds,
    };
    app->thrdPool = (*app->env)->newThreadPool(app->env, &tpMentor, &tpOpts);
    (*app->thrdPool)->start(app->thrdPool);
    (*app->env)->enqueBlocking(app->env, TODO_bRACABpaAgDDXAIA, app);
    #undef MIN
}


int main( int argc, char**argv ){
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->mAGIC = App_mAGIC;
    app->numThrds = 4;
    app->exitCode = -1;
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


