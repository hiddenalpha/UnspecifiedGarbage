#if 0

true `# configure FindFullDisks for NORMAL systems` \
  && CC=gcc \
  && MKDIR_P="mkdir -p" \
  && CFLAGS="-Wall -Werror -pedantic -Os -fmax-errors=1 -Wno-error=unused-variable -Wno-error=unused-function -Isrc/main/c -Iimport/include" \
  && LDFLAGS="-Wl,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-dy,-lpthread,-lws2_w32,-Limport/lib" \
  && true

true `# configure FindFullDisks for BROKEN systems` \
  && CC=x86_64-w64-mingw32-gcc \
  && MKDIR_P="mkdir -p" \
  && CFLAGS="-Wall -Werror -pedantic -Os -fmax-errors=1 -Wno-error=unused-variable -Wno-error=unused-function -Isrc/main/c -Iimport/include" \
  && LDFLAGS="-Wl,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-dy,-lws2_32,-Limport/lib" \
  && true

true `# make FindFullDisks` \
  && ${MKDIR_P:?} build/bin \
  && ${CC:?} -o build/bin/findfulldisks $CFLAGS src/main/c/paisa-fleet/FindFullDisks.c $LDFLAGS \
  && true

#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Garbage.h"

#define FLG_isHelp (1<<0)

#if !NDEBUG
#   define REGISTER register
#   define LOGDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#   define REGISTER
#   define LOGDBG(...)
#endif
#define LOGERR(...) fprintf(stderr, __VA_ARGS__)


typedef  struct FindFullDisks  FindFullDisks;
typedef  struct Device  Device;


struct FindFullDisks {
    int flg;
    const char *sshUser;
    int sshPort;
    int maxParallel, numInProgress;
    struct GarbageEnv **env;
    struct Garbage_CsvIStream **csvSrc;
    struct Garbage_Process **child;
    char *inBuf;
    int inBuf_cap, inBuf_len;
    Device *devices;
    int devices_cap, devices_cnt;
    int iDevice; /* Next device to be triggered. */
    int exitCode;
};


struct Device {
    char hostname[sizeof"lunkwill-0123456789AB"];
    char eddieName[sizeof"eddie12345"];
};


/*BEG fwd decls*/
static void beginNextDevice( void* );
static void feedNextChunkFromStdinToCsvParser( void* );
/*END fwd decls*/


static void printHelp( void ){
    printf("%s%s%s", "  \n"
        "  ", strrchr(__FILE__,'/')+1, "\n"
        "  \n"
        "  Expected format on stdin is:\n"
        "  \n"
        "    eddie00042 <TAB> lunkwill-ABBABEAFABBA <LF>\n"
        "    ...\n"
        "  \n"
        "  Options:\n"
        "  \n"
        "      --sshUser <str>\n"
        "  \n"
        "      --sshPort <int>\n"
        "  \n");
}


static int parseArgs( int argc, char**argv, FindFullDisks*app ){
    int iA = 1;
    app->sshUser = NULL;
    app->sshPort = 22;
    app->maxParallel = 1;
nextArg:;
    const char *arg = argv[iA++];
    if( arg == NULL ) goto validateArgs;
    if( !strcmp(arg, "--help")){
        app->flg |= FLG_isHelp; return 0;
    }else if( !strcmp(arg, "--sshUser")){
        arg = argv[iA++];
        if( arg == NULL ){ LOGERR("EINVAL: Arg --sshUser needs value\n"); return -1; }
        app->sshUser = arg;
    }else if( !strcmp(arg, "--sshPort")){
        arg = argv[iA++];
        if( arg == NULL ){ LOGERR("EINVAL: Arg --sshPort needs value\n"); return -1; }
        errno = 0;
        app->sshPort = strtol(arg, NULL, 0);
        if( errno ){ LOGERR("EINVAL: --sshPort %s\n", arg); return -1; }
    }else{
        LOGERR("EINVAL: %s\n", arg);
    }
    goto nextArg;
validateArgs:;
    if( app->sshUser == NULL ){ LOGERR("EINVAL: Arg --sshUser missing\n"); return -1; }
    return 0;
}


static void no_op( void*_ ){}


static void Child_onStdout( const char*buf, int buf_len, void*cls ){
    //FindFullDisks*const app = cls;
    if( buf_len > 0 ){ /*another chunk*/
        printf("%.*s", buf_len, buf);
    }else{ /*EOF*/
        assert(buf_len == 0);
    }
}


