/* TODO fix this bullshit */
typedef  unsigned  u_int;
typedef  unsigned short  u_short;
typedef  unsigned char  u_char;
#include <pcap/pcap.h>
/* endOf TODO */


/* System */
#include <assert.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static char const*const DEV_STDIN = "/dev/stdin";

#define FLG_isHelp (1<<0)
#define FLG_isTcpPsh (1<<3)
#define FLG_isTcpRst (1<<4)
#define FLG_isTcpSyn (1<<5)
#define FLG_isTcpFin (1<<6)
#define FLG_isHttpReq (1<<7)
#define FLG_isLlLinux (1<<12)
#define FLG_isHdrPrinted (1<<13)
#define FLG_INIT (0)

typedef  struct PcapOne  PcapOne;


struct PcapOne {
    uint_least16_t flg;
    const char *dumpFilePath;
    char *pcapErrbuf;
    pcap_t *pcap;
    unsigned long frameNr;
    struct/*most recent frame*/{
        int llProto;
        int llHdrEnd;
    };
    struct/*most recent packet*/{
        int netProto;
        int netBodyLen;
        int netHdrEnd;
        int_fast32_t netTotLen;
        uint_least32_t ipSrcAddr, ipDstAddr;
    };
    struct/*most recent segment*/{
        int trspBodyLen;
        int trspSrcPort, trspDstPort;
        int trspHdrEnd;
    };
    struct/*most recent http requst*/{
        const uint8_t *httpReqHeadline;
        int httpReqHeadline_len;
        int httpReq_off; /* pkg offset from begin of most recent request */
    };
};


/*BEG func fwd decl*/
static void parse_ll_LINUX_SLL( PcapOne*, const struct pcap_pkthdr*, const u_char* );
static void parse_net_IPv4( PcapOne*, const struct pcap_pkthdr*, const u_char* );
static void parse_trsp_TCP( PcapOne*, const struct pcap_pkthdr*, const u_char* );
static void parse_appl_HTTP_req( PcapOne*, const struct pcap_pkthdr*, const u_char* );
static void printParsingResults( PcapOne*, const struct pcap_pkthdr* );
/*END func fwd decl*/

static void printHelp(){
    #define STRQUOT_21a9ffbe344c0792ed88688d6c676359(s) #s
    #define STRQUOT(s) STRQUOT_21a9ffbe344c0792ed88688d6c676359(s)
    const char *basename = "/"__FILE__ + sizeof("/"__FILE__);
    for(; basename[-1] != '/'; --basename );
    printf("%s%s%s", "  \n"
        "  ", basename, "  " STRQUOT(PROJECT_VERSION) "\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    --pcap-stdin\n"
        "        Like --pcap but reading from stdin.\n"
        "  \n"
        "    --pcap <path>\n"
        "        Pcap file to operate on. Compressed files are NOT supported.\n"
        "  \n");
    #undef STRQUOT_21a9ffbe344c0792ed88688d6c676359
    #undef STRQUOT
}


static int parseArgs( PcapOne*app, int argc, char**argv ){
    app->flg = FLG_INIT;
    app->dumpFilePath = NULL;
    for( int iA = 1 ; iA < argc ; ++iA ){
        const char *arg = argv[iA];
        if(0){
        }else if( !strcmp(arg,"--help") ){
            app->flg |= FLG_isHelp; return 0;
        }else if( !strcmp(arg,"--pcap") ){
            arg = argv[++iA];
            if( arg == NULL ){ fprintf(stderr, "EINVAL --pcap needs value\n"); return -1; }
            app->dumpFilePath = arg;
        }else if( !strcmp(arg,"--pcap-stdin") ){
            app->dumpFilePath = DEV_STDIN;
        }else{
            fprintf(stderr, "EINVAL: %s\n", arg); return -1;
        }
    }
    if( app->dumpFilePath == NULL ){
        fprintf(stderr, "EINVAL Arg missing: --pcap <path>\n"); return -1; }
    return 0;
}


