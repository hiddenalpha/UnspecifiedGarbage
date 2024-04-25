/*

SH: true \
SH:   && `# Configure` \
SH:   && CC=x86_64-w64-mingw32-cc \
SH:   && MKDIR_P="mkdir -p" \
SH:   && CFLAGS="-Wall -Werror -pedantic -O0 -g -Isrc/main/c/common -DPROJECT_VERSION=0.0.0-$(date -u +%s) -fmax-errors=1 -Wno-error=unused-variable" \
SH:   && LDFLAGS="-Wl,--gc-sections,--as-needed" \
SH:   && `# Make` \
SH:   && ${MKDIR_P:?} build/bin \
SH:   && ${CC:?} -o build/bin/ocexec ${CFLAGS:?} src/main/c/postshit/launch/openshift/ocexec.c ${LDFLAGS:?} \
SH:   && true

*/

#include <assert.h>
#include <stdio.h>
#include <string.h>
#if __WIN32
#   include <windoof.h>
#endif

#define LOGERR(...) fprintf(stderr, __VA_ARGS__)
#if !NDEBUG
#   define REGISTER
#else
#   define REGISTER register
#endif

#define FLG_isHelp (1<<0)


typedef  struct App  App;


struct App {
    int flg;
    char const *ocNamespace;
};


static void printHelp( void ){
    printf("  \n"
        "  TODO write help page\n"
        "  \n");
}


static int parseArgs( int argc, char**argv, App*app ){
    REGISTER int err;
    int iArg = 1;
    if( argc <= 1 ){ LOGERR("EINVAL: Luke.. use arguments!\n"); return-1; }
nextArg:;
    char const *arg = argv[iArg++];
    if( arg == NULL ) goto verifyArgs;
    if( !strcmp(arg,"--help") ){
        app->flg |= FLG_isHelp;
    }else if( !strcmp(arg,"-n") || !strcmp(arg,"--namespace") ){
        arg = argv[iArg++];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iArg-2]); return-1; }
        app->ocNamespace = arg;
    }else{
        LOGERR("EINVAL: %s\n", arg);
    }
    goto nextArg;
verifyArgs:
    return 0;
}


int main( int argc, char**argv ){
    REGISTER int err;
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    if( !parseArgs(argc, argv, app) ){ err = -1; goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); err = 0; goto endFn; }
endFn:
    return !!err;
    #undef app
}

