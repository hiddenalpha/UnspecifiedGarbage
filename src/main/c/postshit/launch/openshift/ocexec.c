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
#   define LOGDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#   define REGISTER register
#   define LOGDBG(...)
#endif

#define FLG_isHelp (1<<0)


typedef  struct App  App;


struct App {
    int flg;
    char const *ocNamespace;
    char const *podName;
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
        //LOGDBG("[DEBUG] help -> true\n", arg);
        return 0;
    }else if( !strcmp(arg,"-n") || !strcmp(arg,"--namespace") ){
        arg = argv[iArg++];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iArg-2]); return-1; }
        app->ocNamespace = arg;
        //LOGDBG("[DEBUG] namespace -> \"%s\"\n", arg);
    }else if( !strcmp(arg,"-p") || !strcmp(arg,"--pod") ){
        arg = argv[iArg++];
        if( arg == NULL ){ LOGERR("EINVAL: %s needs value\n", argv[iArg-2]); return-1; }
        app->podName = arg;
        //LOGDBG("[DEBUG] pod -> \"%s\"\n", arg);
    }else{
        LOGERR("EINVAL: %s\n", arg); return -1;
    }
    goto nextArg;
verifyArgs:
    return 0;
}


static int fetchPodnames( App*app ){
    assert(!"TODO_hCICALJrAgDwNgIAZ0ACAD9sAgB5UwIA");
    return -1;
}


static int resolvePodname( App*app ){
    REGISTER int err;
    err = fetchPodnames(app);
    if( err ) return err;
    if( !strcmp(app->podName, "houston") ){
    }
}


static int resolveNamespace( App*app ){
    if(0){
    }else if( !strcmp(app->ocNamespace,"test") ){
        app->ocNamespace = "isa-houston-test";
    }else if( !strcmp(app->ocNamespace,"int") ){
        app->ocNamespace = "isa-houston-int";
    }else if( !strcmp(app->ocNamespace,"preprod") ){
        app->ocNamespace = "isa-houston-preprod";
    }else{
        LOGDBG("[DEBUG] Use oc namespace as provided: \"%s\"\n", app->ocNamespace);
    }
    return 0;
}


static int run( App*app ){
    REGISTER int err;
    err = resolveNamespace(app); if( err ) return err;
    err = resolvePodname(app); if( err ) return err;

    LOGDBG("ENOTSUP: TODO continue here  %s:%d\n", __FILE__, __LINE__);

    PROCESS_INFORMATION proc;
    err = CreateProcessA(NULL, cmdline, NULL, NULL, !0, 0, NULL, NULL, &startInfo, &proc);
    if( err == 0 ){
        LOGERR("ERROR: CreateProcess(): 0x%0lX. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    err = WaitForSingleObject(proc.hProcess, INFINITE);
    if( err != WAIT_OBJECT_0 ){
        LOGERR("ERROR: WaitForSingleObject() -> %lu. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    long unsigned exitCode;
    err = GetExitCodeProcess(proc.hProcess, &exitCode);
    if( err == 0 ){
        LOGERR("ERROR: GetExitCodeProcess(): %lu. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    if( (exitCode & 0x7FFFFFFF) != exitCode ){
        LOGERR("EDOM: Exit code %lu out of bounds. %s:%d\n", exitCode, strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn;
    }
}


int main( int argc, char**argv ){
    REGISTER int err;
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    if( parseArgs(argc, argv, app) ){ err = -1; goto endFn; }
    LOGDBG("[DEBUG] flags are 0x%X\n", app->flg);
    if( app->flg & FLG_isHelp ){ printHelp(); err = 0; goto endFn; }
    err = run(app);
endFn:
    return !!err;
    #undef app
}

