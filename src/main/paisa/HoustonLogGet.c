/*

  && CC=gcc \
  && LD=gcc \
  && OBJDUMP=objdump \
  && BINEXT= \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-lcustom_pthread,-dy,-lws2_32,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/e360b4fbce724d9062d src/main/paisa/HoustonLogGet.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/HoustonLogGet$BINEXT /tmp/e360b4fbce724d9062d ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/HoustonLogGet$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/HoustonLogGet$BINEXT; false; fi \

 */

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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
    char *getPodsBuf;
    int getPodsBuf_len, getPodsBuf_cap;
    char *currentOutfilePath;
    FILE *currentOutfileFd;
    char podName[sizeof"houston-12345-abcde"];
    int podName_len;
    struct GarbageEnv **env;
    struct Garbage_Process **child;
    struct Garbage_Process_Mentor childMentor;
    void *envMemory[SIZEOF_struct_GarbageEnv / sizeof(void*)];
};


char* strerrname(int);


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  Fetch houston logs (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "    -n <str>, --namespace <str>\n"
        "      Namespace to use.\n"
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


//static void printToStdout( const char*buf, int buf_len, void*cls ){
//    fprintf(stdout, "%.*s", buf_len, buf);
//}


static void printToStderr( const char*buf, int buf_len, void*cls ){
    fprintf(stderr, "%.*s", buf_len, buf);
}


static void appendToCurrentOutfile( const char*buf, int buf_len, void*app_ ){
    REGISTER int err;
    App*const app = app_;
    if( app->exitCode ) return;
    if( app->currentOutfileFd == NULL ){
        app->currentOutfileFd = fopen(app->currentOutfilePath, "wb");
        if( app->currentOutfileFd == NULL ){
            app->exitCode = -errno;
            LOGERR("%s: fopen(%s)\n", strerrname(errno), app->currentOutfilePath);
            return;
        }
    }
    err = fwrite(buf, 1, buf_len, app->currentOutfileFd);
    if( err != buf_len ){
        app->exitCode = -errno;
        LOGDBG("%s: fwrite(%s)\n", strerrname(errno), app->currentOutfilePath);
        return;
    }
}


static void onZipDownloadJoined( int retval, int exitCode, int sigNum, void*app_ ){
    App*const app = app_;
    if( retval || exitCode || sigNum ){
        LOGDBG("[DEBUG] retval=%d, exitCode=%d, sigNum=%d\n", retval, exitCode, sigNum);
    }
    if( app->currentOutfileFd != NULL ){ fclose(app->currentOutfileFd); app->currentOutfileFd = NULL; }
    LOGDBG("[DEBUG] TODO_rlECAAMaAgDrFQIA continue here\n");
}


static void beginZipDownload( void*app_ ){
    REGISTER int err;
    App*const app = app_;
    assert(app->child == NULL);
    static char tmpName[sizeof"./houston-20241231-235959Z.tgz"];
    time_t t = time(NULL);
    struct tm *tm = gmtime(&t);
    err = strftime(tmpName, sizeof tmpName, "./houston-%Y%m%d-%H%M%SZ.tgz", tm);
    if( err != sizeof tmpName -1 ){ LOGDBG("assert(strftime() != %d)  %s:%d\n", err, __FILE__, __LINE__); abort(); }
    LOGDBG("[DEBUG] currentOutfilePath := '%s'\n", tmpName);
    app->currentOutfilePath = tmpName;
    app->childMentor.cls = app;
    app->childMentor.img = NULL;
    app->childMentor.usePathSearch = !0;
    app->childMentor.argv = (char*[]){
        //"printf", "  %s",
        "oc", "-n", app->namespace, "exec", "-i", app->podName, "--",
            "sh", "-c", "cd /usr/local/vertx/logs && tar cz $(ls -d houston.log* | sort -r)",
        NULL
    };
    app->childMentor.envp = NULL;
    app->childMentor.workdir = NULL;
    app->childMentor.onStdout = appendToCurrentOutfile;
    app->childMentor.onStderr = printToStderr;
    app->childMentor.onJoined = onZipDownloadJoined;
    app->child = (*app->env)->newProcess(app->env, &app->childMentor);
    assert(app->child != NULL);
    (*app->child)->join(app->child, 7000);
}


static void appendToGetPodsBuf( const char*buf, int buf_len, void*app_ ){
    App*const app = app_;
    if( app->getPodsBuf_cap < app->getPodsBuf_len + buf_len ){
        app->getPodsBuf_cap += 4096;
        void *tmp = realloc(app->getPodsBuf, app->getPodsBuf_cap*sizeof*app->getPodsBuf);
        if( tmp == NULL ){ assert("realloc() != NULL"); abort(); }
        app->getPodsBuf = tmp;
    }
    memcpy(app->getPodsBuf + app->getPodsBuf_len, buf, buf_len);
    app->getPodsBuf_len += buf_len;
}


static void onGetPodsJoined( int retval, int exitCode, int sigNum, void*app_ ){
    App*const app = app_;
    if( retval || exitCode || sigNum ){
        LOGDBG("[DEBUG] retval=%d, exitCode=%d, sigNum=%d\n", retval, exitCode, sigNum);
    }
    //LOGDBG("[DEBUG] buffer contains %d bytes\n", app->getPodsBuf_len);
    (*app->child)->unref(app->child); app->child = NULL;
    /*search for 'houston' in there*/
    int rd = 0;
    int off, len;
checkIfHouston:
    if( rd + 10 > app->getPodsBuf_len ){ goto nothingFound; }
    if( !memcmp(app->getPodsBuf + rd, "houston-", 8) ){
        off = rd;
        goto seekEndOfHoustonName;
    }else{
        goto seekBeginOfNextLine;
    }
seekEndOfHoustonName:
    for(;; ++rd ){
        if( rd +1 > app->getPodsBuf_len ){ goto nothingFound; }
        if( app->getPodsBuf[rd] == ' ' ){
            len = rd - off;
            goto houstonPodNameFound;
        }
    }
seekBeginOfNextLine:
    for(;; ++rd ){
        if( rd +1 > app->getPodsBuf_len ){ goto nothingFound; }
        if( app->getPodsBuf[rd] == '\n' ){ rd += 1; goto checkIfHouston; }
    }
nothingFound:
    LOGERR("[ERROR] Couldn't find houston pod\n");
    app->exitCode = -1;
    return;
houstonPodNameFound:
    LOGDBG("[DEBUG] podName := '%.*s'\n", len, app->getPodsBuf + off);
    if( len +1 >= sizeof app->podName ){ assert(!"TODO_WEsCAEhMAgDWYgIA podName_len"); abort(); }
    app->podName_len = len;
    memcpy(app->podName, app->getPodsBuf + off, len);
    app->podName[app->podName_len] = '\0';
    (*app->env)->enqueBlocking(app->env, beginZipDownload, app);
    return;
}


static void getHoustonPodname( void*app_ ){
    App*const app = app_;
    assert(app->child == NULL);
    app->childMentor.cls = app;
    app->childMentor.img = NULL;
    app->childMentor.usePathSearch = !0;
    app->childMentor.argv = (char*[]){
        //"printf", "  %s",
        "oc", "-n", app->namespace, "get", "pods",
        NULL
    };
    app->childMentor.envp = NULL;
    app->childMentor.workdir = NULL;
    app->childMentor.onStdout = appendToGetPodsBuf;
    app->childMentor.onStderr = printToStderr;
    app->childMentor.onJoined = onGetPodsJoined;
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
    app->exitCode = 0;
    (*app->env)->enqueBlocking(app->env, getHoustonPodname, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}