static void Child_onJoined( int retval, int exitCode, int sigNum, void*cls ){
    FindFullDisks*const app = cls;
    LOGDBG("[TRACE] %s(%d, %d, %d)\n", __func__, retval, exitCode, sigNum);
    assert(app->numInProgress > 0);
    app->numInProgress -= 1;
    //LOGDBG("[DEBUG] numInProgress decremented is now %d\n", app->numInProgress);
    (*app->env)->enqueBlocking(app->env, beginNextDevice, app);
}


static void visitDevice( FindFullDisks*app, const Device*device ){
    assert(device != NULL);
    assert(device < app->devices + app->devices_cnt);
    LOGERR("\n[INFO ] %s \"%s\" (behind \"%s\")\n", __func__, device->hostname, device->eddieName);
    int err;
    char eddieCmd[2048];
    err = snprintf(eddieCmd, sizeof eddieCmd, "true"
        " && HOSTNAME=$(hostname|sed 's_.pnet.ch__')"
        " && STAGE=$PAISA_ENV"
        " && printf \"remoteEddieName=$HOSTNAME, remoteStage=$STAGE\\n\""
        " && if test \"$(echo ${HOSTNAME}|sed -E 's_^vted_teddie_g')\" != \"%s\"; then true"
            " && echo wrong host. Want %s found $HOSTNAME && false"
        " ;fi"
        " && ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
        " -p%d %s@%s"
        " -- sh -c 'true"
            " && HOSTNAME=$(hostname|sed '\"'\"'s_.isa.localdomain__'\"'\"')"
            " && STAGE=$PAISA_ENV"
            " && printf \"remoteHostname=$HOSTNAME, remoteStage=$STAGE\\n\""
            // on some machine, df failed with "Stale file handle" But I want to
            // continue with next device regardless of such errors.
            " && df || true"
            "'",
        device->eddieName, device->eddieName, app->sshPort, app->sshUser,
        strncmp("fook-",device->hostname,5) ? device->hostname : "fook"
    );
    assert(err < sizeof eddieCmd);
    assert(app->sshPort > 0 && app->sshPort < 0xFFFF);
    char sshPortStr[12];
    sprintf(sshPortStr, "%d", app->sshPort);
    char userAtEddie[64];
    err = snprintf(userAtEddie, sizeof userAtEddie, "%s@%s", app->sshUser, device->eddieName);
    assert(err < sizeof userAtEddie);
    char *childArgv[] = { "ssh",
        "-oRemoteCommand=none",
        "-oStrictHostKeyChecking=no",
        "-oUserKnownHostsFile=/dev/null",
        "-oConnectTimeout=4",
        "-p", sshPortStr,
        userAtEddie,
        "--", "sh", "-c", eddieCmd,
        NULL
    };
    //LOGDBG("CMDLINE:");
    //for( int i = 0 ; childArgv[i] != NULL ; ++i ) LOGDBG("  \"%s\"", childArgv[i]);
    //LOGDBG("\n\n");
    app->child = (*app->env)->newProcess(app->env, &(struct Garbage_Process_Mentor){
        .cls = app,
        .usePathSearch = !0,
        .argv = childArgv,
        .onStdout = Child_onStdout,
        //.onStderr = Child_onStderr,
        .onJoined = Child_onJoined,
    });
    assert(app->child != NULL);
    (*app->child)->join(app->child, 42000);
}


static void beginNextDevice( void*cls ){
    FindFullDisks *app = cls;
maybeBeginAnotherOne:
    if( app->numInProgress >= app->maxParallel ){
        LOGDBG("[DEBUG] Already %d/%d in progress. Do NOT trigger more for now.\n",
            app->numInProgress, app->maxParallel);
        goto endFn;
    }
    if( app->iDevice >= app->devices_cnt ){
        LOGDBG("[INFO ] Work on %d devices triggered. No more devices to trigger.\n", app->iDevice);
        goto endFn;
    }
    assert(app->iDevice >= 0 && app->iDevice < INT_MAX);
    app->iDevice += 1;
    assert(app->numInProgress >= 0 && app->numInProgress < INT_MAX);
    app->numInProgress += 1;
    visitDevice(app, app->devices + app->iDevice - 1);
    goto maybeBeginAnotherOne;
endFn:;
}


