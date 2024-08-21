
/* "-DBREAK=do{assert(0);abort();}while(0)" */
#ifndef BREAK
#    define BREAK() do{ \
        LOGDBG("SIGTRAP %s:%d\n", __FILE__, __LINE__); \
        __asm__("int $3; nop"); \
    }while(0)
#endif

