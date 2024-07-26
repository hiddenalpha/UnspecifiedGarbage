/*

  Related: SDCISA-16866.
 
  && CC=cc \
  && LD=cc \
  && CFLAGS="-Wall -Wextra -Werror -pedantic -O0" \
  && LDFLAGS="" \
  && BINEXT= \

  && CC=x86_64-w64-mingw32-gcc \
  && LD=x86_64-w64-mingw32-gcc \
  && CFLAGS="-Wall -Wextra -Werror -pedantic -O0" \
  && LDFLAGS="-Wl,-dy,-lws2_32" \
  && BINEXT=".exe" \

  && mkdir -p build/bin build/obj \
  && ${CC:?} -c -o build/obj/SAoCAPVYAgBnTgIA src/main/paisa-SendAfterFin/SendAfterFin.c ${CFLAGS?} \
  && ${LD:?} -o build/bin/SendAfterFin${BINEXT?} build/obj/SAoCAPVYAgBnTgIA ${LDFLAGS?} \

 */

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#if __WIN32
#   include <winsock2.h>
#   include <windows.h>
#   define WINDOOF 1
#   define MSG_NOSIGNAL 0
#   define SHUT_WR SD_SEND
#   define SOCK long long unsigned
#   define SOCK_isValid(s) ((s) != INVALID_SOCKET)
#else
#   include <arpa/inet.h>
#   include <sys/socket.h>
#   define WINDOOF 0
#   define SOCK int
#   define SOCK_isValid(s) ((s) >= 0)
#endif

#define LOGERR(...) fprintf(stderr, __VA_ARGS__)
#define LOGDBG(...) fprintf(stderr, __VA_ARGS__)

#if WINDOOF
#   define sleepMs(ms) Sleep(ms)
#else
#   define sleepMs(ms) do{struct timespec t={.tv_sec=ms/1000,.tv_nsec=(ms%1000)*1000000}; nanosleep(&t, NULL); }while(0)
#endif

#define FLG_isHelp (1<<0)
#define FLG_isClient (1<<1)
#define FLG_isServer (1<<2)
#define FLG_isListenAny (1<<3)


typedef  struct App  App;


struct App {
    int flg;
    int port;
    SOCK sock, sockRemote;
    struct sockaddr_storage addrLocal;
};


static void printHelp( void ){
    printf("\n"
        "  %s - Provocate send after FIN.\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    --client\n"
        "      Play the client role.\n"
        "  \n"
        "    --server\n"
        "      Play the server role.\n"
        "  \n"
        "    --port\n"
        "      TCP port to bind/connect to.\n"
        "  \n"
        "    --listen-any\n"
        "      If server, listen to INADDR_ANY in place of localhost only.\n"
        "  \n", strrchr(__FILE__,'/') + 1
    );
}


static int parseArgs( App*app, char**argv ){
    int iA = 0;
    app->port = -1;
nextOpt:
    iA += 1;
    char *arg = argv[iA];
    if( arg == NULL ){
        goto verify;
    }else if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp;
        return 0;
    }else if( !strcmp(arg, "--client") ){
        app->flg |= FLG_isClient;
    }else if( !strcmp(arg, "--server") ){
        app->flg |= FLG_isServer;
    }else if( !strcmp(arg, "--port") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iA-1]); return-1; }
        errno = 0;
        char *endptr;
        app->port = strtol(arg, &endptr, 0);
        if( endptr == arg || *endptr != '\0' ){ errno = EINVAL; }
        if( errno ){ LOGERR("%s: %s %s\n", strerror(errno), argv[iA-1], arg); return-1; }
        if( app->port <= 0 || app->port > 0xFFFF ){ LOGERR("ERANGE: port %d\n", app->port); return-1; }
    }else if( !strcmp(arg, "--listen-any") ){
        app->flg |= FLG_isListenAny;
    }else{
        LOGERR("EINVAL: %s\n", arg);
        return -1;
    }
    goto nextOpt;
verify:
    if(  (app->flg & (FLG_isClient|FLG_isServer)) == (FLG_isClient|FLG_isServer)
      || (app->flg & (FLG_isClient|FLG_isServer)) == 0
    ){
        LOGERR("EINVAL: Choose ONE of server or client mode.\n");
        return -1;
    }
    if( app->port == -1 ){ LOGERR("EINVAL: --port missing\n"); return-1; }
    return 0;
}


