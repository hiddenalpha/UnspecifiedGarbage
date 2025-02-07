#if 0

  && outBinDir=build/${ARCH:?}/bin \
  && CC=gcc \
  && LD=gcc \
  && ARCH=x86_64-linux-gnu \
  && BINEXT= \
  && LIBSPRE=lib \
  && LIBSEXT=.a \
  && CFLAGS="-Wall -Werror -fmax-errors=1 -O1 -s -Isrc/private/NerdButtler -Iimport/include -DPROJECT_VERSION=$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && LDFLAGS="-lgarbage -lpthread -Limport/lib" \
  \
  && rm -rf "build/${ARCH:?}/bin/NerdButtler${BINEXT?}" \
  && tar c src/private/NerdButtler \
     | ssh "${vm:?}" -T 'cd garb && rm -rf src && tar x' \
  && ssh "${vm:?}" -t 'cd garb \
     && mkdir -p build/'${ARCH:?}'/bin build/'${ARCH:?}'/obj \
     && '${CC:?}' -c -o build/'${ARCH:?}'/obj/private/NerdButtler/NerdButtler.c src/private/NerdButtler/NerdButtler.c '"${CFLAGS?} -DEXPOSE_NerdButtler_main=1"' \
     && '${LD:?}' -o build/'${ARCH:?}'/bin/NerdButtler'${BINEXT?}' build/'${ARCH:?}'/obj/private/NerdButtler/NerdButtler.c '"${LDFLAGS?}"' \
     && true' \
  && rm -rf "build/${ARCH:?}/bin/*" \
  && ssh "${vm:?}" -T 'cd garb/build/'${ARCH:?}'/bin' | (cd "${outBinDir:?}" && tar x) \

#endif

#include <NerdButtler_Private.h>

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if _WIN32
#   include <winsock2.h>
#   include <windows.h>
#else
#   include <sys/socket.h>
#   include <arpa/inet.h>
#endif

#include <Garbage_Bootstrap.h>

#define FLG_isHelp (1<<0)
#define FLG_isSrcClosed (1<<1)
#define FLG_isRspInProgress (1<<2)

typedef  struct App  App;
typedef  struct HttpClient  HttpClient;
typedef  struct HttpReqHandler  HttpReqHandler;


#define HttpReqHandler_mAGIC 0x0BF2974B
struct HttpReqHandler {
    unsigned mAGIC;
    int (*onHttpRequestHeader)( HttpClient*httpClient );
    void (*onHttpMessageEnd)( HttpClient*httpClient ); /*NULLable*/
};


#define App_mAGIC 0xBC5A4F47
struct App {
    unsigned mAGIC;
    unsigned flg;
    int exitCode;
    char *webroot;
    ptrdiff_t envMem[SIZEOF_struct_Garbage_Env/sizeof(ptrdiff_t)];
    struct Garbage_Env **env;
    struct Garbage_Mallocator **mallocator;
    struct Garbage_HttpServer **httpServer;
    struct Garbage_HttpServer_StepCtx httpServerStepCtx;
    struct Garbage_SocketMgr **socketMgr;
    struct Garbage_ThreadPool **ioThreadPool;
    struct Garbage_IoMultiplexer **ioMultiplexer;
    struct HttpReqHandler httpReqHandlers[3];
};


#define HttpClient_mAGIC 0x916A1469
struct HttpClient {
    unsigned mAGIC;
    unsigned flg;
    App *app;
    struct Garbage_HttpServer_Client **handle;
    struct Garbage_HttpServer_Client_StepCtx stepCtx;
    struct/*current-request*/{
        int iReqHandler; /* idx of the request handler, which is handling the request */
        int onHttpMessageEnd_state;
        int eno;
    };
    struct/*webroot handler*/{
        FILE *fh;
        int webroot_state;
        int webroot_eno;
        char const *webroot_mime, *webroot_chrst;
        char *webrootBuf;
        int webrootBuf_cap, webrootBuf_len;
    };
};


