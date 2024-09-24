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
#define REGISTER /*no-op*/

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
    char *rspBody;
    int rspBody_cap, rspBody_end;
    struct GarbageEnv **env;
    struct Garbage_TlsClient **tlsClient;
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
    Cls*const cls = cls_; assert_is_Cls(cls_);
    App*const app = assert_is_App(cls->app);
    (*app->env)->enqueBlocking(app->env, task, arg);
}


static void HttpReq_onError( int retval, void*mentorCls ){
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
    if( rspCode == 200 ){
        /*no debug output needed*/
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
    static struct Garbage_TlsClient_Mentor tlsMentor = {
        .pushIoTask = TlsClientMentor_pushIoTask,
        .onError = TlsClientMentor_onError,
    };
    app->tlsClient = (*app->env)->newTlsClient(app->env,
        &tlsMentor, app, &(struct Garbage_TlsClient_Opts){
            .peerHostname = peerHostname,
            //.mallocator = NULL,
            //.socketMgr = NULL,
            //.ioWorker = NULL,
        }
    );
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
    //LOGDBG("[DEBUG] GET %s\n", url);
    req = (*app->env)->newHttpClientReq(app->env, &httpMentor, cls,
        &(struct Garbage_HttpClientReq_Opts){
            //.mallocator = NULL,
            .socketMgr = (*app->tlsClient)->asSocketMgr(app->tlsClient),
            .mthd = "GET",
            .host = peerHostname,
            .url = url,
            .port = 443,
            .hdrs_cnt = (app->cookie == NULL) ? 0 : 1,
            .hdrs = ((struct Garbage_HttpMsg_Hdr[]){{
                .key = "Cookie", .key_len = 6,
                .val = app->cookie, .val_len = (app->cookie == NULL ? 0 : strlen(app->cookie)),
            }}),
        });
    (*req)->resume(req);
}

#undef Cls_mAGIC
#undef Cls
#undef assert_is_Cls


static void onBuildStatusAvailable( char const*buildStatus, void*app_ ){
    (void)app_; //App*const app = assert_is_App(app_);
    printf("%s\n", buildStatus);
}


static void run( void*app_ ){
    App*const app = assert_is_App(app_);
    TODO_refactorMeToAProperApi(app, onBuildStatusAvailable, app);
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
    app->env = GarbageEnv_ctor(app->envMem, sizeof app->envMem);
    (*app->env)->enqueBlocking(app->env, run, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}