static void onPcapPkg( u_char*user, const struct pcap_pkthdr*hdr, const u_char*buf ){
    PcapOne *const app = (void*)user;

    /* prepare for this new packet */
    app->frameNr += 1;
    app->flg &= ~(FLG_isTcpPsh | FLG_isTcpRst | FLG_isTcpSyn | FLG_isTcpFin | FLG_isHttpReq);

    /* data-link layer */
    switch( pcap_datalink(app->pcap) ){
    case 0x71: parse_ll_LINUX_SLL(app, hdr, buf); break;
    default: assert(!fprintf(stderr,"pcap_datalink() -> 0x%02X\n", pcap_datalink(app->pcap)));
    }

    /* network layer */
    switch( app->llProto ){
    case 0x0800: parse_net_IPv4(app, hdr, buf); break;
    default: printf("???, proto=0x%04X, network-layer\n", app->llProto); return;
    }

    /* transport layer */
    switch( app->netProto ){
    case 0x06: parse_trsp_TCP(app, hdr, buf); break;
    default: printf("???, proto=0x%02X, transport-layer\n", app->netProto); return;
    }

    assert(app->trspBodyLen >= 0);

    /* application layer, towards server */
    switch( app->trspDstPort ){
    case    80: parse_appl_HTTP_req(app, hdr, buf); break;
    case  7012: parse_appl_HTTP_req(app, hdr, buf); break;
    case  8080: parse_appl_HTTP_req(app, hdr, buf); break;
    }

    printParsingResults(app, hdr);
}


static void parse_ll_LINUX_SLL( PcapOne*app, const struct pcap_pkthdr*hdr, const u_char*buf  ){
    assert(hdr->caplen >= 15);
    app->llProto = buf[14]<<8 | buf[15];
    app->llHdrEnd = 16;
}


static void parse_net_IPv4( PcapOne*app, const struct pcap_pkthdr*hdr, const u_char*buf ){
    assert(hdr->caplen >= app->llHdrEnd+19 && "TODO_775afde7f19010220e9df8d5e2924c3e");
    int_fast8_t netHdrLen = (buf[app->llHdrEnd+0] & 0x0F) * 4;
    app->netTotLen = buf[app->llHdrEnd+2] << 8 | buf[app->llHdrEnd+3];
    app->netProto = buf[app->llHdrEnd+9];
    app->ipSrcAddr = 0
        | ((uint_least32_t)buf[app->llHdrEnd+12]) << 24
        | ((uint_least32_t)buf[app->llHdrEnd+13]) << 16
        | buf[app->llHdrEnd+14] << 8
        | buf[app->llHdrEnd+15] ;
    app->ipDstAddr = 0
        | ((uint_least32_t)buf[app->llHdrEnd+16]) << 24
        | ((uint_least32_t)buf[app->llHdrEnd+17]) << 16
        | buf[app->llHdrEnd+18] << 8
        | buf[app->llHdrEnd+19] ;
    app->netHdrEnd = app->llHdrEnd + netHdrLen;
    app->netBodyLen = app->netTotLen - netHdrLen;
}


static void parse_trsp_TCP( PcapOne*app, const struct pcap_pkthdr*hdr, const u_char*buf ){
    assert(hdr->caplen >= app->netHdrEnd+12 && "TODO_058d5f41043d383e1ba2c492d0db4b6a");
    app->trspSrcPort = buf[app->netHdrEnd+0] << 8 | buf[app->netHdrEnd+1];
    app->trspDstPort = buf[app->netHdrEnd+2] << 8 | buf[app->netHdrEnd+3];
    int tcpHdrLen = (buf[app->netHdrEnd+12] >> 4) * 4;
    app->trspHdrEnd = app->netHdrEnd + tcpHdrLen;
    app->trspBodyLen = app->netBodyLen - tcpHdrLen;
}


static void parse_appl_HTTP_req( PcapOne*app, const struct pcap_pkthdr*hdr, const u_char*buf ){
    app->flg |= FLG_isHttpReq;
    app->httpReqHeadline = buf + app->trspHdrEnd;
    app->httpReqHeadline_len = 0;
    for(;; ++app->httpReqHeadline_len ){
        if( (app->trspHdrEnd + app->httpReqHeadline_len) > hdr->caplen ) break;
        if( app->httpReqHeadline[app->httpReqHeadline_len] == '\r' ) break;
        if( app->httpReqHeadline[app->httpReqHeadline_len] == '\n' ) break;
    }
    /* TODO improve, as now its like a guess only */
    int isNewRequest = 0
        | !memcmp(buf + app->trspHdrEnd, "GET ", 4)
        | !memcmp(buf + app->trspHdrEnd, "PUT ", 4)
        | !memcmp(buf + app->trspHdrEnd, "POST ", 5)
        | !memcmp(buf + app->trspHdrEnd, "DELETE ", 7)
        ;
    if( isNewRequest ){
        app->httpReq_off = 0;
    }else{
        app->httpReq_off = 42; /*TODO make more accurate*/
    }
}


