/* TODO move compile cmd somewhere better maybe?

true \
  && CFLAGS="-Wall -Werror -pedantic -ggdb -Os -fmax-errors=1 -Wno-error=unused-variable -Wno-error=unused-function" \
  && ${CC:?} -o build/bin/findfulldisks $CFLAGS src/main/c/paisa-fleet/FindFullDisks.c -Isrc/main/c -Iimport/include -Limport/lib -lgarbage -lpthread \
  && true

*/

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Garbage.h"


typedef  struct FindFullDisks  FindFullDisks;
typedef  struct Device  Device;


struct FindFullDisks {
    char *sshUser;
    int sshPort;
    struct GarbageEnv **garb;
    struct Garbage_Process **child;
    int devices_len;
    Device *devices;
};


struct Device {
    char hostname[sizeof"lunkwill-0123456789AB"];
    char eddieName[sizeof"eddie12345"];
    char lastSeen[sizeof"2023-12-31T23:59:59"];
};


static void Child_onStdout( const char*buf, int buf_len, void*cls ){
    //struct FindFullDisks*const app = cls;
    //fprintf(stderr, "[TRACE] %s(buf, %d, cls)\n", __func__, buf_len);
    if( buf_len > 0 ){ /*another chunk*/
        fprintf(stdout, "%.*s", buf_len, buf);
    }else{ /*EOF*/
        assert(buf_len == 0);
    }
}


static void Child_onJoined( int retval, int exitCode, int sigNum, void*cls ){
    //struct FindFullDisks*const app = cls;
    fprintf(stderr, "[TRACE] %s(%d, %d, %d)\n", __func__, retval, exitCode, sigNum);
}


static void visitDevice( struct FindFullDisks*app, const Device*device ){
    assert(device != NULL);
    fprintf(stderr, "[TRACE] %s \"%s\" (behind \"%s\")\n", __func__,
        device->hostname, device->eddieName);
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
    //fprintf(stderr, "CMDLINE:");
    //for( int i = 0 ; childArgv[i] != NULL ; ++i ) fprintf(stderr, "  \"%s\"", childArgv[i]);
    //fprintf(stderr, "\n\n");
    app->child = (*app->garb)->newProcess(app->garb, &(struct Garbage_Process_Mentor){
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


static void startApp( void*cls ){
    struct FindFullDisks *app = cls;
    for( int i = 0 ; i < app->devices_len ; ++i ){
        visitDevice(app, app->devices + i);
    }
}


static void setupExampleDevices( FindFullDisks*app ){
    app->devices_len = 1;
    app->devices = realloc(NULL, app->devices_len*sizeof*app->devices);
    assert(app->devices != NULL || !"ENOMEM");
    /**/
    strcpy(app->devices[0].hostname, "fook-12345");
    strcpy(app->devices[0].eddieName, "eddie09815");
    strcpy(app->devices[0].lastSeen, "2023-12-31T23:59:59");
    /**/
//    strcpy(app->devices[1].hostname, "fook-67890");
//    strcpy(app->devices[1].eddieName, "eddie12345");
//    strcpy(app->devices[1].lastSeen, "2023-12-31T23:42:42");
//    /**/
//    strcpy(app->devices[2].hostname, "lunkwill-12345");
//    strcpy(app->devices[2].eddieName, "eddie09845");
//    strcpy(app->devices[2].lastSeen, "2023-12-31T23:59:42");
//    /**/
}


int main( int argc, char**argv ){
    static union{ void*align; char space[SIZEOF_struct_GarbageEnv]; } garbMemory;
    FindFullDisks app = {
        .sshUser = "brünzli",
        .sshPort = 22,
        .garb = NULL,
        .child = NULL,
        .devices_len = 0,
        .devices = NULL,
    };
    setupExampleDevices(&app);
    app.garb = GarbageEnv_ctor(&(struct GarbageEnv_Mentor){
        .memBlockToUse = &garbMemory,
        .memBlockToUse_sz = sizeof garbMemory,
    });
    assert(app.garb != NULL);
    (*app.garb)->enqueBlocking(app.garb, startApp, &app);
    (*app.garb)->runUntilDone(app.garb);
    return 0;
}


