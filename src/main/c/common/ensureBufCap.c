

/* [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/c/common/ensureBufCap.c) */
static int ensureBufCap(
    void*(*allocFn)(ptrdiff_t ctx,void*ptr,size_t oldSz,size_t newSz), ptrdiff_t ctx,
    char **buf, int *buf_cap,
    int wanted
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

