

#if 0 /* Template for QuickNDirty builds */
  && CC=gcc \
  && LD=gcc \
  && OBJDUMP=objdump \
  && BINEXT= \
  && SRCFILE="src/path/to/input.c" \
  && OBJFILE="/tmp/HDG4zsUwy697siH6" \
  && OUTFILE="build/bin/out${BINEXT?}" \
  && CFLAGS="-nostdlib -Wall -Wextra -Werror -pedantic -fmax-errors=1 -Iinclude" \
  && LDFLAGS="-Wl,-nostdlib,-dn,-lgarbage,-lcJSON,-lmbedtls,-lmbedx509,-lmbedcrypto,-lexpat,-dy,-lpthread,-lgcc,-Lbuild/lib,-Limport/lib" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o "${OBJFILE:?}" "${SRCFILE:?}" ${CFLAGS:?} \
  && ${LD:?} -o "${OUTFILE:?}" "${OBJFILE:?}" ${LDFLAGS:?} \
  && bullshit=$(${OBJDUMP?} -p "${OUTFILE:?}"|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm "${OUTFILE:?}"; false; fi \
  
  Shitty systems maybe need adaptions like:
  
  && LDFLAGS="-Wl,-lws2_32,-l:libwinpthread.a" \
#endif










/* [Source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#ifndef container_of
#   define container_of(P, T, M) \
        ((T*)( ((size_t)P) - ((size_t)((ptrdiff_t)&((T*)0)->M - (ptrdiff_t)0) )))
#endif










/* [Source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
typedef  unsigned char  uchar;










/* [Source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#define STRQUOT_(s) #s
#define STRQUOT(s) STRQUOT_(s)
#ifndef PROJECT_VERSION
#   define PROJECT_VERSION 0.0.0-SNAPSHOT
#endif










/* [Source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#if !NDEBUG
#define TPL_assert_is(T, PRED) static inline T*assert_is_##T(void*p,\
const char*f,int l){if(p==NULL){fprintf(stderr,"assert(" STR_QUOT(T)\
" != NULL)  %s:%d\n",f,l);abort();}T*obj=p;if(!(PRED)){fprintf(stderr,\
"ssert(type is \""STR_QUOT(T)"\")  %s:%d\n",f,l);abort();}return p; }
#else
#define TPL_assert_is(T, PRED) static inline T*assert_is_##T(void*p,\
const char*f,int l){return p;}
#endif
/*
 * Example usage:
 *
 * add some magic to your struct under check
 */
typedef  struct Person  Person;
struct Person {
    char tYPE[sizeof"Hi, I'm a Person"];
};
/*
 * then instantiate an instance of this template for Person:
 */
TPL_assert_is(Person, !strcmp(obj->tYPE, "Hi, I'm a Person"))
#define assert_is_Person(p) assert_is_Person(p, __FILE__, __LINE__)
/*
 * make sure magic is initialized (ALSO MAKE SURE TO PROPERLY INVALIDATE IT IN
 * DTOR!)
 */
static void someCaller( void ){
    Person p = {0};
    strcpy(p.tYPE, "Hi, I'm a Person");
    void *ptr = p; /*whops compiler cannot help us any longer*/
    someCallee(ptr);
}
/*
 * How to verify if you really got a Person:
 */
static void someCallee( void*shouldBeAPerson ){
    Person *p = assert_is_Person(shouldBeAPerson);
    /* 'p' is now ready as a Person. */
}










/* [Source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c)
 * -DBREAK\(\)=abort\(\) */
#ifndef BREAK
#    define BREAK() do{ \
        LOGDBG("SIGTRAP %s:%d\n", __FILE__, __LINE__); \
        __asm__("int $3; nop"); abort(); \
    }while(0)
#endif










/* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
static int ensureBufCap(
    void*    (*allocFn)(ptrdiff_t ctx,void*ptr,size_t oldSz,size_t newSz),
    ptrdiff_t  ctx,
    char     **buf,
    int       *buf_cap,
    int        wanted
){
    #define BUF (*buf)
    #define BUF_CAP (*buf_cap)
    assert(allocFn != NULL);
    assert(BUF_CAP >= 0);
    assert(wanted > 0);
    if( BUF_CAP < wanted ){
        void *tmp = allocFn(ctx, BUF, BUF_CAP, wanted);
        if( tmp == NULL ){ assert(errno > 0); return -errno; }
        BUF_CAP = wanted;
        BUF = tmp;
    }
    return 0;
    #undef BUF
    #undef BUF_CAP
}










/* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#if _WIN32
    int _setmode(int,int);
#   define FUCK_BROKEN_SYSTEMS() do{char a=0;for(;!(a&10);){_setmode(a++,32768);}}while(0)
#else
#   define FUCK_BROKEN_SYSTEMS()
#endif







/* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#if _WIN32
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
/* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#if _WIN32
    switch( WSACleanup() ){
    case 0: break;
    case WSANOTINITIALISED : assert(!"WSANOTINITIALISED" ); break;
    case WSAENETDOWN       : assert(!"WSAENETDOWN"       ); break;
    case WSAEINPROGRESS    : assert(!"WSAEINPROGRESS"    ); break;
    default                : assert(!"ERROR"             ); break;
    }
#endif









/* TODO share this 'HUMANIZE_SI' somewhere. */
/* [Source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/snippets.c) */
#define HUMANIZE_SI(VAL, UNIT, PAD_LEN) do{ \
    UNIT = ""; \
    if( VAL >= 1000 ){ VAL /= 1024; UNIT = "ki"; } \
    if( VAL >= 1000 ){ VAL /= 1024; UNIT = "Mi"; } \
    if( VAL >= 1000 ){ VAL /= 1024; UNIT = "Gi"; } \
    if( VAL >= 1000 ){ VAL /= 1024; UNIT = "Ti"; } \
    PAD_LEN = 2; \
    if( VAL >=   10 ){ PAD_LEN -= 1; } \
    if( VAL >=  100 ){ PAD_LEN -= 1; } \
}while(0)




