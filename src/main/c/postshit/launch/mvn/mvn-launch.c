/*

  Shitty policies require shitty workarounds. Standard maven ships with a 'cmd'
  file for its execution. But as some shiny 'security' policies forbid
  execution of 'cmd' files, we need to waste our time writing stuff like this
  instead doing our work. Grrr...

  ${CC:?} -o build/bin/mvn-launch.exe \
    -Wall -Werror -fmax-errors=3 -Wno-error=unused-function -Wno-error=unused-variable \
    src/main/c/postshit/launch/mvn/mvn-launch.c \
    -Isrc/main/c/postshit/launch/mvn \

*/

#include <windows.h>
#include <assert.h>
#include <stdio.h>

#define LOGERR(...) fprintf(stderr, __VA_ARGS__)
#define LOGDBG(...) fprintf(stderr, __VA_ARGS__)


static int appendRaw( char*dst, int*dst_len, int dst_cap, const char*src, int src_len ){
    #define dst_len (*dst_len)
    register int err;
    if( dst_cap < dst_len + src_len ){
        LOGERR("ENOBUFS: %s Cannot add: %.*s\n", strrchr(__FILE__,'/')+1, src_len, src);
        err = -ENOBUFS; goto endFn;
    }
    memcpy(dst + dst_len, src, src_len);
    dst_len += src_len;
    err = 0;
endFn:
    return err;
    #undef dst_len
}


static int appendQuotEscaped( char*dst, int*dst_len, int dst_cap, const char*src, int src_len ){
    #define dst_len (*dst_len)
    register int err;
    if( dst_cap < dst_len + src_len ){
        LOGDBG("ENOBUFS: %s: cannot append \"%.*s\"\n", strrchr(__FILE__,'/')+1, src_len, src);
        err = -ENOBUFS; goto endFn;
    }
    for( err = 0 ; err < src_len ; ++err ){
        if( src[err] == '"' ){
            LOGERR("ENOTSUP: Quotes in args not impl. %s:%d\n", __FILE__, __LINE__);
            err = -ENOTSUP; goto endFn;
        }
        dst[dst_len++] = src[err];
    }
    err = 0;
endFn:
    return err;
    #undef dst_len
}


static int appendArg( char*cmdline, int*cmdline_len, int cmdline_cap, const char*newArg, int newArg_len ){
    #define cmdline_len (*cmdline_len)
    register int err;
    if( cmdline_cap < cmdline_len + newArg_len + sizeof" \"\"" ){
        LOGERR("ENOBUFS: Cmdline too long. %s:%d\n", strrchr(__FILE__,'/')+1, __LINE__);
        err = -ENOBUFS; goto endFn;
    }
    cmdline[cmdline_len++] = ' ';
    cmdline[cmdline_len++] = '"';
    for( err = 0 ; err < newArg_len ; ++err ){
        if( newArg[err] == '"' ){
            LOGERR("ENOTSUP: Quotes in args not impl. %s:%d\n", strrchr(__FILE__,'/')+1, __LINE__);
            err = -ENOTSUP; goto endFn;
        }
        cmdline[cmdline_len++] = newArg[err];
    }
    cmdline[cmdline_len++] = '"';
    err = 0;
endFn:
    return err;
    #undef cmdline_len
}


static int appendFromEnvironIfNotEmpty( char*cmdline, int*cmdline_len, int cmdline_cap, const char*envKey ){
    #define cmdline_len (*cmdline_len)
    assert(envKey != NULL);
    register int err;
    char envval[0x7FFF];
    const int envval_cap = sizeof envval;
    err = GetEnvironmentVariable(envKey, envval, envval_cap-1);
    if( err >= envval_cap-1 ){
        LOGERR("ENOBUFS: environ.%s too long. %s:%d\n", envKey, strrchr(__FILE__,'/')+1, __LINE__);
        err = -ENOBUFS; goto endFn;
    }
    if( err > 0 ){
        err = appendArg(cmdline, &cmdline_len, cmdline_cap, envval, err);
        if( err < 0 ){ LOGDBG("[TRACE]   at %s:%d\n", __FILE__, __LINE__); goto endFn; }
        cmdline_len += err;
    }
    err = 0;
endFn:
    return err;
    #undef cmdline_len
}


