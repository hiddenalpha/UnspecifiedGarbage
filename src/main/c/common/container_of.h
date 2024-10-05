#ifndef container_of
#   define container_of(P, T, M) \
        ((T*)( ((size_t)P) - ((size_t)((char*)&((T*)0)->M - (char*)0) )))
#endif