static int runServer( App*app ){
    int err;
    #define ADDR ((struct sockaddr*)&app->addrLocal)
    #define ADDR4 ((struct sockaddr_in*)&app->addrLocal)
    ADDR4->sin_family = AF_INET;
    ADDR4->sin_port = htons(app->port);
    ADDR4->sin_addr.s_addr = htonl((app->flg & FLG_isListenAny) ? INADDR_ANY : 0x7F000001);
    app->sock = socket(AF_INET, SOCK_STREAM, 0);
    if( !SOCK_isValid(app->sock) ){
#if WINDOOF
        LOGDBG("socket(): 0x%X\n", WSAGetLastError());
#else
        LOGDBG("socket(): %s\n", strerror(errno));
#endif
        return -1;
    }
    err = bind(app->sock, ADDR, sizeof app->addrLocal);  assert(err == 0);
    err = listen(app->sock, 4);  assert(err == 0);
    #undef ADDR
    #undef ADDR4
nextClient:
    err = accept(app->sock, NULL, NULL);  assert(err >= 0);
    app->sockRemote = err;
    /* in the 1st message we expect 'A' */
    char msg;
    err = recv(app->sockRemote, &msg, 1, 0);
    if( err != 1 ){ LOGDBG("[DEBUG] recv() -> %d (%s)\n", err, strerror(errno)); }
    assert(err == 1);
    assert(msg == 'A');
    /* lets imagine we need some time to setup our response */
    sleepMs(230);
    err = send(app->sockRemote, "C", 1, 0);  assert(err == 1);
    /* Now, as we're done sending our response. We go waiting for more incoming
     * data which MUST be EOF, because client did send FIN after 'A', so there
     * MUST NOT be any data. Also, message 'B' MUST NOT arrive, because it was
     * sent AFTER FIN. */
    err = recv(app->sockRemote, &msg, 1, 0);
    /* TODO why is linux/win return code different here? */
#if WINDOOF
    if( err != -1 ){
        LOGERR("assert(recv() != %d): recv() MUST return 0! (aka EOF). But got: 0x%X\n",
            err, WSAGetLastError());
#else
    if( err != 0 ){
        LOGERR("assert(recv() != %d): recv() MUST return 0! (aka EOF). But got: %s\n",
            err, strerror(errno));
#endif
        return -1;
    }else{
        LOGDBG("[SUCCESS] Well done TCP :) You reported ['A', EOF] as expected.\n");
    }
    /* Good :) Then release client socket after a while and go handle next client. */
    sleepMs(42);
    err = close(app->sockRemote);
#if WINDOOF
    assert(err == -1 && WSAGetLastError() == WSAECONNABORTED);
#else
    assert(err == 0);
#endif
    goto nextClient;
    return -42;
}


static int runClient( App*app ){
    int err;
    #define ADDR ((struct sockaddr*)&app->addrLocal)
    #define ADDR4 ((struct sockaddr_in*)&app->addrLocal)
    ADDR4->sin_family = AF_INET;
    ADDR4->sin_port = htons(app->port);
    ADDR4->sin_addr.s_addr = htonl(0x7F000001);
    app->sock = socket(AF_INET, SOCK_STREAM, 0);  assert(app->sock > 0);
    err = connect(app->sock, ADDR, sizeof app->addrLocal);
    if( err != 0 ){
        LOGDBG("connect(): %s\n", strerror(errno));
        LOGDBG("Is the server running?\n");
        return -1;
    }
    #undef ADDR
    #undef ADDR4
    /* Send letter 'A' (as our reqeust) followed by TCP FIN (indicating we wont
     * send anymore). */
    err = send(app->sock, "A", 1, MSG_NOSIGNAL);  assert(err == 1);
    err = shutdown(app->sock, SHUT_WR);  assert(err == 0);
    /* Lets say some broken code tries to send 'B' a moment later ON THE
     * ALREADY CLOSED outgoing stream.
     * NOTE: TCP stack MUST NOT accept our data! It has to report an error to
     * us. Something like EPIPE or equivalent. */
    sleepMs(150);
    err = send(app->sock, "B", 1, MSG_NOSIGNAL);
    assert(err == -1);
#if WINDOOF
    assert(WSAGetLastError() != 0);
#else
    assert(errno != 0);
#endif
    LOGDBG("[SUCCESS] Well done TCP :) Thx for reporting errno %d, aka: %s\n", errno, strerror(errno));
    return 0;
}


int main( int argc, char**argv ){
#if WINDOOF
    WSAStartup(1, &(WSADATA){0});
#endif
    (void)argc;
    int err;
    App *app = &(App){0}; assert((void*)0 == NULL);
    if( (err=parseArgs(app, argv)) ){ goto endFn; }
    if( app->flg & FLG_isHelp ){
        printHelp(); err = -1; goto endFn;
    }
    if( app->flg & FLG_isClient ){
        err = runClient(app); goto endFn;
    }
    if( app->flg & FLG_isServer ){
        err = runServer(app); goto endFn;
    }
    assert(!"TODO_7iUCAHg5AgBaIwIA");
endFn:
    return !!err;
}