static void onCsvRow( struct Garbage_CsvIStream_BufWithLength*row, int numCols, void*cls ){
    REGISTER int err;
    FindFullDisks *app = cls;
    if( app->exitCode ) return;
    if( numCols != 2 ){
        LOGERR("[ERROR] Expected 2 column in input CSV but found %d\n", numCols);
        app->exitCode = -1; return;
    }
    if( app->devices_cap <= app->devices_cnt ){
        app->devices_cap += 4096;
        void *tmp = realloc(app->devices, app->devices_cap*sizeof*app->devices);
        if( tmp == NULL ) assert(!"TODO_c04CAJtRAgDYWQIAm10CAOAeAgA0KgIA");
        app->devices = tmp;
    }
    #define DEVICE (app->devices + app->devices_cnt)
    if( row[0].len >= sizeof DEVICE->eddieName ){
        LOGERR("[ERROR] eddieName too long: len=%d\n", row[0].len);
        app->exitCode = -1; return;
    }
    if( row[1].len >= sizeof DEVICE->hostname ){
        LOGERR("[ERROR] hostname too long: len=%d\n", row[1].len);
        app->exitCode = -1; return;
    }
    memcpy(DEVICE->eddieName, row[0].buf, row[0].len);
    DEVICE->eddieName[row[0].len] = '\0';
    memcpy(DEVICE->hostname, row[1].buf, row[1].len);
    DEVICE->hostname[row[1].len] = '\0';
    #undef DEVICE
    app->devices_cnt += 1;
}


static void onCsvParserCloseSnkDone( int retval, void*app_ ){
    FindFullDisks *app = app_;
    LOGDBG("[DEBUG] Found %d devices in input.\n", app->devices_cnt);
    (*app->env)->enqueBlocking(app->env, beginNextDevice, app);
}


static void onCsvParserWriteDone( int retval, void*cls ){
    FindFullDisks *app = cls;
    if( retval <= 0 ) assert(!"TODO_bD0CAO1tAgDaNgIACzcCAIsOAgBkXgIA");
    (*app->env)->enqueBlocking(app->env, feedNextChunkFromStdinToCsvParser, app);
}


static void feedNextChunkFromStdinToCsvParser( void*cls ){
    REGISTER int err;
    FindFullDisks *app = cls;
    if( app->exitCode ) return;
    #define SRC (stdin)
    if( app->inBuf == NULL || app->inBuf_cap < 1024 ){
        app->inBuf_cap = 1<<15;
        void *tmp = realloc(app->inBuf, app->inBuf_cap*sizeof*app->inBuf);;
        if( tmp == NULL ){ assert(!"TODO_TT8CAGQLAgCoawIA9jgCANA6AgBTaAIA"); }
        app->inBuf = tmp;
    }
    err = fread(app->inBuf, 1, app->inBuf_cap, SRC);
    if( err <= 0 ){
        (*app->csvSrc)->closeSnk(app->csvSrc, onCsvParserCloseSnkDone, app);
        return;
    }
    app->inBuf_len = err;
    (*app->csvSrc)->write(app->inBuf, app->inBuf_len, app->csvSrc, onCsvParserWriteDone, app);
    #undef SRC
}


static void initCsvParserForDeviceListOnStdin( void*cls ){
    FindFullDisks *app = cls;
    static struct Garbage_CsvIStream_Mentor csvMentor = {
        .onCsvRow = onCsvRow,
        .onCsvDocEnd = no_op,
    };
    static struct Garbage_CsvIStream_Opts csvOpts = { .delimCol = ';' };
    app->csvSrc = (*app->env)->newCsvIStream(app->env, &csvOpts, &csvMentor, app);
    feedNextChunkFromStdinToCsvParser(app);
}


int main( int argc, char**argv ){
    void *envMemory[SIZEOF_struct_GarbageEnv/sizeof(void*)];
    FindFullDisks app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    if( parseArgs(argc, argv, app) ){ app->exitCode = -1; goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->env = GarbageEnv_ctor(envMemory, sizeof envMemory);
    assert(app->env != NULL);
    (*app->env)->enqueBlocking(app->env, initCsvParserForDeviceListOnStdin, app);
    (*app->env)->runUntilDone(app->env);
endFn:
    return !!app->exitCode;
    #undef app
}


