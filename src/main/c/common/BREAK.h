
/* -DBREAK\(\)=abort\(\) */
#ifndef BREAK
#    define BREAK() do{ \
        LOGDBG("SIGTRAP %s:%d\n", __FILE__, __LINE__); \
        __asm__("int $3; nop"); abort(); \
    }while(0)
#endif

