#if 0

  20250606: Seems broken. Try "NerdButtler.c" (with source-patch) instead.

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

#define Garbage_Closure void*
#include <Garbage.h>
#include <Garbage_Bootstrap.h>


#define STR_QUOT_(s) #s
#define STR_QUOT(s) STR_QUOT_(s)
#define LOGDBG(...) fprintf(stderr, __VA_ARGS__)
#define LOGERR(...) fprintf(stderr, __VA_ARGS__)
#define LOGT(...) fprintf(stderr, __VA_ARGS__)
#define REGISTER /*no-op*/

#define Env_enqueBlocking(A, B, C) (*A)->enqueBlocking(A, B, C)
#define ThreadPool_enque(A, B, C) (*A)->enque(A, B, C)
#define TlsClient_asSocketMgr(A) (*A)->asSocketMgr(A)

#define FLG_isHelp (1<<0)
#define FLG_printRspBodyAnyway (1<<1)


typedef  struct App  App;


#define App_mAGIC (signed)0x88180200
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    int httpRspCode;
    char *serviceName;
    char *branchName;
    char *cookie;
    /**/
    struct Garbage_Env **env;
    struct Garbage_Mallocator **mallocator;
    struct Garbage_TlsClient **tlsClient;
    struct Garbage_SocketMgr **socketMgr;
    struct Garbage_ThreadPool **ioWorker;
    struct Garbage_IoMultiplexer **ioMultiplexer;
    struct Garbage_Networker **networker;
    /**/
    char *rspBody;
    int rspBody_cap, rspBody_end;
    /**/
    void *envMem[SIZEOF_struct_Garbage_Env/sizeof(void*)];
};


static struct Garbage_TlsClient** newTlsClient( App*, char const* );


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
        "  Options:\n"
        "  \n"
        "      --service <str>\n"
        "      Service name in question (eg 'slarti').\n"
        "  \n"
        "      --branch <str>\n"
        "      Branch name in question (eg 'feature-SDCISA-42-foobar').\n"
        "  \n"
        "      --cookie <str>\n"
        "      This tool does not support any auth mechanism. A cookie header can\n"
        "      be provided here. For example one copied from an established\n"
        "      browser session or similar. This already works for some auth\n"
        "      mechanisms.\n"
        "  \n"
    );
}


static int parseArgs( App*app, char**argv ){
    assert(app->serviceName == NULL);
    register int iA = 0;
nextArg:;
    char *arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg, "--service") ){
        app->serviceName = argv[++iA];
        if( app->serviceName == NULL ){ LOGERR("EINVAL: %s needs value\n", arg); return-1; }
    }else if( !strcmp(arg, "--branch") ){
        app->branchName = argv[++iA];
        if( app->branchName == NULL ){ LOGERR("EINVAL: %s needs value\n", arg); return-1; }
    }else if( !strcmp(arg, "--cookie") ){
        app->cookie = argv[++iA];
        if( app->cookie == NULL ){ LOGERR("EINVAL: %s needs value\n", arg); return-1; }
    }else{
        LOGERR("EINVAL: %s\n", arg); return-1;
    }
    goto nextArg;
verify:
    if( app->serviceName == NULL ){ LOGERR("EINVAL: --service missing\n"); return -1; }
    if( app->branchName == NULL ){ LOGERR("EINVAL: --branch missing\n"); return -1; }
    return 0;
}


#define Cls_mAGIC (signed)0x0E2C0000
#define Cls struct { \
    int mAGIC; \
    App *app; \
    void (*onDone)(char const*restrict,void*); \
    void *onDoneArg; \
}
#define assert_is_Cls(p) assert(p && ((Cls*)p)->mAGIC == Cls_mAGIC)

static void HttpReq_pushIoTask( void(*task)(void*arg), void*arg, void*cls_ ){
    LOGT("[TRACE] %s()\n", __func__);
    Cls*const cls = cls_; assert_is_Cls(cls_);
    App*const app = assert_is_App(cls->app);
    ThreadPool_enque(app->ioWorker, task, arg);
}


static void HttpReq_onError( int retval, void*mentorCls ){
    (void)retval; (void)mentorCls;
    LOGDBG("[DEBUG] %s(eno=%d)\n", __func__, retval);
}


