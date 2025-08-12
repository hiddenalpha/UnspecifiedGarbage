#if 0

  Experiments about how to do mDNS-SD, PROPERLY and WITHOUT terrible kludge
  tools.

  && CC=x86_64-w64-mingw32-gcc \
  && LD=x86_64-w64-mingw32-gcc \
  && OBJDUMP=x86_64-w64-mingw32-objdump \
  && BINEXT=.exe \
  && CFLAGS="-Wall -Werror -Wextra -pedantic" \
  && LDFLAGS="-Wl,-dn,-lgarbage,-l:libwinpthread.a,-dy,-lws2_32,-Limport/lib" \
  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && OUT=build/bin/mdns${BINEXT?} \
  && rm -rf "${OUT:?}" \
  && mkdir -p "$(dirname "${OUT:?}")" \
  && ${CC:?} -c -o /tmp/HlAAAIJ4AADgEwAA src/private/mdns/MdnsSd.c ${CFLAGS?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o "${OUT:?}" /tmp/HlAAAIJ4AADgEwAA ${LDFLAGS?} \
  && bullshit=$(${OBJDUMP?} -p "${OUT:?}"|grep DLL\ Name|egrep -v '\'' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'\''||true) \
  && if test -n "$bullshit"; then printf '\''\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n'\'' "$bullshit"; rm "${OUT:?}"; false; fi \

  [Seems to contain some wire format for mDNS-SD](https://www.ietf.org/rfc/rfc6887.txt)
  [Has refs to good docs](http://www.dns-sd.org/)
  [IPv4 vs IPv6](http://ipuptime.net/IPv4Mapped.aspx)


#endif
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#if _WIN32
#   include <winsock2.h> /*MUST be before winDOOF */
#   include <windows.h>
#   define socklen_t int32_t /*FUCK this shit!*/
#   define MSG_NOSIGNAL 0
#else
#   error "TODO_MBEAAPFlAADHZwAA"
#endif

#define REGISTER
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#define LOGW(...) fprintf(stderr, __VA_ARGS__)
#define LOGI(...) fprintf(stderr, __VA_ARGS__)
#define LOGD(...) fprintf(stderr, __VA_ARGS__)
#define LOGT(...) fprintf(stderr, __VA_ARGS__)

#define FLG_isHelp (1<<0)

#define mDnsOp_StandardQuery 0


typedef  struct App  App;


struct App {
    unsigned flg;
    SOCKET sock;
    struct sockaddr_storage mcastAddr;
    struct sockaddr_storage peerAddr;
    socklen_t peerAddr_len;
};


char*strerrname(int);


static inline void printHelp( void ){
    printf("TODO write this help page\n");
}


static inline int parseArgs( App*this, int argc, char**argv ){
    int iA = 0;
    int isYolo = 0;
nextArg:;
    char *arg = argv[++iA];
    if( !arg ){
        goto verify;
    }else if( !strcmp(arg, "--help") ){
        this->flg |= FLG_isHelp;
        return 0;
    }else if( !strcmp(arg, "--yolo") ){
        isYolo = 1;
    }else{
        LOGE("EINVAL: %s\n", arg);
        return -1;
    }
    goto nextArg;
verify:
    if( argc <= 1 && !isYolo ){ LOGE("EINVAL: Try --help\n"); return-1; }
    return 0;
}


static inline void mDnsSd_setVersion( char*msg, int msg_len, int version ){
    assert(msg_len >= 1); assert(version >= 1); assert(version <= 0xFF);
    msg[0] = version;
}


static inline void mDnsSd_setIsRequest( char*msg, int msg_len ){
    assert(msg_len >= 2);
    msg[1] &= ~0x80;
}


static inline void mDnsSd_setOpcode( char*msg, int msg_len, int opCode ){
    assert(msg_len >= 2); assert(opCode >= 0); assert(opCode <= 0x7F);
    REGISTER int err = msg[1];
    err &= ~0x7F; /*zero*/
    err |= opCode; /*set*/
    msg[1] = err;
}


static inline void mDnsSd_zeroReserved( char*msg, int msg_len ){
    assert(msg_len >= 4);
    msg[2] = 0;  msg[3] = 0;
}


static inline void mDnsSd_setRequestedLifetime( char*msg, int msg_len, uint_fast32_t reqLfTm ){
    assert(msg); assert(msg_len >= 8);
    msg[4] = reqLfTm >> 24 & 0xFF;
    msg[5] = reqLfTm >> 16 & 0xFF;
    msg[6] = reqLfTm >>  8 & 0xFF;
    msg[7] = reqLfTm       & 0xFF;
}


static inline void mDnsSd_setIpv4Src( char*msg, int msg_len, uint32_t ipv4HostOrder ){
    assert(msg); assert(msg_len >= 24);
    memset(msg +  8, 0x00, 10);
    memset(msg + 18, 0xFF,  2);
    msg[20] = ipv4HostOrder >> 24 & 0xFF;
    msg[21] = ipv4HostOrder >> 16 & 0xFF;
    msg[22] = ipv4HostOrder >>  8 & 0xFF;
    msg[23] = ipv4HostOrder       & 0xFF;
}


static int run( App*this ){
    REGISTER int err;
    #define MCASTADDR ((struct sockaddr*)&this->mcastAddr)
    #define MCASTADDR_LEN (sizeof this->mcastAddr)
    #define MCASTADDR4 ((struct sockaddr_in*)&this->mcastAddr)
    #define PEERADDR ((struct sockaddr*)&this->peerAddr)
    #define PEERADDR_LEN (this->peerAddr_len)
    #define PEERADDR_MEM (&this->peerAddr)
    memset(&this->mcastAddr, 0, sizeof this->mcastAddr);
    MCASTADDR4->sin_family = AF_INET;
    MCASTADDR4->sin_addr.s_addr = inet_addr("224.0.0.251");
    MCASTADDR4->sin_port = htons(5353);
    /*
     * TODO need 'SO_BROADCAST'? */
    this->sock = socket(MCASTADDR4->sin_family, SOCK_DGRAM, IPPROTO_UDP);
    if( this->sock == INVALID_SOCKET ){
        err = WSAGetLastError();
        LOGE("%s: socket(%d, %d, %d)\n", strerrname(err), MCASTADDR4->sin_family, SOCK_DGRAM, IPPROTO_UDP);
        return -1;
    }
    // NONSENSE? if( connect(sockfd, (struct sockaddr*)&this->mcastAddr, sizeof(this->mcastAddr)) < 0 ){
    // NONSENSE?     assert(!"TODO_IEAAAJxeAACMaQAA");
    // NONSENSE? }
    /**/
    char msg[1024];
    int const msg_cap = sizeof msg;
    /* transactionID */
    msg[0] = 0x00;  msg[1] = 0x00;
    /* flags (0x0000=StandardQuery) */
    msg[2] = 0x00;  msg[3] = 0x00;
    /* num questions (u16 BigEndian) */
    msg[4] = 0x00;  msg[5] = 0x01;
    /* Answer RRs, Authority RRs, Additional RRs */
    msg[6] = 0x00;  msg[7] = 0x00;
    /* TODO I guess those are reserved and have to be zero? */
    msg[8] = 0; msg[9] = 0; msg[10] = 0; msg[11] = 0;
    char *it = msg + 12;
    /* QName (labels include a 0x00 which means dot. Except last label, which
     * has NO trailing char. Neither a dot NOR a 0x00) */
    char const qname[] = "\x05""_http\0""\x04""_tcp\0""\x05""local";
    int const qname_len = sizeof qname-(sizeof"\0");
    memcpy(it, qname, qname_len);  it += qname_len;
    /* EndOf QName */
    *it++ = 0x00;
    /* QType (0x000C=PTR) */
    *it++ = 0x00;  *it++ = 0x0C;
    /* QClass (0x0001=IN) */
    *it++ = 0x00;  *it++ = 0x0C;
    int const msg_len = it - msg;
    assert(msg_len < msg_cap);
    LOGI("Send mDNS-SD request ...\n");
    err = sendto(this->sock, msg, msg_len, MSG_NOSIGNAL, MCASTADDR, MCASTADDR_LEN); 
    if( err != msg_len ) assert(!"TODO_vRoAAPYqAAAzPAAA");
    LOGI("mDNS-SD sent\n");
    /**/
    char recvBuf[1024];
    int const recvBuf_cap = sizeof recvBuf;
    PEERADDR_LEN = sizeof*PEERADDR_MEM;
    int const maxRecvWaitSec = 17;
    int const recvTimeoutSec = 3;
    int totalWaitingSec = 0;
    for(;;){
        if( totalWaitingSec > maxRecvWaitSec ){
            LOGE("Nothing received after waiting %d seconds. Giving up.\n",
                totalWaitingSec);
            return -1;
        }
        //LOGD("recvfrom() ...\n");
        fd_set rdFds, exFds;
        FD_ZERO(&rdFds);
        FD_ZERO(&exFds);
        FD_SET(this->sock, &rdFds);
        FD_SET(this->sock, &exFds);
        struct timeval timeout = { .tv_sec = recvTimeoutSec, .tv_usec = 0, };
        err = select(this->sock + 1, &rdFds, NULL, &exFds, &timeout);
        if( err == -1 ){
            err = WSAGetLastError();
            LOGE("mDNS: recv(): select(): %d (See https://learn.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2)\n", err);
            return -1;
        }
        if( err == 0 ){ /*timeout*/
            LOGI("No response ...\n");
            totalWaitingSec += recvTimeoutSec;
            continue;
        }
        assert(err > 0);
        break;
    }
    ssize_t const recvLen = recvfrom(
        this->sock, recvBuf, recvBuf_cap, 0, PEERADDR, &PEERADDR_LEN);
    if( recvLen == -1 ){
        err = WSAGetLastError();
        LOGE("%s: recvfrom()\n", strerrname(err));
        assert(!"TODO_VgUAAEIEAADrAgAA");
    }
    LOGD("[DEBUG] recvfrom() -> %lld\n", recvLen);
    assert(recvLen >= 0);
    LOGD("[DEBUG] recvLen := %lld\n", recvLen);
    /**/
    assert(!"TODO_D1cAAKAsAABobgAj");
    return 0;
    #undef MCASTADDR
    #undef MCASTADDR_LEN
    #undef MCASTADDR4
    #undef PEERADDR
    #undef PEERADDR_LEN
}


int main( int argc, char**argv ){
#if _WIN32 /* TODO re-use from libgarbage */
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
    REGISTER int err;
    App*const this = &(App){
        0,
    };
    if( parseArgs(this, argc, argv) ) return 1;
    if( this->flg & FLG_isHelp ){ printHelp(); return 0; }
    err = run(this);
    if( err < 0 ) err = -err;
    if( err > 127 ) err = 1;
#if _WIN32 /* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
    switch( WSACleanup() ){
    case 0: break;
    case WSANOTINITIALISED : assert(!"WSANOTINITIALISED" ); break;
    case WSAENETDOWN       : assert(!"WSAENETDOWN"       ); break;
    case WSAEINPROGRESS    : assert(!"WSAEINPROGRESS"    ); break;
    default                : assert(!"ERROR"             ); break;
    }
#endif
    return err;
}

