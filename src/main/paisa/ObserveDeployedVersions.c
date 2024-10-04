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
  && ${CC:?} -c -o /tmp/gH0AAK5pAACIZwAA src/main/paisa/ObserveDeployedVersions.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/ObserveDeployedVersions$BINEXT /tmp/gH0AAK5pAACIZwAA ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/ObserveDeployedVersions$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/ObserveDeployedVersions$BINEXT; false; fi \

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


typedef  struct App  App;


#define App_mAGIC (int)0x1B400000
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    struct GarbageEnv **env;
    struct Garbage_Mallocator **mallocator;
    struct Garbage_SocketMgr **tlsSocketMgr;
    struct Garbage_HttpClientReq **req;
    int httpRspCode;
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
    fprintf(stdout, "  \n"
        "  %s  " STR_QUOT(PROJECT_VERSION) "\n"
        "  \n"
        "  TODO_PhUAALMDAADGWAAA: Write this help page.\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "      --yolo\n"
        "      WARN: Only use this if you know what you're doing!\n"
        "  \n"
        "", strrchr(__FILE__,'/')+1
    );
}


static int parseArgs( App*app, char**argv ){
    register int iA = 0;
    int isYolo = 0;
nextArg:;
    char *arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg, "--yolo") ){
        isYolo = !0;
    }else{
        LOGERR("EINVAL: %s\n", arg); return-1;
    }
    goto nextArg;
verify:
    if( !isYolo ){ LOGERR("EINVAL: Try --help\n"); return -1; }
    return 0;
}


static void pushIoTask( void(*task)(void*arg), void*arg, void*app_ ){
    App*const app = assert_is_App(app_);
    (*app->env)->enqueBlocking(app->env, task, arg);
}


static void onHttpsError( int retval, void*mentorCls ){
    (void)retval; (void)mentorCls;
    assert(!"TODO_UDUAAB1XAAC3AQAA");
}