TPL_assert_is(App, obj->mAGIC == App_mAGIC)
#define assert_is_App(p) assert_is_App(p, __FILE__, __LINE__)

TPL_assert_is(HttpClient, obj->mAGIC == HttpClient_mAGIC)
#define assert_is_HttpClient(p) assert_is_HttpClient(p, __FILE__, __LINE__)

TPL_assert_is(HttpReqHandler, obj->mAGIC == HttpReqHandler_mAGIC)
#define assert_is_HttpReqHandler(p) assert_is_HttpReqHandler(p, __FILE__, __LINE__)


static void noopVoid(){/*no-op*/}


static void printHelp( char const*arg0 ){
    printf("  \n"
        "  %s  " STR_QUOT(PROJECT_VERSION) "\n"
        "  \n"
        "  Usage:\n"
        "    %s  options...\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    --webroot <path>\n"
        "        Path where to serve requests from, which do not match\n"
        "        otherwise. Can be useful to serve static assets like a\n"
        "        webapp.\n"
        "  \n"
        "  \n", strrchr(__FILE__,'/')+1, strrchr(arg0,'/')+1);
}


static int parseArgs( App*const app, int argc, char**argv ){
    REGISTER int iA = 0;
    app->webroot = NULL;
nextArg:;
    char *arg = argv[++iA];
    if( !arg ){
        goto verify;
    }else if( !strcmp(arg,"--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg,"--webroot") ){
        app->webroot = argv[++iA];
        /* normalize, that it ALWAYS ends with '/' */
        int webroot_len = strlen(app->webroot);
        if( app->webroot[webroot_len-1] != '/' ){
            static char mem[PATH_MAX+1];
            /*TODO err=*/snprintf(mem, sizeof mem, "%.*s/", webroot_len, app->webroot);
            app->webroot = mem;
        }
    }else{
        LOGE("EINVAL: %s\n", arg); return -1;
    }
    goto nextArg;
verify:
    if( argc <= 1 ){ LOGE("EINVAL: Too few args. Try --help\n"); return-1; }
    if( !app->webroot ){ LOGW("[WARN ] No webroot given. UI won't be available.\n"); }
    return 0;
}


static void guessMimeByFileExt(
    char const*path, int path_len, char const**mime, char const**charset
){
    char const *ext = path + path_len;
    for(; ext -1 > path && ext[-1] != '.' ; --ext );
    int const ext_len = path_len - (ext - path);
    if( !strncasecmp("HTML", ext, ext_len) ){ *mime = "text/html";  *charset = "utf-8";  return; }
    if( !strncasecmp("CSS", ext, ext_len) ){ *mime = "text/css";  *charset = "utf-8";  return; }
    if( !strncasecmp("JS", ext, ext_len) ){
        *mime = "application/javascript";  *charset = "utf-8";  return; }
    if( !strncasecmp("JSON", ext, ext_len) ){
        *mime = "application/json";  *charset = "utf-8";  return; }
    LOGD("NoMimeFor: '%.*s'\n", path_len, path);
    *mime = NULL;  *charset = NULL;
}


static void HttpWebroot_continueServingOpenedFile( HttpClient* );
static void f48amiHOXCmp8YpZu( int eno, void*httpClient_ ){
    HttpClient*const httpClient = assert_is_HttpClient(httpClient_);
    httpClient->webroot_eno = eno;
    HttpWebroot_continueServingOpenedFile(httpClient_);
}
static void HttpWebroot_continueServingOpenedFile( HttpClient*httpClient ){
    #define CORO_STATE (httpClient->webroot_state)
    #define CORO_GOTO(S) do{CORO_STATE=S;goto S;}while(0)
    REGISTER int err;
    enum { begin=0, sM4psQzMaIHDCENAd, sibOSBcQKz0qxTlPs, sk9HYMmhgSBi1dWeK, endOfFile, };
    switch( CORO_STATE ){case begin:{
        char contentType[64];
        int contentType_len;
        if( httpClient->webroot_mime && httpClient->webroot_chrst ){
            contentType_len = snprintf(contentType, sizeof contentType, "%s;charset=%s",
                httpClient->webroot_mime, httpClient->webroot_chrst);
        }else if( httpClient->webroot_mime ){
            contentType_len = snprintf(contentType, sizeof contentType, "%s",
                httpClient->webroot_mime);
        }else{
            contentType_len = 24;
            memcpy(contentType, "application/octet-stream", contentType_len+1);
        }
        assert(contentType_len < (int)sizeof contentType);
        struct Garbage_HttpMsg_Hdr hdrs[] = {{
            .key = "Transfer-Encoding", .val = "chunked",
            .key_len = 17, .val_len = 7,
        },{
            .key = "Content-Type", .val = contentType,
            .key_len = 12, .val_len = contentType_len,
        }};
        CORO_STATE = sM4psQzMaIHDCENAd;
        HTTPCLIENT_SENDHTTPHDR(httpClient->handle, NULL, 200, NULL, hdrs, sizeof hdrs/sizeof*hdrs,
            f48amiHOXCmp8YpZu, httpClient);
        return;
    }case sM4psQzMaIHDCENAd:sM4psQzMaIHDCENAd:{
        if( httpClient->webroot_eno < 0 ){
            LOGD("%s: %s:%d\n", strerrname(-httpClient->webroot_eno), __FILE__, __LINE__); abort();
        }
        #define BUF (httpClient->webrootBuf)
        #define BUF_LEN (httpClient->webrootBuf_len)
        #define BUF_CAP (httpClient->webrootBuf_cap)
        if( BUF_CAP < 8192 ){
            size_t const oldSz = BUF_CAP;
            BUF_CAP = 8192;
            void *tmp = MALLOCATOR_REALLOCBLOCKING(httpClient->app->mallocator,
                BUF, oldSz*sizeof*BUF, BUF_CAP*sizeof*BUF);
            if( !tmp ){ assert(!"TODO_IjPJwl8thttTS6ci"); }
            BUF = tmp;
        }
        CORO_STATE = sibOSBcQKz0qxTlPs;
        IOMULTIPLEXER_READ(httpClient->app->ioMultiplexer, BUF, 1, BUF_CAP, httpClient->fh,
            f48amiHOXCmp8YpZu, httpClient);
        return;
    }case sibOSBcQKz0qxTlPs:{
        if( httpClient->webroot_eno < 0 ){ /*ERROR*/
            assert(!"TODO_Xme47BSVE4roVZlI");
        }
        if( httpClient->webroot_eno == 0){ /*EOF*/
            CORO_STATE = endOfFile;
            HTTPCLIENT_SENDBODY(httpClient->handle, NULL, 0, 4, f48amiHOXCmp8YpZu, httpClient);
            return;
        }
        assert(httpClient->webroot_eno > 0);
        BUF_LEN = httpClient->webroot_eno;
        int const IS_LAST = 4;
        CORO_STATE = sk9HYMmhgSBi1dWeK;
        HTTPCLIENT_SENDBODY(httpClient->handle, BUF, BUF_LEN, 0, f48amiHOXCmp8YpZu, httpClient);
        return;
    }case sk9HYMmhgSBi1dWeK:{
        if( httpClient->webroot_eno < 0 ){
            LOGD("%s: %s:%d\n", strerrname(-httpClient->webroot_eno), __FILE__, __LINE__); abort();
        }
        assert(httpClient->webroot_eno == BUF_LEN);
        /* loop back to read next chunk */
        httpClient->webroot_eno = 0;
        CORO_GOTO(sM4psQzMaIHDCENAd);
    }case endOfFile:{
        if( httpClient->webroot_eno < 0 ){
            LOGE("%s: %s:%d\n", strerrname(-httpClient->webroot_eno), __FILE__, __LINE__); abort();
        }
        err = fclose(httpClient->fh);  httpClient->fh = NULL;
        if( err ){
            LOGD("%s: fclose(httpClient->fh) %s:%d\n", strerrname(errno), __FILE__, __LINE__);
            /*continue anyway*/
        }
        httpClient->flg &= ~FLG_isRspInProgress;
        CORO_STATE = 0;
        HTTPCLIENT_RESUME(httpClient->handle);
        return;
        #undef BUF
        #undef BUF_LEN
        #undef BUF_CAP
    }}
    LOGD("assert(s != %d)  %s:%d\n", CORO_STATE, __FILE__, __LINE__); abort();
    #undef CORO_STATE
    #undef CORO_GOTO
}


static int HttpWebroot_onHttpRequestHeader( HttpClient*httpClient ){
    #define REQHDR (&httpClient->stepCtx.reqHdr)
    REGISTER int err;
    App*const app = assert_is_App(httpClient->app);
    if( !app->webroot ) return -ENOTSUP; /*no dir given we could serve from*/
    if( strncmp("GET", REQHDR->mthd, REQHDR->mthd_len) ) return -ENOTSUP;
    assert(app->webroot[strlen(app->webroot)-1] == '/');
    assert(REQHDR->path_len > 0);
    char *path = REQHDR->path;
    int path_len = REQHDR->path_len;
    if( path[0] == '/' ){ path += 1; path_len -= 1; }
    /*cut-off query*/
    for( err = 0 ; err < path_len ; ++err ){
        if( path[err] == '?' ){ path_len = err; break; }
    }
    guessMimeByFileExt(path, path_len, &httpClient->webroot_mime, &httpClient->webroot_chrst);
    char pathAbs[PATH_MAX+1];
    int const pathAbs_len = snprintf(pathAbs, sizeof pathAbs, "%s%.*s",
        app->webroot, path_len, path);
    /* TODO make async! */
    assert(pathAbs[pathAbs_len] == '\0');
    FILE *fh = fopen(pathAbs, "rb");
    if( !fh ){ /*nothing we could serve*/
        LOGD("ENOENT: %.*s\n", pathAbs_len, pathAbs);
        return -ENOTSUP;
    }
    httpClient->fh = fh;
    HTTPCLIENT_PAUSE(httpClient->handle); /*prevent problems with pipelining*/
    assert(httpClient->webroot_state == 0);
    HttpWebroot_continueServingOpenedFile(httpClient);
    return 0;
    #undef REQHDR
}


static void fmtCshCEVvN22FwbW( int eno, void*httpClient_ ){
    if( eno < 0 ){ LOGD("%s: httpClient:sendRaw()\n", strerrname(-eno)); }
    HttpClient*const httpClient = assert_is_HttpClient(httpClient_);
    assert(httpClient->flg & FLG_isRspInProgress);
    httpClient->flg &= ~FLG_isRspInProgress;
    HTTPCLIENT_RESUME(httpClient->handle);
}


static int Http418_onHttpRequestHeader( HttpClient*httpClient ){
    #define REQHDR (&httpClient->stepCtx.reqHdr)
    #define IS_MSG_END 4
    /* pause, to prevent (potential) problems with pipelining */
    HTTPCLIENT_PAUSE(httpClient->handle);
    static char msg[] = ""
        "HTTP/1.1 418 I'm A Teapod\r\n"
        "Content-Type: text/html; charset=utf-8\r\n"
        "Content-Length: 24\r\n"
        "\r\n"
        "<h1>Teapod says hi</h1>\n";
    int const msg_len = (sizeof msg)-1;
    HTTPCLIENT_SENDRAW(httpClient->handle, msg, msg_len, IS_MSG_END, fmtCshCEVvN22FwbW, httpClient);
    /*
     * this is a catch-all handler, so it will accept EVERY request */
    return 0; /* 0=WillHandleThisRequest */
    #undef REQHDR
    #undef IS_MSG_END
}


static void onHttpRequestHeader( HttpClient*httpClient ){
    REGISTER int err;
    /**/
    assert(!(httpClient->flg & FLG_isRspInProgress));
    httpClient->flg |= FLG_isRspInProgress;
    /**/
    #define REQHDR (&httpClient->stepCtx.reqHdr)
    httpClient->iReqHandler = 0;
askNextRequestHandler:
    httpClient->iReqHandler += 1;
    App*const app = assert_is_App(httpClient->app);
    #define REQHDLR (app->httpReqHandlers + httpClient->iReqHandler - 1/*previous*/)
    assert(REQHDLR->onHttpRequestHeader && "app config is broken. NO HttpReqHandler wants to handle this request");
    err = REQHDLR->onHttpRequestHeader(httpClient);
    #undef REQHDLR
    if( err == -ENOTSUP ){
        /* handler does NOT want to handle this one */
        goto askNextRequestHandler;
    }
    if( err == 0 ){
        /* handler WILL handle this request */
        return;
    }
    assert(!"TODO_aWOMTWSzi6ZV45uf");
    #undef REQHDR
}


static void onHttpMessageEnd( void* );
// UNUSED static void onHttpMessageEnd_IV( int eno, void*httpClient_ ){
// UNUSED     HttpClient*const httpClient = assert_is_HttpClient(httpClient_);
// UNUSED     httpClient->eno = eno;
// UNUSED     onHttpMessageEnd(httpClient_);
// UNUSED }
static void onHttpMessageEnd( void*httpClient_ ){
    REGISTER int err;
    HttpClient*const httpClient = assert_is_HttpClient(httpClient_);
    App*const app = assert_is_App(httpClient->app);
    /* delegate to responsible handler */
    #define REQHDLR (app->httpReqHandlers + httpClient->iReqHandler)
    if( REQHDLR->onHttpMessageEnd ){ /*bcause this cback is optional*/
        REQHDLR->onHttpMessageEnd(httpClient);
    }
    #undef REQHDLR
#if 0 /* vv-- OBSOLETE */
    static char const *const rspBody = "Git nüüt ds gugge hie :)\n";
    #define CORO_STATE (httpClient->onHttpMessageEnd_state)
    enum { begin=0, sGK9YdOh9Wg8Wk5xL, stvA6avryUmn9fnQM, sPzZrabRvyjtBNQU0 };
    switch( CORO_STATE ){case begin:{
        ///* pause, to prevent problems with overtaking requests */
        //HTTPCLIENT_PAUSE(httpClient->handle);
        int const rspBody_len = strlen(rspBody);
        char rspBody_lenStr[8];
        err = snprintf(rspBody_lenStr, sizeof rspBody_lenStr, "%d", rspBody_len);
        assert(err < sizeof rspBody_lenStr);
        struct Garbage_HttpMsg_Hdr hdrs[] = {{
            .key = "Content-Length", .val = rspBody_lenStr,
            .key_len = 14, .val_len = strlen(rspBody_lenStr),
        },{
            .key = "Content-Type", .val = "text/plain; charset=utf-8",
            .key_len = 12, .val_len = 25,
        }};
        CORO_STATE = stvA6avryUmn9fnQM;
        HTTPCLIENT_SENDHTTPHDR(httpClient->handle, NULL, 418, NULL, hdrs, sizeof hdrs/sizeof*hdrs,
            onHttpMessageEnd_IV, httpClient);
        return;
    }case stvA6avryUmn9fnQM:{
        err = httpClient->eno;
        if( err < 0 ){
            /* TODO WhereTheFu** is this EIO coming from? */
            LOGW("[WARN ] %s: send(httpClient, rspHdr)\n", strerrname(-err));
            err = 0;
        }
        assert(err == 0);
        int const isEndOfMsg = 4;
        CORO_STATE = sPzZrabRvyjtBNQU0;
        HTTPCLIENT_SENDBODY(httpClient->handle, rspBody, strlen(rspBody), isEndOfMsg, onHttpMessageEnd_IV, httpClient);
        return;
    }case sPzZrabRvyjtBNQU0:{
        err = httpClient->eno;
        if( err < 0 ){
            LOGW("%s: send(httpClient, emptyRspBody)\n", strerrname(-err));
            assert(!"TODO_ZEijoIFoHOOA5NLO");
        }
        CORO_STATE = 0; /*reset for next request*/
        assert(httpClient->flg & FLG_isRspInProgress);
        httpClient->flg &= ~FLG_isRspInProgress;
        HTTPCLIENT_RESUME(httpClient->handle);
        return;
    }}
    LOGD("assert(coroState != %d)\n", CORO_STATE); abort();
#endif
    #undef CORO_STATE
}


static void onHttpClientSrcEof( HttpClient*const httpClient ){
    httpClient->flg |= FLG_isSrcClosed;
}


static void continueOnHttpClient( void*httpClient_ ){
    REGISTER int err;
    HttpClient*const httpClient = assert_is_HttpClient(httpClient_);
    App*const app = assert_is_App(httpClient->app);
    err = HTTPCLIENT_STEP(httpClient->handle, &httpClient->stepCtx);
    if( err == -EWOULDBLOCK ){
        /* TODO eliminate busy waiting! */
        err = HTTPCLIENT_WAITUNTIL(httpClient->handle, 1, 0);
        if( err == 0 || err == -ETIMEDOUT ){
            ENV_ENQUEBLOCKING(app->env, continueOnHttpClient, httpClient);
            return;
        }
        assert(!"TODO_K36jfYEdCpl8oAY3");
    }
    /* inspect event if any */
    if( err == 1 ) switch( httpClient->stepCtx.type ){
    case GARBAGE_HTTPSERVER_CLIENT_REQHDR: onHttpRequestHeader(httpClient); break;
    case GARBAGE_HTTPSERVER_CLIENT_MSGEND: onHttpMessageEnd(httpClient); break;
    case GARBAGE_HTTPSERVER_CLIENT_SRCTCPFIN: onHttpClientSrcEof(httpClient); break;
    default: LOGD("assert(httpClient.stepCtx.type != %d)\n", httpClient->stepCtx.type); abort();
    }
    /**/
    assert_is_HttpClient(httpClient);
    int const isSrcClosed = httpClient->flg & FLG_isSrcClosed;
    int const isRspInProgress = httpClient->flg & FLG_isRspInProgress;
    if( isSrcClosed && !isRspInProgress ){
        int const SHUTDOWN = 2;
        HTTPCLIENT_SENDRAW(httpClient->handle, NULL, 0, SHUTDOWN, noopVoid, NULL);
        httpClient->mAGIC = 0;
        HTTPCLIENT_UNREF(httpClient->handle);
        MALLOCATOR_REALLOCBLOCKING(httpClient->app->mallocator, httpClient, sizeof httpClient, 0);
    }else{
        ENV_ENQUEBLOCKING(app->env, continueOnHttpClient, httpClient);
    }
}


static void runHttpServer( void*app_ ){
    REGISTER int err;
    App*const app = assert_is_App(app_);
continueServer:
    err = HTTPSERVER_RUNUNTILPAUSE(app->httpServer, &app->httpServerStepCtx);
    if( err == -EWOULDBLOCK ){ goto waitForServerEvents; }
    if( err == 1 ){
        HttpClient*const httpClient = MALLOCATOR_REALLOCBLOCKING(
            app->mallocator, NULL, 0, sizeof*httpClient);
        if( !httpClient ){ assert(!"TODO_tCoYwHTuw9ulzvyT"); }
        *httpClient = (HttpClient){
            .mAGIC = HttpClient_mAGIC,
            .app = app,
            .handle = app->httpServerStepCtx.newClient,
        };
        HTTPCLIENT_SETCTX(app->httpServerStepCtx.newClient, httpClient);
        continueOnHttpClient(httpClient);
        goto continueServer;
    }
    LOGE("httpServer: %s\n", app->httpServerStepCtx.errDetail);
    assert(!"TODO_HPlzpL91n02qa2iG");
waitForServerEvents:
    /* TODO get rid of UGLY busywaiting */
    err = HTTPSERVER_WAITUNTIL(app->httpServer, 1, 0);
    if( err == -ETIMEDOUT ){
        ENV_ENQUEBLOCKING(app->env, runHttpServer, app);
        return;
    }
    assert(!"TODO_pqWOwBjJqPUtXyl4");
}


static void run( void*cls_ ){
    App*const app = assert_is_App(cls_);
    LOGD("App says hi from %s()\n", __func__);
    runHttpServer(app);
}


static int initApp( App*const app ){
    app->mallocator = Garbage_newMallocator();  assert(app->mallocator);
    app->env = Garbage_newEnv(&(struct Garbage_Env_Opts){
        .memBlockToUse = app->envMem,
        .memBlockToUse_sz = sizeof app->envMem,
        .mallocator = app->mallocator,
    });  assert(app->env);
    app->ioThreadPool = Garbage_newThreadPool(&(struct Garbage_ThreadPool_Opts){
        .mallocator = app->mallocator,
        .numThrds = 4,
    }); assert(app->ioThreadPool);
    app->ioMultiplexer = Garbage_newIoMultiplexer(app->env, &(struct Garbage_IoMultiplexer_Opts){
        .mallocator = app->mallocator,
    }); assert(app->ioMultiplexer);
    app->socketMgr = Garbage_newSocketMgr(app->env, &(struct Garbage_SocketMgr_Opts){
        .mallocator = app->mallocator,
        .ioMultiplexer = app->ioMultiplexer,
        .blockingIoWorker = app->ioThreadPool,
        .reuseaddr = 1, /*TODO*/
    }); assert(app->socketMgr);
    app->httpServer = Garbage_newHttpServer(&(struct Garbage_HttpServer_Opts){
        .mallocator = app->mallocator,
        .socketMgr = app->socketMgr,
        .sockaddr_len = sizeof(struct sockaddr_in),
        .sockaddr = (&(struct sockaddr_in){
            .sin_family = AF_INET,
            .sin_port = htons(8080),
            .sin_addr.s_addr = inet_addr("127.0.0.1"),
        }),
        //.backlog = ,
    }); assert(app->httpServer);
    /**/
    THREADPOOL_START(app->ioThreadPool);
    IOMULTIPLEXER_START(app->ioMultiplexer);
    return 0;
}


int NerdButtler_main( int argc, char**argv ){
    REGISTER int err;
    App*const app = &(App){
        .mAGIC = App_mAGIC,
        .httpReqHandlers = {{
            .onHttpRequestHeader = HttpWebroot_onHttpRequestHeader,
        },{
            .onHttpRequestHeader = Http418_onHttpRequestHeader,
        },{
            .onHttpRequestHeader = NULL, /*end-marker*/
        }},
    };
    if( parseArgs(app, argc, argv) ) return 1;
    if( app->flg & FLG_isHelp ){ printHelp(argv[0]); return 0; }
    err = initApp(app);  assert(!err);
    (*app->env)->enqueBlocking(app->env, run, app);
    (*app->env)->runUntilDone(app->env);
    assert(app->exitCode >= 0); assert(app->exitCode <= 0x7F);
    return app->exitCode;
}


#if EXPOSE_NerdButtler_main
int main( int argc, char**argv ){ return NerdButtler_main(argc, argv); }
#endif

