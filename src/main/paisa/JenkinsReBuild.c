#if 0

  && HOST_=x86_64-w64-mingw32- \
  && CC=${HOST_}gcc \
  && LD=${HOST_}gcc \
  && OBJDUMP=${HOST_}objdump \
  && BINEXT=.exe \
  && CFLAGS="-Wall -Werror -Wextra -pedantic -fmax-errors=3 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-l:libwinpthread.a,-dy,-lws2_32,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/rBcCAJFNAgDObAIA src/main/paisa/JenkinsReBuild.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/JenkinsReBuild$BINEXT /tmp/rBcCAJFNAgDObAIA ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/JenkinsReBuild$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/JenkinsReBuild$BINEXT; false; fi \

#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>
#if _WIN32
#   include <windows.h>
#endif

#include <Garbage.h>


#define STR_QUOT_(s) #s
#define STR_QUOT(s) STR_QUOT_(s)
#define LOGDBG(...) fprintf(stderr, __VA_ARGS__)
#define LOGERR(...) fprintf(stderr, __VA_ARGS__)

#define FLG_isHelp (1<<0)


typedef  struct App  App;


#define App_mAGIC (signed)0x88180200
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    struct GarbageEnv **env;
    void *envMem[SIZEOF_struct_GarbageEnv/sizeof(void*)];
};


static inline struct App* assert_is_App( void*p, char const*f, int l ){
#if !NDEBUG
    if( p == NULL ){ LOGDBG("assert(app != NULL)  %s:%d\n", f, l); assert(0); }
    App *a = p;
    if( a->mAGIC != App_mAGIC ){
        LOGDBG("assert(app.mAGIC != %d)  %s:%d\n", a->mAGIC, f, l); assert(0); }
#endif
    return p;
}
#define assert_is_App(p) assert_is_App(p, __FILE__, __LINE__)


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  JenkinsReBuild (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Fights annoying just-trigger-another-build workaround.\n"
        "  \n"
    );
}


static int parseArgs( App*app, char**argv ){
    register int iA = 0;
nextArg:;
    char *arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else{
        LOGERR("EINVAL: %s\n", arg); return-1;
    }
    goto nextArg;
verify:
    //if( argc <= 1 ){ LOGERR("EINVAL: Zero-arg-nonsense. Tell me what you want please.\n"); return -1; }
    return 0;
}


static void HttpReq_pushIoTask( void(*task)(void*arg), void*arg, void*app_ ){
    App*const app = assert_is_App(app_);
    (*app->env)->enqueBlocking(app->env, task, arg);
}


static void HttpReq_onError( int retval, void*mentorCls ){
    LOGDBG("[DEBUG] %s(eno=%d)\n", __func__, retval);
}


static void HttpReq_onRspHdr(
    const char*proto, int proto_len, int rspCode, const char*phrase, int phrase_len,
    const struct Garbage_HttpMsg_Hdr*hdrs, int hdrs_cnt,
    struct Garbage_HttpClientReq**req, void*app_
){
    //App*const app = assert_is_App(app_);
    if( rspCode != 200 ){
        LOGDBG("%.*s %d %.*s\n", proto_len, proto, rspCode, phrase_len, phrase);
        for( int i = 0 ; i < hdrs_cnt ; ++i ){
            LOGDBG("%.*s: %.*s\n", hdrs[i].key_len, hdrs[i].key, hdrs[i].val_len, hdrs[i].val);
        }
        LOGDBG("\n");
    }
}


static void HttpReq_onRspBody(
    const char*buf, int buf_len, struct Garbage_HttpClientReq**req, void*app_
){
    //App*const app = assert_is_App(app_);
    // TODO if( httpRspCode != 200 ){
        LOGDBG("%.*s", buf_len, buf);
    // TODO }
}


static void HttpReq_onRspDone( struct Garbage_HttpClientReq**req, void*app_ ){
    LOGDBG("[DEBUG] TODO_FlsAAAwZAADIHgAA %s()\n", __func__);
}


static void run( void*app_ ){
    App*const app = assert_is_App(app_);
    struct Garbage_HttpClientReq **req = NULL;
    static struct Garbage_HttpClientReq_Mentor httpMentor = {
        .pushIoTask = HttpReq_pushIoTask,
        .onError = HttpReq_onError,
        .onRspHdr = HttpReq_onRspHdr,
        .onRspBody = HttpReq_onRspBody,
        .onRspDone = HttpReq_onRspDone,
    };
    assert(5*sizeof(void*) == sizeof httpMentor);
    req = (*app->env)->newHttpClientReq(app->env, &httpMentor, app,
        &(struct Garbage_HttpClientReq_Opts){
            //.mallocator = NULL,
            //.socketMgr = NULL,
            .mthd = "GET",
            .host = "127.0.0.1",
            .url = "/guguseli/gagageli",
            .port = 8081,
            //.hdrs = struct Garbage_HttpMsg_Hdr*,
            //.hdrs_cnt = int,
        });
    (*req)->resume(req);
}


int main( int argc, char**argv ){
#if _WIN32
    WSAStartup(1, &(WSADATA){0});
#endif
    (void)argc;
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->mAGIC = App_mAGIC;
    app->exitCode = -1;
    if( parseArgs(app, argv) ){ goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->exitCode = 0;
    app->env = GarbageEnv_ctor(app->envMem, sizeof app->envMem);
    (*app->env)->enqueBlocking(app->env, run, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}