static void onHttpRspHdr(
    const char*proto, int proto_len, int rspCode, const char*phrase, int phrase_len,
    const struct Garbage_HttpMsg_Hdr*hdrs, int hdrs_cnt,
    struct Garbage_HttpClientReq**req, void*app_
){
    (void)req;
    App*const app = assert_is_App(app_);
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


static void onHttpRspBody(
    const char*buf, int buf_len, struct Garbage_HttpClientReq**req, void*app_
){
    (void)req;
    App*const app = assert_is_App(app_);
    if( app->httpRspCode != 200 && app->httpRspCode != 404 ){
        LOGDBG("%.*s", buf_len, buf);
        return;
    }
    LOGDBG("TODO_i2gAAKlYAACxbwAA impl %s()\n", __func__);
}


static void onHttpRspDone( struct Garbage_HttpClientReq**req, void*app_ ){
    (void)req; (void)app_;
    //App*const app = assert_is_App(app_);
    //if( app->flg & FLG_printRspBodyAnyway ){
    //    LOGDBG("\n");/*fix broken server which deliver no LF at TEXT body end*/
    //}
    //if( app->httpRspCode == 404 ){
    //    cls->onDone("ENOENT", cls->onDoneArg);
    //    return;
    //}
    //if( app->httpRspCode != 200 ){
    //    cls->onDone("ERROR", cls->onDoneArg);
    //    return;
    //}
    LOGDBG("TODO_tBkAAMhAABgXAAAK: impl %s())\n", __func__);
}


static struct Garbage_HttpClientReq** newHttpsRequest(
    App*app,
    char const*restrict host,
    char const*restrict mthd,
    char const*restrict path
){
    static struct Garbage_HttpClientReq_Mentor reqMentor = {
        .pushIoTask = pushIoTask,
        .onError = onHttpsError,
        .onRspHdr = onHttpRspHdr,
        .onRspBody = onHttpRspBody,
        .onRspDone = onHttpRspDone,
    };
    return (*app->env)->newHttpClientReq(app->env, &reqMentor, app, &(struct Garbage_HttpClientReq_Opts){
        .mallocator = app->mallocator,
        .socketMgr = app->tlsSocketMgr,
        .mthd = mthd,
        .host = host,
        .url = path,
        .port = 443,
        .hdrs_cnt = 0,
        .hdrs = NULL, // struct Garbage_HttpMsg_Hdr *hdrs;
    });
}


static void fetchServiceStatus(
    App*app, char const*restrict svcName, char const*restrict stage,
    void(*onDone)(void*), void*onDoneArg
){
    char *stageLc;
    if(0){}
    else if( !strcmp(stage, "PROD"    ) ){ stageLc = "prod"    ; }
    else if( !strcmp(stage, "PREPROD" ) ){ stageLc = "preprod" ; }
    else if( !strcmp(stage, "INT"     ) ){ stageLc = "int"     ; }
    else if( !strcmp(stage, "TEST"    ) ){ stageLc = "test"    ; }
    else if( !strcmp(stage, "SNAPSHOT") ){ stageLc = "snapshot"; }
    else{ assert(!LOGDBG("EINVAL: %s\n", stage)); /*TODO onDone(error)*/ }
    int const host_cap = 48;
    char host[host_cap];
    int host_end = snprintf(host, host_cap, "isa-houston-%s.isa.aws.pnetcloud.ch", stageLc);
    assert(host_end < host_cap);
    int const path_cap = 64;
    char path[path_cap];
    int path_end = snprintf(path, path_cap, "/houston/services/%s/info", svcName);
    assert(path_end < path_cap);
    assert(app->req == NULL);
    app->req = newHttpsRequest(app, host, "GET", path);
    assert(app->req != NULL);
    (*app->req)->closeSnk(app->req);
    (void)onDone; (void)onDoneArg; // TODO onDone(onDoneArg);
}


static void onFetchServiceStatusDone( void*app_ ){
    (void)app_; //App*const app = assert_is_App(app_);
    LOGDBG("[DEBUG] TODO impl %s()\n", __func__);
}


static void run( void*app_ ){
    App*const app = assert_is_App(app_);
    char const *svcName = "preflux";
    char const *stage = "TEST";
    fetchServiceStatus(app, svcName, stage, onFetchServiceStatusDone, app);
}


/*TODO make this obsolete by using newer lib version, which has an impl itself*/
static void my_realloc(
    struct Garbage_Mallocator**app_,
    void*oldPtr,
    size_t oldPtr_sz,
    size_t newPtr_sz,
    void(*onDone)(int eno, void*newPtr,void*arg),
    void*arg
){
    (void)app_; (void)oldPtr; (void)oldPtr_sz; (void)newPtr_sz; (void)onDone; (void)arg;
    assert(!"TODO_JgYAAPkPAAD1AQAA");
}
static void* onReallocBlocking(
    struct Garbage_Mallocator**app_,
    void*oldPtr,
    size_t oldPtr_sz,
    size_t newPtr_sz
){
    (void)app_; (void)oldPtr_sz;
    return realloc(oldPtr, newPtr_sz);
}
static struct Garbage_Mallocator** newMallocator( void ){
    static struct Garbage_Mallocator vt = {
        .realloc = my_realloc,
        .reallocBlocking = onReallocBlocking,
    }, *globalPimpl = &vt;
    return &globalPimpl;
}


static void initEnv( App*app ){
    app->env = GarbageEnv_ctor(app->envMem, sizeof app->envMem); assert(app->env != NULL);
    app->mallocator = newMallocator();
    app->tlsSocketMgr = NULL; /*TODO need one here*/
}


int main( int argc, char**argv ){
    (void)argc;
    assert((void*)0 == NULL);
    App*const app = &(App){
        .mAGIC = App_mAGIC,
        .exitCode = 1,
    };
    if( parseArgs(app, argv) ){ goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->exitCode = 0;
    initEnv(app);
#if _WIN32
    WSAStartup(1, &(WSADATA){0});
#endif
    (*app->env)->enqueBlocking(app->env, run, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return app->exitCode;
}