int main( int argc, char**argv ){
    register int err;

    char username[16];
    const int username_cap = sizeof username;
    err = GetEnvironmentVariable("USERNAME", username, username_cap);
    if( err == 0 ){ LOGERR("ERROR: GetEnvironmentVariable(USERNAME) -> 0x%lX\n", GetLastError());
        err = -1; goto endFn; }
    if( err > username_cap ){
        LOGERR("ENOBUFS: environ.USERNAME too long. %s:%d\n", strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    assert(err > 0);
    const int username_len = err;

    char cmdline[32767]; /*[length](https://stackoverflow.com/questions/3205027/#comment17734587_3205048)*/
    cmdline[0] = '\0';
    const int cmdline_cap = sizeof cmdline;
    int cmdline_len = 0;

    err = 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "C:/Users/", 9) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, username, username_len) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "/.opt/java/bin/java.exe", 23) < 0
        || appendFromEnvironIfNotEmpty(cmdline, &cmdline_len, cmdline_cap, "JVM_CONFIG_MAVEN_PROPS") < 0
        || appendFromEnvironIfNotEmpty(cmdline, &cmdline_len, cmdline_cap, "MAVEN_OPTS") < 0
        || appendFromEnvironIfNotEmpty(cmdline, &cmdline_len, cmdline_cap, "MAVEN_DEBUG_OPTS") < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " -classpath", 11) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " C:/Users/", 9) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, username, username_len) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "/.opt/maven/boot/plexus-classworlds-2.5.2.jar", 45) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " -Dclassworlds.conf=C:/Users/", 29) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, username, username_len) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "/.opt/maven/bin/m2.conf", 23) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " -Dmaven.home=C:/Users/", 23) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, username, username_len) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "/.opt/maven", 11) < 0
        ;
    if( err ){ LOGDBG("[TRACE]   at %s:%d\n", __FILE__, __LINE__); goto endFn; }

    char tmpBuf[0x7FFF];
    const int tmpBuf_cap = sizeof tmpBuf;
    err = GetCurrentDirectory(tmpBuf_cap, tmpBuf);
    if( err == 0 ){
        LOGERR("ERROR: GetCurrentDirectory() -> 0x%lX. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    if( err >= tmpBuf_cap ){
        LOGERR("ENOBUFS: Working dir too long. %s:%d\n", strrchr(__FILE__,'/')+1, __LINE__);
        err = -ENOBUFS; goto endFn; }
    assert(err > 0);
    const int tmpBuf_len = err;

    err = 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " \"-Dmaven.multiModuleProjectDirectory=", 38) < 0
        || appendQuotEscaped(cmdline, &cmdline_len, cmdline_cap, tmpBuf, tmpBuf_len) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "\"", 1) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " org.codehaus.plexus.classworlds.launcher.Launcher", 50) < 0
        ;
    if( err ){ LOGDBG("[TRACE] %s:%d", __FILE__, __LINE__); err = -1; goto endFn; }

    /*append all other args*/
    for( int iA=1 ; iA < argc ; ++iA ){
        char *arg = argv[iA];
        err = appendArg(cmdline, &cmdline_len, cmdline_cap, arg, strlen(arg));
        if( err < 0 ){ LOGDBG("[TRACE]   at %s:%d\n", __FILE__, __LINE__); goto endFn; }
    }

    STARTUPINFOA startInfo = { .lpDesktop = NULL, .lpTitle = NULL, .dwFlags = 0, };
    startInfo.cb = sizeof(startInfo);
    PROCESS_INFORMATION proc;
    err = CreateProcessA(NULL, cmdline, NULL, NULL, !0, 0, NULL, NULL, &startInfo, &proc);
    if( err == 0 ){
        LOGERR("[DEBUG] CMDLINE: %.*s\n", cmdline_len, cmdline);
        LOGERR("ERROR: CreateProcess(): 0x%0lX. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn;
    }
    err = WaitForSingleObject(proc.hProcess, INFINITE);
    if( err != WAIT_OBJECT_0 ){ LOGERR("ERROR: WaitForSingleObject() -> %d. %s:%d\n", err, strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    err = 0;
endFn:
    if( err < 0 ) err = -err;
    if( err > 0x7F ) err = 1;
    return err;
}

