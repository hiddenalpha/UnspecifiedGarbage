/*

  && CC=gcc \
  && LD=gcc \
  && BINEXT= \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-dy,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/e360b4fbce724d9062d src/main/paisa/HoustonLogGet.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/HoustonLogGet$BINEXT /tmp/e360b4fbce724d9062d ${LDFLAGS:?} \

  && bullshit=$(objdump -p build/bin/HoustonLogGet$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$') \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/HoustonLogGet$BINEXT; false; fi \

 */

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Garbage.h"

#define FLG_isHelp (1<<0)

#define STR_QUOT_(s) #s
#define STR_QUOT(s) STR_QUOT_(s)
#define LOGERR(...) fprintf(stderr, __VA_ARGS__);

#if !NDEBUG
#   define REGISTER /*noop*/
#   define LOGDBG(...) fprintf(stderr, __VA_ARGS__);
#else
#   define REGISTER register
#   define LOGDBG(...) /*noop*/
#endif


typedef  struct App  App;


#define App_mAGIC 0x00B9F68A
struct App {
    int mAGIC;
    int flg;
    int exitCode;
    char *namespace;
    struct GarbageEnv **env;
    struct Garbage_Process **child;
    struct Garbage_Process_Mentor childMentor;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  Fetch houston logs (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
    );
}


static int parseArgs( App*app, int argc, char**argv ){
    REGISTER int iA = 0;
nextOpt:;
    char *arg = argv[++iA];
    if( arg == NULL ){
        goto verify;
    }else if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp;
    }else if( !strcmp(arg, "--namespace") || !strcmp(arg, "-n") ){
        arg = argv[++iA];
        if( arg == NULL ){ LOGDBG("EINVAL: %s needs value\n", argv[iA-1]); return -1; }
        app->namespace = arg;
    }else{
        LOGERR("EINVAL: %s\n", arg);
        return -1;
    }
    goto nextOpt;
verify:
    if( argc <= 1 ){ LOGERR("EINVAL: Zero args is not enough\n"); return -1; }
    return 0;
}


static void printToStdout( const char*buf, int buf_len, void*cls ){
    fprintf(stdout, "%.*s", buf_len, buf);
}


static void printToStderr( const char*buf, int buf_len, void*cls ){
    fprintf(stderr, "%.*s", buf_len, buf);
}


static void onChildJoined( int retval, int exitCode, int sigNum, void*app_ ){
    //App*const app = app_;
    LOGDBG("[DEBUG] retval=%d, exitCode=%d, sigNum=%d\n", retval, exitCode, sigNum);
    LOGDBG("[DEBUG] continue here TODO_4604d7352c44b4de8045edb6f27e230d\n");
}


static void TODO_b9371e42e4e5ff6a15df612953f3c105( void*app_ ){
    App*const app = app_;
    assert(app->child == NULL);
    app->childMentor.cls = app;
    app->childMentor.img = NULL;
    app->childMentor.usePathSearch = !0;
    app->childMentor.argv = (char*[]){
        "printf", "  %s",
        "oc", "-n", app->namespace, "get", "pods",
        "\n",
        NULL
    };
    app->childMentor.envp = NULL;
    app->childMentor.workdir = NULL;
    app->childMentor.onStdout = printToStdout;
    app->childMentor.onStderr = printToStderr;
    app->childMentor.onJoined = onChildJoined;
    app->child = (*app->env)->newProcess(app->env, &app->childMentor);
    assert(app->child != NULL);
    (*app->child)->join(app->child, 7000);
}


int main( int argc, char**argv ){
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->mAGIC = App_mAGIC;
    if( parseArgs(app, argc, argv) ){ app->exitCode = -1; goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->env = GarbageEnv_ctor(app->envMemory, sizeof app->envMemory);
    assert(app->env != NULL);
    (*app->env)->enqueBlocking(app->env, TODO_b9371e42e4e5ff6a15df612953f3c105, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}

