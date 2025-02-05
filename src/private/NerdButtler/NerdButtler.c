#if 0

  && CC=gcc \
  && LD=gcc \
  && ARCH=x86_64-linux-gnu \
  && BINEXT= \
  && LIBSPRE=lib \
  && LIBSEXT=.a \
  && CFLAGS="-Wall -Werror -fmax-errors=1 -O1 -s -Isrc/private/NerdButtler -Iimport/include" \
  && LDFLAGS="-lgarbage -lpthread -Limport/lib" \
  \
  && rm -rf "build/${ARCH:?}/bin/NerdButtler${BINEXT?}" \
  && tar c src/private/NerdButtler \
     | ssh "${vm:?}" -T 'cd garb && rm -rf src && tar x' \
  && ssh "${vm:?}" -t 'cd garb \
     && mkdir -p build/'${ARCH:?}'/bin \
     && '${CC:?}' -c -o /tmp/qujXMSXIeM06EKHj src/private/NerdButtler/NerdButtler.c '"${CFLAGS?} -DEXPOSE_NerdButtler_main=1"' \
     && '${CC:?}' -o build/'${ARCH:?}'/bin/NerdButtler'${BINEXT?}' /tmp/qujXMSXIeM06EKHj '"${LDFLAGS?}"' \
     && true' \
  && rm -rf "build/${ARCH:?}/bin/*" \
  && ssh "${vm:?}" -T 'cd garb && tar c build/'${ARCH:?}'/bin' | tar x \

#endif

#include <NerdButtler_Private.h>

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#include <Garbage_Bootstrap.h>

#define FLG_isSrcClosed (1<<0)
#define FLG_isRspInProgress (1<<1)


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
    ptrdiff_t envMem[SIZEOF_struct_Garbage_Env/sizeof(ptrdiff_t)];
    struct Garbage_Env **env;
    struct Garbage_Mallocator **mallocator;
    struct Garbage_HttpServer **httpServer;
    struct Garbage_HttpServer_StepCtx httpServerStepCtx;
    struct Garbage_SocketMgr **socketMgr;
    struct Garbage_ThreadPool **ioThreadPool;
    struct Garbage_IoMultiplexer **ioMultiplexer;
    struct HttpReqHandler httpReqHandlers[2];
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
};


TPL_assert_is(App, obj->mAGIC == App_mAGIC)
#define assert_is_App(p) assert_is_App(p, __FILE__, __LINE__)

TPL_assert_is(HttpClient, obj->mAGIC == HttpClient_mAGIC)
#define assert_is_HttpClient(p) assert_is_HttpClient(p, __FILE__, __LINE__)

TPL_assert_is(HttpReqHandler, obj->mAGIC == HttpReqHandler_mAGIC)
#define assert_is_HttpReqHandler(p) assert_is_HttpReqHandler(p, __FILE__, __LINE__)


static void noopVoid(){/*no-op*/}


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
        MALLOCATOR_REALLOC(httpClient->app->mallocator, httpClient, sizeof httpClient, 0);
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
        HttpClient*const httpClient = MALLOCATOR_REALLOC(app->mallocator, NULL, 0, sizeof*httpClient);
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
            .onHttpRequestHeader = Http418_onHttpRequestHeader,
        },{
            .onHttpRequestHeader = NULL, /*end-marker*/
        }},
    };
    err = initApp(app);  assert(!err);
    (*app->env)->enqueBlocking(app->env, run, app);
    (*app->env)->runUntilDone(app->env);
    assert(app->exitCode >= 0); assert(app->exitCode <= 0x7F);
    return app->exitCode;
}


#if EXPOSE_NerdButtler_main
int main( int argc, char**argv ){ return NerdButtler_main(argc, argv); }
#endif