static void HttpReq_onRspHdr(
    const char*proto, int proto_len, int rspCode, const char*phrase, int phrase_len,
    const struct Garbage_HttpMsg_Hdr*hdrs, int hdrs_cnt,
    struct Garbage_HttpClientReq**req, void*cls_
){
    Cls*const cls = cls_; assert_is_Cls(cls_);
    App*const app = assert_is_App(cls->app);
    app->httpRspCode = rspCode;
    if(0){
    }else if( rspCode == 200 ){
        /*no debug output needed*/
        //LOGDBG("%.*s %d %.*s\n", proto_len, proto, rspCode, phrase_len, phrase);
    }else if( rspCode == 401 || rspCode == 404 ){
        /*short output is enough*/
        LOGDBG("%.*s %d %.*s\n", proto_len, proto, rspCode, phrase_len, phrase);
    }else{ /*unexpected, Log more*/
        LOGDBG("%.*s %d %.*s\n", proto_len, proto, rspCode, phrase_len, phrase);
        for( int i = 0 ; i < hdrs_cnt ; ++i ){
            LOGDBG("%.*s: %.*s\n", hdrs[i].key_len, hdrs[i].key, hdrs[i].val_len, hdrs[i].val);
        }
        LOGDBG("\n");
    }
}


static void HttpReq_onRspBody(
    const char*buf, int buf_len, struct Garbage_HttpClientReq**req, void*cls_
){
    Cls*const cls = cls_; assert_is_Cls(cls_);
    App*const app = assert_is_App(cls->app);
    if( app->httpRspCode != 200 && app->httpRspCode != 404 ){
        LOGDBG("%.*s", buf_len, buf);
        return;
    }
    if( app->flg & FLG_printRspBodyAnyway ){
        LOGDBG("%.*s", buf_len, buf);
    }
    if( app->rspBody_cap - app->rspBody_end < buf_len ){
        app->rspBody_cap += buf_len;
        void *tmp = realloc(app->rspBody, app->rspBody_cap*sizeof*app->rspBody);
        if( tmp == NULL ){ assert(!"TODO_0GgAAAF8AACMaAAA ENOMEM"); }
        app->rspBody = tmp;
    }
    memcpy(app->rspBody + app->rspBody_end, buf, buf_len);
    app->rspBody_end += buf_len;
}


static void HttpReq_onRspDone( struct Garbage_HttpClientReq**req, void*cls_ ){
    Cls*const cls = cls_; assert_is_Cls(cls_);
    App*const app = assert_is_App(cls->app);
    if( app->flg & FLG_printRspBodyAnyway ){
        LOGDBG("\n");/*fix broken server which deliver no LF at TEXT body end*/
    }
    if( app->httpRspCode == 404 ){
        cls->onDone("ENOENT", cls->onDoneArg);
        return;
    }
    if( app->httpRspCode != 200 ){
        cls->onDone("ERROR", cls->onDoneArg);
        return;
    }
    assert(app->rspBody != NULL);
    int const isRunning = strstr(app->rspBody, "\"state\":\"running\"") != NULL;
    int const isFail = strstr(app->rspBody, "\"state\":\"failure\"") != NULL;
    if( isRunning ){
        cls->onDone("running", cls->onDoneArg);
    }else if( isFail ){
        cls->onDone("failure", cls->onDoneArg);
    }else{
        cls->onDone("OK", cls->onDoneArg);
    }
}


static void TlsClientMentor_pushIoTask( void(*task)(void*arg), void*arg, void*cls_ ){ assert(!"TODO_4WgAAI8UAACIdQAA"); }
static void TlsClientMentor_onError( int eno, void*cls_ ){ assert(!"TODO_gxsAAMspAABkYgAA"); }


/*
 * @param onDone
 *     Called with one of: "running", "failure", "OK".
 */
