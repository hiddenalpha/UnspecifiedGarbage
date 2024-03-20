
typedef  unsigned char  uchar;

#define STRQUOT_ASDFASDF(s) #s
#define STRQUOT(s) STRQUOT_ASDFASDF(s)
#ifndef PROJECT_VERSION
#   define PROJECT_VERSION 0.0.0-SNAPSHOT
#endif

#if __WIN32
    int _setmode(int,int);
#   define FUCK_BROKEN_SYSTEMS() do{char a=0;for(;!(a&10);){_setmode(a++,32768);}}while(0)
#else
#   define FUCK_BROKEN_SYSTEMS()
#endif

