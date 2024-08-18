
#define BREAK() do{ \
    LOGDBG("Hardcoded breakpoint @ %s:%d\n", __FILE__, __LINE__); \
    __asm__("int $3; nop"); \
}while(0)

