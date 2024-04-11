#if 0

true `# configure FindFullDisks for NORMAL systems` \
  && CC=gcc \
  && MKDIR_P="mkdir -p" \
  && CFLAGS="-Wall -Werror -pedantic -Os -fmax-errors=1 -Wno-error=unused-variable -Wno-error=unused-function -Isrc/main/c -Iimport/include" \
  && LDFLAGS="-Wl,-dn,-lgarbage,-dy,-lpthread,-lws2_w32,-Limport/lib" \
  && true

true `# configure FindFullDisks for BROKEN systems` \
  && CC=x86_64-w64-mingw32-gcc \
  && MKDIR_P="mkdir -p" \
  && CFLAGS="-Wall -Werror -pedantic -Os -fmax-errors=1 -Wno-error=unused-variable -Wno-error=unused-function -Isrc/main/c -Iimport/include" \
  && LDFLAGS="-Wl,-dn,-lgarbage,-dy,-lws2_32,-Limport/lib" \
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
    char *sshUser;
    int sshPort;
    int maxParallel, numInProgress;
    struct GarbageEnv **env;
    struct Garbage_Process **child;
    int devices_len;
    Device *devices;
    int iDevice; /* Next device to be triggered. */
    int exitCode;
};


struct Device {
    char hostname[sizeof"lunkwill-0123456789AB"];
    char eddieName[sizeof"eddie12345"];
    char lastSeen[sizeof"2023-12-31T23:59:59"];
};


/*BEG fwd decls*/
static void beginNextDevice( void* );
/*END fwd decls*/


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
    assert(device < app->devices + app->devices_len);
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
    if( app->iDevice >= app->devices_len ){
        LOGDBG("[INFO ] All %d devices started\n", app->iDevice);
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


static void setupExampleDevices( FindFullDisks*app ){
    #define DEVICES_CAP 3
    app->devices_len = 0;
    app->devices = malloc(DEVICES_CAP*sizeof*app->devices);
    assert(app->devices != NULL || !"malloc fail");
    /**/
//    strcpy(app->devices[app->devices_len].eddieName, "eddie09815");
//    strcpy(app->devices[app->devices_len].hostname, "fook-12345");
//    strcpy(app->devices[app->devices_len].lastSeen, "2023-12-31T23:59:59");
//    app->devices_len += 1; assert(app->devices_len < DEVICES_CAP);
//    /**/
//    strcpy(app->devices[app->devices_len].eddieName, "eddie12345");
//    strcpy(app->devices[app->devices_len].hostname, "fook-67890");
//    strcpy(app->devices[app->devices_len].lastSeen, "2023-12-31T23:42:42");
//    app->devices_len += 1; assert(app->devices_len < DEVICES_CAP);
//    /**/
    strcpy(app->devices[app->devices_len].eddieName, "eddie09845");
    strcpy(app->devices[app->devices_len].hostname, "lunkwill-0005b7ec98a9");
    strcpy(app->devices[app->devices_len].lastSeen, "2023-12-31T23:59:42");
    app->devices_len += 1; assert(app->devices_len < DEVICES_CAP);
    /**/
    strcpy(app->devices[app->devices_len].eddieName, "eddie00002");
    strcpy(app->devices[app->devices_len].hostname, "lunkwill-FACEBOOKBABE");
    strcpy(app->devices[app->devices_len].lastSeen, "2023-12-31T23:59:42");
    app->devices_len += 1; assert(app->devices_len < DEVICES_CAP);
    /**/
    #undef DEVICES_CAP
}


int main( int argc, char**argv ){
    static union{ void*align; char space[SIZEOF_struct_GarbageEnv]; } garbMemory;
    FindFullDisks app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->sshUser = "isa"  ;//  "brünzli";
    app->sshPort = 7022  ;//  22;
    app->maxParallel = 1;
    setupExampleDevices(app);
    app->env = GarbageEnv_ctor(&(struct GarbageEnv_Mentor){
        .memBlockToUse = &garbMemory,
        .memBlockToUse_sz = sizeof garbMemory,
    });
    assert(app->env != NULL);
    (*app->env)->enqueBlocking(app->env, beginNextDevice, app);
    (*app->env)->runUntilDone(app->env);
    return !!app->exitCode;
    #undef app
}


