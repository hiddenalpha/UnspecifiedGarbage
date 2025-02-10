#ifndef INCGUARD_Qeo3GDN5wMhfjlVa
#define INCGUARD_Qeo3GDN5wMhfjlVa
#if __cplusplus
extern "C" {
#endif



#define Garbage_Closure void*

#define REGISTER /*no-op*/

#define LOGF(...) fprintf(stderr, __VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#define LOGW(...) fprintf(stderr, __VA_ARGS__)
#define LOGI(...) fprintf(stderr, __VA_ARGS__)
#define LOGD(...) fprintf(stderr, __VA_ARGS__)
#define LOGT(...) fprintf(stderr, __VA_ARGS__)

#define STR_QUOT_(S) #S
#define STR_QUOT(S) STR_QUOT_(S)

#define MIN(a, b) (((a) < (b)) * (a) + ((a) >= (b)) * (b))

#define MALLOCATOR_REALLOC(A, B, C, D, E, F) (*A)->reallocBlocking(A, B, C, D, E, F)
#define MALLOCATOR_REALLOCBLOCKING(A, B, C, D) (*A)->reallocBlocking(A, B, C, D)

#define ENV_ENQUEBLOCKING(A, B, C) (*A)->enqueBlocking(A, B, C)

#define THREADPOOL_START(A) (*A)->start(A)

#define IOMULTIPLEXER_START(A) (*A)->start(A)
#define IOMULTIPLEXER_READ(A, B, C, D, E, F, G) (*A)->read(A, B, C, D, E, F, G)

#define HTTPSERVER_RUNUNTILPAUSE(A, B) (*A)->runUntilPause(A, B)
#define HTTPSERVER_WAITUNTIL(A, B, C) (*A)->waitUntil(A, B, C)

#define HTTPCLIENT_GETCTX(A) (*A)->getCtx(A)
#define HTTPCLIENT_SETCTX(A, B) (*A)->setCtx(A, B)
#define HTTPCLIENT_STEP(A, B) (*A)->step(A, B)
#define HTTPCLIENT_WAITUNTIL(A, B, C) (*A)->waitUntil(A, B, C)
#define HTTPCLIENT_PAUSE(A) (*A)->pause(A)
#define HTTPCLIENT_RESUME(A) (*A)->resume(A)
#define HTTPCLIENT_SENDHTTPHDR(A, B, C, D, E, F, G, H) (*A)->sendHttpHdr(A, B, C, D, E, F, G, H)
#define HTTPCLIENT_SENDBODY(A, B, C, D, E, F) (*A)->sendBody(A, B, C, D, E, F)
#define HTTPCLIENT_SENDRAW(A, B, C, D, E, F) (*A)->sendRaw(A, B, C, D, E, F)
#define HTTPCLIENT_UNREF(A) (*A)->unref(A)


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


char*strerrname(int);


#if __cplusplus
} /* extern "C" */
#endif
#endif /* INCGUARD_Qeo3GDN5wMhfjlVa */
