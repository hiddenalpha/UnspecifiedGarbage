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


struct Cls4B5C0000/*HttpJenkinsStatus*/{
    unsigned mAGIC;
    int coroState;
    HttpClient *httpClient;
    int eno;
    char *buf;
    int buf_len;
    char buildResult[16];
    int buildResult_len;
};


struct ClsE8750000/*getJenkinsBuildStatus*/{
    unsigned mAGIC;
    int coroState;;
    int eno, childExit, childSig;
    App *app;
    struct Garbage_Process **child;
    void (*onDone)(char*,int,void*);
    void *onDoneArg;
    char flip[65536], flop[65536];
    int flip_len, flop_len;
};


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
    int httpPort;
    char *webroot;
    char *jenkinsCookie;
    ptrdiff_t envMem[SIZEOF_struct_Garbage_Env/sizeof(ptrdiff_t)];
    struct Garbage_Env **env;
    struct Garbage_Mallocator **mallocator;
    struct Garbage_HttpServer **httpServer;
    struct Garbage_HttpServer_StepCtx httpServerStepCtx;
    struct Garbage_SocketMgr **socketMgr;
    struct Garbage_ThreadPool **ioThreadPool;
    struct Garbage_Networker **networker;
    struct Garbage_IoMultiplexer **ioMultiplexer;
    struct Garbage_ProcessFactory **processFactory;
    struct HttpReqHandler httpReqHandlers[4];
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
        "    --port <int>\n"
        "        Port for the webserver to listen on.\n"
        "  \n"
        "    --webroot <path>\n"
        "        Path where to serve requests from, which do not match\n"
        "        otherwise. Can be useful to serve static assets like a\n"
        "        webapp.\n"
        "  \n"
        "    --cookie <str>\n"
        "        This client does not yet have any way of auth. This can help\n"
        "        for jenkins requests with session riding for now.\n"
        "        Not yet sure which cookies are really needed. Did work with\n"
        "        those:\n"
        "        ittrksessid=...; JSESSIONID.AAA=...; JSESSIONID.BBB=...;\n"
        "        mod_auth_openidc_session=...;\n"
        "  \n", strrchr(__FILE__,'/')+1, arg0);
}