static void printParsingResults( PcapOne*app, const struct pcap_pkthdr*hdr ){

    int isHttpRequest = (app->flg & FLG_isHttpReq);
    int isHttpReqBegin = isHttpRequest && app->httpReq_off == 0;

    if( isHttpRequest && isHttpReqBegin ){
        /* find http method */
        const uint8_t *method = app->httpReqHeadline;
        int method_len = 0;
        for(;; ++method_len ){
            if( method_len > app->httpReqHeadline_len ) break;
            if( method[method_len] == ' ' ) break;
        }
        /* find http uri */
        const uint8_t *uri = method + method_len + 1;
        int uri_len = 0;
        for(;; ++uri_len ){
            if( method_len + uri_len > app->httpReqHeadline_len ) break;
            if( uri[uri_len] == ' ' ) break;
        }
        if( !(app->flg & FLG_isHdrPrinted) ){
            app->flg |= FLG_isHdrPrinted;
            printf("h;Title;HTTP requests\n");
            printf("c;epochSec;srcIp;dstIp;srcPort;dstPort;http_method;http_uri\n");
        }
        /* print it as a quick-n-dirty CSV record */
        printf("r;%ld.%06ld;%d.%d.%d.%d;%d.%d.%d.%d;%d;%d;%.*s;%.*s\n",
            hdr->ts.tv_sec, hdr->ts.tv_usec,
            app->ipSrcAddr >> 24, app->ipSrcAddr >> 16 & 0xFF, app->ipSrcAddr >> 8 & 0xFF, app->ipSrcAddr & 0xFF,
            app->ipDstAddr >> 24, app->ipDstAddr >> 16 & 0xFF, app->ipDstAddr >> 8 & 0xFF, app->ipDstAddr & 0xFF,
            app->trspSrcPort, app->trspDstPort,
            method_len, method, uri_len, uri);
    }
}


static int run( PcapOne*app ){
    int err;
    err = pcap_init(PCAP_CHAR_ENC_UTF_8, app->pcapErrbuf);
    if( err == PCAP_ERROR ){
        fprintf(stderr, "libpcap: %s\n", app->pcapErrbuf); err = -1; goto endFn; }
    app->pcap = pcap_open_offline(
        (app->dumpFilePath == DEV_STDIN) ? "-" : app->dumpFilePath,
        app->pcapErrbuf);
    if( app->pcap == NULL ){
        fprintf(stderr, "libpcap: %s\n", app->pcapErrbuf); err = -1; goto endFn; }
    for(;;){
        err = pcap_dispatch(app->pcap, -1,  onPcapPkg, (void*)app);
        switch( err ){
        case PCAP_ERROR:
            fprintf(stderr, "pcap_dispatch(): %s\n", pcap_geterr(app->pcap));
            err = -1; goto endFn;
        case PCAP_ERROR_BREAK:
        case PCAP_ERROR_NOT_ACTIVATED:
            fprintf(stderr, "pcap_dispatch() -> %d\n", err);
            err = -1; goto endFn;
        }
        if( err > 0 ){
            fprintf(stderr, "Processed %d packages in this turn.\n", err);
            continue;
        }
        break;
    }
    err = 0;
endFn:
    if( app->pcap != NULL ){ pcap_close(app->pcap); app->pcap = NULL; }
    return err;
}


int main( int argc, char**argv ){
    int err;
    static char errbuf[PCAP_ERRBUF_SIZE];
    errbuf[0] = '\0';
    PcapOne app = {
        .flg = FLG_INIT,
        .pcapErrbuf = errbuf,
        .pcap = NULL,
        .frameNr = 0,
        .trspBodyLen = 0,
    };
    #define app (&app)

    err = parseArgs(app, argc, argv);
    if( err ){ goto endFn; }

    if( app->flg & FLG_isHelp ){
        printHelp(); goto endFn; }

    err = run(app);

endFn:
    if( err < 0 ) err = -err;
    if( err > 0x7F ) err = 1;
    return err;
    #undef app
}