static void TODO_refactorMeToAProperApi(
    App*app_, void(*onDone)(char const*restrict state,void*arg), void*arg
){
    REGISTER int err;
    App*const app = assert_is_App(app_);
    static char const*const peerHostname = "jenkinspaisa-temp.tools.pnet.ch";
    assert(app->tlsClient == NULL);
    assert(onDone != NULL);
    Cls *cls = malloc(1*sizeof*cls);
    assert(cls != NULL);
    cls->mAGIC = Cls_mAGIC;
    cls->app = app;
    cls->onDone = onDone;
    cls->onDoneArg = arg;
    app->tlsClient = newTlsClient(app, peerHostname);
    struct Garbage_HttpClientReq **req = NULL;
    static struct Garbage_HttpClientReq_Mentor httpMentor = {
        .pushIoTask = HttpReq_pushIoTask,
        .onError = HttpReq_onError,
        .onRspHdr = HttpReq_onRspHdr,
        .onRspBody = HttpReq_onRspBody,
        .onRspDone = HttpReq_onRspDone,
    };
    assert(5*sizeof(void*) == sizeof httpMentor);
    #define SPACE (url_cap - (it - url))
    int const url_cap = 256;
    char url[url_cap];
    char *it = url;
    err = snprintf(it, SPACE, "/job/"); it += err; assert(err == 5);
    err = snprintf(it, SPACE, "%s", app->serviceName); it += err; assert(err == (signed)strlen(app->serviceName));
    err = snprintf(it, SPACE, "/job/"); it += err; assert(err == 5);
    err = snprintf(it, SPACE, "%s", app->branchName); it += err; assert(err == (signed)strlen(app->branchName));
    err = snprintf(it, SPACE, "/lastBuild/pipeline-graph/tree"); it += err; assert(err == 30);
    #undef SPACE
    int const port = 443;
    LOGDBG("[DEBUG] GET %s:%d%s\n", peerHostname, port, url);
    req = Garbage_newHttpClientReq(app->env, &httpMentor, cls,
        &(struct Garbage_HttpClientReq_Opts){
            .mallocator = app->mallocator,
            .ioWorker = app->ioWorker,
            .networker = app->networker,
            .socketMgr = TlsClient_asSocketMgr(app->tlsClient),
            .mthd = "GET",
            .host = peerHostname,
            .url = url,
            .port = port,
            .hdrs_cnt = (app->cookie) ? 1 : 0,
            .hdrs = ((struct Garbage_HttpMsg_Hdr[]){{
                .key = "Cookie"   , .key_len = 6,
                .val = app->cookie, .val_len = (app->cookie == NULL ? 0 : strlen(app->cookie)),
            }}),
        });
    (*req)->resume(req);
    (*req)->closeSnk(req);
}

#undef Cls_mAGIC
#undef Cls
#undef assert_is_Cls


static void onBuildStatusAvailable( char const*buildStatus, void*app_ ){
    (void)app_; //App*const app = assert_is_App(app_);
    printf("%s\n", buildStatus);
}


static struct Garbage_TlsClient** newTlsClient( App*app, char const*peerHostname ){
    struct Garbage_TlsClient **tls;
    static struct Garbage_TlsClient_Mentor tlsMentor = {
        .pushIoTask = TlsClientMentor_pushIoTask,
        .onError = TlsClientMentor_onError,
    };
    assert(app->mallocator); assert(app->socketMgr); assert(app->ioWorker);
    tls = Garbage_newTlsClient(app->env, &tlsMentor, app, &(struct Garbage_TlsClient_Opts){
        .peerHostname = peerHostname,
        .mallocator = app->mallocator,
        .socketMgr = app->socketMgr,
        .ioWorker = app->ioWorker,
    });
    assert(tls);
    return tls;
}


static void run( void*app_ ){
    App*const app = assert_is_App(app_);
    TODO_refactorMeToAProperApi(app, onBuildStatusAvailable, app);
}


static void initApp( App*app ){
    app->mallocator = Garbage_newMallocator(); assert(app->mallocator);
    app->env = Garbage_newEnv(&(struct Garbage_Env_Opts){
        .memBlockToUse = app->envMem,
        .memBlockToUse_sz = sizeof app->envMem,
        .mallocator = app->mallocator,
    }); assert(app->env);
    app->ioWorker = Garbage_newThreadPool(&(struct Garbage_ThreadPool_Opts){
        .mallocator = app->mallocator,
        .numThrds = 8, /* TODO use environ.IO_THRD_CNT */
    }); assert(app->ioWorker);
    app->ioMultiplexer = Garbage_newIoMultiplexer(app->env, &(struct Garbage_IoMultiplexer_Opts){
        .mallocator = app->mallocator,
        .ioWorker = app->ioWorker,
    }); assert(app->ioMultiplexer);
    app->networker = Garbage_newNetworker(&(struct Garbage_Networker_Opts){
        .mallocator = app->mallocator,
        .ioWorker = app->ioWorker,
    }); assert(app->networker);
    app->socketMgr = Garbage_newSocketMgr(app->env, &(struct Garbage_SocketMgr_Opts){
        .mallocator = app->mallocator,
        .ioMultiplexer = app->ioMultiplexer,
        .blockingIoWorker = app->ioWorker,
        .reuseaddr = 1,
    }); assert(app->socketMgr);
    assert(app->socketMgr);
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
    //app->flg |= FLG_printRspBodyAnyway;
    initApp(app);
    (*app->env)->enqueBlocking(app->env, run, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}