static int parseArgs( App*const app, int argc, char**argv ){
    REGISTER int iA = 0;
    int isHttpPort =  0;
    app->webroot = NULL;
nextArg:;
    char *arg = argv[++iA];
    if( !arg ){
        goto verify;
    }else if( !strcmp(arg,"--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg,"--port") ){
        int const port = strtol(argv[++iA], NULL, 0);
        if( port < 1 || port > 0xFFFF ){ LOGE("EINVAL: %s %s\n", arg, argv[iA]); return-1; }
        app->httpPort = port;
        isHttpPort = 1;
    }else if( !strcmp(arg,"--webroot") ){
        app->webroot = argv[++iA];
        /* normalize, that it ALWAYS ends with '/' */
        int webroot_len = strlen(app->webroot);
        if( app->webroot[webroot_len-1] != '/' ){
            static char mem[PATH_MAX+1];
            /*TODO err=*/snprintf(mem, sizeof mem, "%.*s/", webroot_len, app->webroot);
            app->webroot = mem;
        }
    }else if( !strcmp(arg,"--cookie") ){
        app->jenkinsCookie = argv[++iA];
        if( !app->jenkinsCookie ){ LOGE("EINVAL: %s needs value\n", arg); return-1; }
    }else{
        LOGE("EINVAL: %s\n", arg); return -1;
    }
    goto nextArg;
verify:
    if( argc <= 1 ){ LOGE("EINVAL: Too few args. Try --help\n"); return-1; }
    if( !app->webroot ){ LOGW("[WARN ] No webroot given. UI won't be available.\n"); }
    if( !isHttpPort ){
        app->httpPort = 8080; LOGW("[WARN ] --port missing. Fallback to %d\n", app->httpPort); }
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


static void appendToFlip( const char*buf, int buf_len, void*cls_ ){
    #define BUF (cls->flip)
    #define BUF_CAP ((signed)sizeof cls->flip)
    #define BUF_LEN (cls->flip_len)
    struct ClsE8750000*const cls = cls_; assert(cls->mAGIC == 0xE8750000);
    if( buf_len > 0 ){
        if( BUF_CAP <= BUF_LEN + buf_len ){
            LOGD("assert(%d > %d) %s:%d\n", BUF_CAP, BUF_LEN + buf_len, __FILE__, __LINE__); abort();
        }
        memcpy(BUF + BUF_LEN, buf, buf_len);
        BUF_LEN += buf_len;
    }
    #undef BUF
    #undef BUF_CAP
    #undef BUF_LEN
}


static void appendToFlop( const char*buf, int buf_len, void*cls_ ){
    #define BUF (cls->flop)
    #define BUF_CAP ((signed)sizeof cls->flop)
    #define BUF_LEN (cls->flop_len)
    struct ClsE8750000*const cls = cls_; assert(cls->mAGIC == 0xE8750000);
    if( buf_len > 0 ){
        if( BUF_CAP <= BUF_LEN + buf_len ){
            LOGD("assert(%d > %d) %s:%d\n", BUF_CAP, BUF_LEN + buf_len, __FILE__, __LINE__); abort();
        }
        memcpy(BUF + BUF_LEN, buf, buf_len);
        BUF_LEN += buf_len;
    }
    #undef BUF
    #undef BUF_CAP
    #undef BUF_LEN
}


static void getJenkinsBuildStatus_kontinue( void* );
static void fs3gAADBZAADUNgAA( int err, void*cls_){
    struct ClsE8750000*const cls = cls_; assert(cls->mAGIC == 0xE8750000);
    cls->eno = err;
    getJenkinsBuildStatus_kontinue(cls);
}
static void fIxIAALgAAA0SwAAa( int err, int exitCode, int sigNum, void*cls_ ){
    struct ClsE8750000*const cls = cls_; assert(cls->mAGIC == 0xE8750000);
    cls->eno = err;
    cls->childExit = exitCode;
    cls->childSig = sigNum;
    getJenkinsBuildStatus_kontinue(cls);
}
static void getJenkinsBuildStatus_kontinue( void*cls_ ){
    /* TODO replace this sub process mess by proper http client */
    REGISTER int err;
    struct ClsE8750000*const cls = cls_; assert(cls->mAGIC == 0xE8750000);
    App*const app = assert_is_App(cls->app);
    char const *host = "jenkinspaisa-temp.tools.pnet.ch";
    char const *svcName = "preflux";
    char const *prName = "PR-893";
    #define CORO_STATE (cls->coroState)
    enum { begin=0, srx8AAH84AAD8LwAA, skE4AAIxKAADyQAAA, sAT4AADZCAAAiTgAA, sQk0AAENdAADiPQAA,
        sPkIAAIhbAACrDQAA, suhoAACw0AAAXMwAA, };
    switch( CORO_STATE ){case begin:{
    }/* need to get the job number bcause 'latest' is not valid :( */{
        char url[512];
        err = snprintf(url, sizeof url, "https://%s/job/%s/job/%s/api/json", host, svcName, prName);
        assert(err < (signed)sizeof url);
        char cookieHdr[768];
        err = snprintf(cookieHdr, sizeof cookieHdr, "Cookie: %s", app->jenkinsCookie);
        assert(err < (signed)sizeof url);
        if( cls->child ){ (*cls->child)->unref(cls->child); }
        cls->flip_len = 0;
        CORO_STATE = srx8AAH84AAD8LwAA;
        cls->child = (*app->processFactory)->newProcess(app->processFactory, &(struct Garbage_Process_Mentor){
            .cls = cls,
            .usePathSearch = 1,
            .argv = (char*[]){"curl", "-sS", "-H", cookieHdr, url, NULL},
            .onStdout = appendToFlip,
            .onJoined = fIxIAALgAAA0SwAAa,
        });
        (*cls->child)->closeSnk(cls->child);
        (*cls->child)->join(cls->child, 5000);
        return;
    }case srx8AAH84AAD8LwAA:{
        if( cls->eno || cls->childExit || cls->childSig ){
            LOGD("assert(!%d && !%d && !%d) %s:%d\n",
                cls->eno, cls->childExit, cls->childSig, __FILE__, __LINE__);
            abort();
        }
        if( cls->child ){ (*cls->child)->unref(cls->child); }
        cls->flop_len = 0;
        CORO_STATE = skE4AAIxKAADyQAAA;
        cls->child = (*app->processFactory)->newProcess(
            app->processFactory, &(struct Garbage_Process_Mentor){
                .cls = cls,
                .usePathSearch = 1,
                .argv = (char*[]){"jq", ".lastBuild.number", NULL},
                .onStdout = appendToFlop,
                .onJoined = fIxIAALgAAA0SwAAa,
            });
        #define BUF (cls->flip)
        #define BUF_LEN (cls->flip_len)
        (*cls->child)->write(cls->child, BUF, BUF_LEN, fs3gAADBZAADUNgAA, cls);
        return;
    }case skE4AAIxKAADyQAAA:{
        if( cls->eno != BUF_LEN ){
            LOGD("assert(!%d) %s:%d\n", cls->eno, __FILE__, __LINE__); abort(); }
        CORO_STATE = sAT4AADZCAAAiTgAA;
        (*cls->child)->closeSnk(cls->child);
        (*cls->child)->join(cls->child, 2000);
        return;
    }case sAT4AADZCAAAiTgAA:{
        if( cls->eno || cls->childExit || cls->childSig ){
            if( cls->childExit == 4 ){ /*jq parsing error (likely auth issue with curl?)*/
                LOGD("\n[DEBUG] Input was:\n%.*s\n", MIN(BUF_LEN, 2048), BUF); abort();
            }
            LOGD("assert(!%d && !%d && !%d) %s:%d\n",
                cls->eno, cls->childExit, cls->childSig, __FILE__, __LINE__);
            abort();
        }
        #undef BUF
        #undef BUF_LEN
        #define BUF (cls->flop)
        #define BUF_LEN (cls->flop_len)
        if( BUF_LEN <= 0 || BUF_LEN > 5 ){
            LOGD("assert(!%d) %s:%d\n", BUF_LEN, __FILE__, __LINE__); abort();
        }
        BUF[BUF_LEN] = '\0';
        char *end;
        int const buildNr = strtol(BUF, &end, 10);
        if( end - BUF == 0 ){
            LOGD("assert(%lld > 0) %s:%d\n", end - BUF, __FILE__, __LINE__); abort();
        }
        LOGD("buildNr := %d\n", buildNr);
        #undef BUF
        #undef BUF_LEN
        char url[512];
        err = snprintf(url, sizeof url, "https://%s/job/%s/job/%s/%d/api/json",
            host, svcName, prName, buildNr);
        assert(err < (signed)sizeof url);
        char cookieHdr[768];
        err = snprintf(cookieHdr, sizeof cookieHdr, "Cookie: %s", app->jenkinsCookie);
        assert(err < (signed)sizeof url);
        if( cls->child ){ (*cls->child)->unref(cls->child); }
        cls->flip_len = 0;
        CORO_STATE = sQk0AAENdAADiPQAA;
        cls->child = (*app->processFactory)->newProcess(
            app->processFactory, &(struct Garbage_Process_Mentor){
                .cls = cls,
                .usePathSearch = 1,
                .argv = (char*[]){"curl", "-sS", "-H", cookieHdr, url, NULL},
                .onStdout = appendToFlip,
                .onJoined = fIxIAALgAAA0SwAAa,
            });
        (*cls->child)->closeSnk(cls->child);
        (*cls->child)->join(cls->child, 5000);
        return;
    }case sQk0AAENdAADiPQAA:{
        if( cls->eno || cls->childExit || cls->childSig ){
            LOGD("assert(!%d && !%d && !%d) %s:%d\n",
                cls->eno, cls->childExit, cls->childSig, __FILE__, __LINE__);
            abort();
        }
        if( cls->child ){ (*cls->child)->unref(cls->child); }
        cls->flop_len = 0;
        CORO_STATE = sPkIAAIhbAACrDQAA;
        cls->child = (*app->processFactory)->newProcess(
            app->processFactory, &(struct Garbage_Process_Mentor){
                .cls = cls,
                .usePathSearch = 1,
                .argv = (char*[]){"jq", ".result", NULL},
                .onStdout = appendToFlop,
                .onJoined = fIxIAALgAAA0SwAAa,
            });
        #define BUF (cls->flip)
        #define BUF_LEN (cls->flip_len)
        (*cls->child)->write(cls->child, BUF, BUF_LEN, fs3gAADBZAADUNgAA, cls);
        return;
    }case sPkIAAIhbAACrDQAA:{
        if( cls->eno != BUF_LEN ){
            LOGD("assert(!%d) %s:%d\n", cls->eno, __FILE__, __LINE__); abort(); }
        CORO_STATE = suhoAACw0AAAXMwAA;
        (*cls->child)->closeSnk(cls->child);
        (*cls->child)->join(cls->child, 2000);
        return;
        #undef BUF
        #undef BUF_LEN
    }case suhoAACw0AAAXMwAA:{
        #define BUF (cls->flop)
        #define BUF_LEN (cls->flop_len)
        if( cls->eno || cls->childExit || cls->childSig ){
            LOGD("assert(!%d && !%d && !%d) %s:%d\n",
                cls->eno, cls->childExit, cls->childSig, __FILE__, __LINE__);
            abort();
        }
        if( BUF_LEN <= 0 || BUF_LEN > 32 ){
            LOGD("assert(!%d) %s:%d\n", BUF_LEN, __FILE__, __LINE__); abort();
        }
        BUF[BUF_LEN] = '\0';
        int beg = 0, end = BUF_LEN;
        if( BUF_LEN >= 2 && BUF[0] == '"' ){
            beg += 1;
            for( end = beg + 1 ; end < BUF_LEN ; ++end ){ if( BUF[end] == '"' ) break; }
        }
        cls->onDone(BUF + beg, end - beg, cls->onDoneArg);
        cls->mAGIC = 0;
        MALLOCATOR_REALLOCBLOCKING(app->mallocator, cls, sizeof*cls, 0);
        return;
        #undef BUF
        #undef BUF_LEN
    }}
    LOGD("assert(s != %d) %s:%d\n", CORO_STATE, __FILE__, __LINE__); abort();
    #undef CORO_STATE
}

static void getJenkinsBuildStatus( void*cls_, void(*onDone)(char*,int,void*), void*onDoneArg ){
    assert(onDone);
    App*const app = assert_is_App(cls_);
    struct ClsE8750000 *cls;
    cls = MALLOCATOR_REALLOCBLOCKING(app->mallocator, NULL, 0, sizeof*cls);
    if( !cls ){ assert(!"TODO_cg0AAHhJAADBBwAA"); }
    *cls = (struct ClsE8750000){
        .mAGIC = 0xE8750000,
        .app = app,
        .onDone = onDone,
        .onDoneArg = onDoneArg,
    };
    getJenkinsBuildStatus_kontinue(cls);
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
            LOGF("%s: %s:%d\n", strerrname(-httpClient->webroot_eno), __FILE__, __LINE__); abort();
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
        IOMULTIPLEXER_READ(httpClient->app->ioMultiplexer, BUF, 1, BUF_CAP,
            (ptrdiff_t)httpClient->fh, f48amiHOXCmp8YpZu, httpClient);
        return;
    }case sibOSBcQKz0qxTlPs:{
        if( httpClient->webroot_eno < 0 ){ /*ERROR*/
            LOGE("%s(%d): file:read()\n", strerrname(-httpClient->webroot_eno), httpClient->webroot_eno);
            abort();
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
            LOGF("%s: %s:%d\n", strerrname(-httpClient->webroot_eno), __FILE__, __LINE__); abort();
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
            LOGW("%s: fclose(httpClient->fh) %s:%d\n", strerrname(errno), __FILE__, __LINE__);
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



static void HttpJenkinsStatus_kontinue( void* );
static void fzAEAAHdDAABNcQAA( char*buf, int buf_len, void*cls_ ){
    struct Cls4B5C0000*const cls = cls_; assert(cls->mAGIC == 0x4B5C0000);
    cls->buf = buf;
    cls->buf_len = buf_len;
    HttpJenkinsStatus_kontinue(cls);
}
static void fFyoAANUaAADfcQAA( int eno, void*cls_ ){
    struct Cls4B5C0000*const cls = cls_; assert(cls->mAGIC == 0x4B5C0000);
    cls->eno = eno;
    HttpJenkinsStatus_kontinue(cls);
}
static void HttpJenkinsStatus_kontinue( void*cls_ ){
    REGISTER int err;
    struct Cls4B5C0000*const cls = cls_; assert(cls->mAGIC == 0x4B5C0000);
    App*const app = assert_is_App(cls->httpClient->app);
    #define CORO_STATE (cls->coroState)
    enum { begin=0, stzUAAAlnAAC3GwAA, sllEAANEYAADVagAA, slVIAAOBaAABAWQAA, };
    switch( CORO_STATE ){case begin:{
        CORO_STATE = stzUAAAlnAAC3GwAA;
        getJenkinsBuildStatus(app, fzAEAAHdDAABNcQAA, cls);
        return;
    }case stzUAAAlnAAC3GwAA:{
        if( cls->buf_len <= 0 ){
            LOGD("assert(%d > 0) %s:%d\n", cls->buf_len, __FILE__, __LINE__); abort();
        }
        assert(sizeof cls->buildResult > cls->buf_len + (sizeof"\n\0"-1));
        memcpy(cls->buildResult, cls->buf, cls->buf_len);
        memcpy(cls->buildResult + cls->buf_len, "\n\0", 2);
        cls->buildResult_len = cls->buf_len + 1;
        char contentLenStr[8];
        err = snprintf(contentLenStr, sizeof contentLenStr, "%d", cls->buildResult_len);
        assert(err < (signed)sizeof contentLenStr);
        struct Garbage_HttpMsg_Hdr hdrs[] = {{
            .key = "Content-Length", .val = contentLenStr,
            .key_len = 14, .val_len = err,
        }};
        CORO_STATE = sllEAANEYAADVagAA;
        HTTPCLIENT_SENDHTTPHDR(cls->httpClient->handle, NULL, 200, NULL, hdrs, sizeof hdrs/sizeof*hdrs,
            fFyoAANUaAADfcQAA, cls);
        return;
    }case sllEAANEYAADVagAA:{
        if( cls->eno ){ assert(!"TODO_9w0AAGp9AAAxHgAA"); }
        CORO_STATE = slVIAAOBaAABAWQAA;
        HTTPCLIENT_SENDBODY(cls->httpClient->handle, cls->buildResult, cls->buildResult_len, 4,
            fFyoAANUaAADfcQAA, cls);
        return;
    }case slVIAAOBaAABAWQAA:{
        cls->mAGIC = 0;
        MALLOCATOR_REALLOCBLOCKING(app->mallocator, cls, sizeof*cls, 0);
        return;
    }}
    LOGD("assert(s != %d) %s:%d\n", CORO_STATE, __FILE__, __LINE__); abort();
    #undef CORO_STATE
}


static int HttpJenkinsStatus_onHttpRequestHeader( HttpClient*httpClient ){
    #define REQHDR (&httpClient->stepCtx.reqHdr)
    if( strncmp("GET", REQHDR->mthd, REQHDR->mthd_len) ) return -ENOTSUP;
    LOGD("[DEBUG] %.*s\n", REQHDR->path_len, REQHDR->path);
    if( strncmp("/api/v0/getJenkinsBuildStatus", REQHDR->path, REQHDR->path_len) ) return -ENOTSUP;
    App*const app = assert_is_App(httpClient->app);
    struct Cls4B5C0000*const cls = MALLOCATOR_REALLOCBLOCKING(app->mallocator, NULL, 0, sizeof*cls);
    *cls = (struct Cls4B5C0000){
        .mAGIC = 0x4B5C0000,
        .httpClient = httpClient,
    };
    HttpJenkinsStatus_kontinue(cls);
    return 0;
    #undef REQHDR
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
    /**/
    app->env = Garbage_newEnv(&(struct Garbage_Env_Opts){
        .memBlockToUse = app->envMem,
        .memBlockToUse_sz = sizeof app->envMem,
        .mallocator = app->mallocator,
    });  assert(app->env);
    /**/
    app->ioThreadPool = Garbage_newThreadPool(&(struct Garbage_ThreadPool_Opts){
        .mallocator = app->mallocator,
        .numThrds = 4,
    }); assert(app->ioThreadPool);
    /**/
    app->ioMultiplexer = Garbage_newIoMultiplexer(app->env, &(struct Garbage_IoMultiplexer_Opts){
        .mallocator = app->mallocator,
        .ioWorker = app->ioThreadPool,
    }); assert(app->ioMultiplexer);
    /**/
    assert(app->mallocator); assert(app->ioThreadPool);
    app->networker = Garbage_newNetworker(&(struct Garbage_Networker_Opts){
        .mallocator = app->mallocator,
        .ioWorker = app->ioThreadPool,
    }); assert(app->networker);
    /**/
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
            .sin_port = htons(app->httpPort),
            .sin_addr.s_addr = inet_addr("127.0.0.1"),
        }),
        //.backlog = ,
    }); assert(app->httpServer);
    assert(app->mallocator); assert(app->env);
    app->processFactory = Garbage_newProcessFactory(&(struct Garbage_ProcessFactory_Opts){
        .mallocator = app->mallocator,
        .env = app->env,
    }); assert(app->processFactory);
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
            .onHttpRequestHeader = HttpJenkinsStatus_onHttpRequestHeader,
        },{
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
int main( int argc, char**argv ){
#if _WIN32 /* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
    switch( WSAStartup(1, &(WSADATA){0}) ){
    case 0: break;
    case WSASYSNOTREADY    : assert(!"WSASYSNOTREADY"    ); break;
    case WSAVERNOTSUPPORTED: assert(!"WSAVERNOTSUPPORTED"); break;
    case WSAEINPROGRESS    : assert(!"WSAEINPROGRESS"    ); break;
    case WSAEPROCLIM       : assert(!"WSAEPROCLIM"       ); break;
    case WSAEFAULT         : assert(!"WSAEFAULT"         ); break;
    default                : assert(!"ERROR"             ); break;
    }
#endif
    return NerdButtler_main(argc, argv);
#if _WIN32 /* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
    switch( WSACleanup() ){
    case 0: break;
    case WSANOTINITIALISED : assert(!"WSANOTINITIALISED" ); break;
    case WSAENETDOWN       : assert(!"WSAENETDOWN"       ); break;
    case WSAEINPROGRESS    : assert(!"WSAEINPROGRESS"    ); break;
    default                : assert(!"ERROR"             ); break;
    }
#endif
}
#endif

