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


static int appendRaw( char*dst, int*dst_off, int dst_cap, const char*src, int src_len ){
    #define dst_off (*dst_off)
    register int err;
    if( dst_cap < dst_off + src_len ){
        LOGDBG("ENOBUFS: %s Cannot add: %.*s\n", strrchr(__FILE__,'/')+1, src_len, src);
        err = -ENOBUFS; goto endFn;
    }
    memcpy(dst + dst_off, src, src_len);
    dst_off += src_len;
    err = 0;
endFn:
    return err;
    #undef dst_off
}


static int appendQuotEscaped( char*dst, int*dst_off, int dst_cap, const char*src, int src_len ){
    #define dst_off (*dst_off)
    register int err;
    if( dst_cap < dst_off + src_len ){
        LOGDBG("ENOBUFS: %s: cannot append \"%.*s\"\n", strrchr(__FILE__,'/')+1, src_len, src);
        err = -ENOBUFS; goto endFn;
    }
    for(; src[0] != '\0' ; ++src ){
        if( src[0] == '"' ){
            LOGDBG("ENOTSUP: %s not impl to handle quotes inside args (TODO_a9o8uz4rga98orui)\n",
                strrchr(__FILE__,'/'));
            err = -ENOTSUP; goto endFn;
        }
        dst[dst_off++] = src[0];
    }
    err = 0;
endFn:
    return err;
    #undef dst_off
}


static int appendArg( char*cmdline, int*cmdline_len, int cmdline_cap, const char*newArg, int newArg_len ){
    #define cmdline_len (*cmdline_len)
    register int err;
    if( cmdline_cap < cmdline_len + newArg_len + sizeof" \"\"" ){
        LOGDBG("ENOBUFS: %s cmdline too long\n", strrchr(__FILE__,'/')+1);
        err = -ENOBUFS; goto endFn;
    }
    cmdline[cmdline_len++] = ' ';
    cmdline[cmdline_len++] = '"';
    for(; newArg[0] != '\0' ; ++newArg ){
        if( newArg[0] == '"' ){
            LOGDBG("ENOTSUP: %s not impl to handle quotes inside args (TODO_H0cCAJtBAg)\n",
                strrchr(__FILE__,'/'));
            err = -ENOTSUP; goto endFn;
        }
        cmdline[cmdline_len++] = newArg[0];
    }
    cmdline[cmdline_len++] = '"';
    err = 0;
endFn:
    return err;
    #undef cmdline_len
}


static int appendFromEnvironEvenIfEmpty( char*cmdline, int*cmdline_len, int cmdline_cap, const char*envKey ){
    #define cmdline_len (*cmdline_len)
    assert(envKey != NULL);
    register int err;
    char envval[0x7FFF];
    const int envval_cap = sizeof envval;
    err = GetEnvironmentVariable(envKey, envval, envval_cap-1);
    if( err >= envval_cap-1 ){
        LOGDBG("ENOBUFS: %s: environ.%s too long\n", strrchr(__FILE__,'/'), envKey);
        err = -ENOBUFS; goto endFn;
    }
    err = appendArg(cmdline, &cmdline_len, cmdline_cap, envval, err);
    if( err < 0 ) goto endFn;
    cmdline_len += err;
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
        LOGDBG("ENOBUFS: %s: environ.%s too long\n", strrchr(__FILE__,'/'), envKey);
        err = -ENOBUFS; goto endFn;
    }
    if( err > 0 ){
        err = appendArg(cmdline, &cmdline_len, cmdline_cap, envval, err);
        if( err < 0 ) goto endFn;
        cmdline_len += err;
    }
    err = 0;
endFn:
    return err;
    #undef cmdline_len
}


int main( int argc, char**argv ){
    register int err;
    char envval[0x7FFF];
    const int envval_cap = sizeof envval;

    char username[16];
    const int username_cap = sizeof username;
    err = GetEnvironmentVariable("USERNAME", username, username_cap);
    if( err == 0 ){ LOGERR("ERROR: GetEnvironmentVariable(USERNAME) -> 0x%lX\n", GetLastError()); err = -1; goto endFn; }
    if( err > username_cap ){ LOGERR("ENOBUFS: environ.USERNAME too long\n"); err = -1; goto endFn; }
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
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " C:/Users/fankhauseand/.opt/maven/boot/plexus-classworlds-2.5.2.jar", 67) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " -Dclassworlds.conf=C:/Users/fankhauseand/.opt/maven/bin/m2.conf", 64) < 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, " -Dmaven.home=C:/Users/fankhauseand/.opt/maven", 46) < 0
        ;
    if( err ){ LOGDBG("[TRACE] %s:%d\n", __FILE__, __LINE__); goto endFn; }

    char tmpBuf[0x7FFF];
    const int tmpBuf_cap = sizeof tmpBuf;
    err = GetCurrentDirectory(tmpBuf_cap, tmpBuf);
    if( err == 0 ){
        LOGDBG("%s: GetCurrentDirectory() -> 0x%lX\n", strrchr(__FILE__,'/')+1, GetLastError());
        err = -1; goto endFn; }
    if( err >= tmpBuf_cap ){
        LOGDBG("ENOBUFS: %s: working dir too long\n", strrchr(__FILE__,'/')+1);
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
        if( err < 0 ){ LOGDBG("[TRACE] %s:%d\n", __FILE__, __LINE__); goto endFn; }
    }

    //LOGDBG("[DEBUG] cmdline is:\n%.*s\n", cmdline_len, cmdline);

    STARTUPINFOA lpsui = { .lpDesktop = NULL, .lpTitle = NULL, .dwFlags = 0, };
    lpsui.cb = sizeof(lpsui);
    PROCESS_INFORMATION proc;
    /*TODO try BELOW_NORMAL_PRIORITY_CLASS */
    err = CreateProcessA(NULL, cmdline, NULL, NULL, !0, 0, NULL, NULL, &lpsui, &proc);
    if( err == 0 ){
        LOGDBG("[DEBUG] CMDLINE: %.*s\n", cmdline_len, cmdline);
        LOGERR("%s, CreateProcess(): 0x%0lX\n", strrchr(__FILE__,'/')+1, GetLastError());
        err = -1; goto endFn;
    }
    err = WaitForSingleObject(proc.hProcess, INFINITE);
    if( err != WAIT_OBJECT_0 ){ LOGERR("ERROR: %s: WaitForSingleObject() -> %d  %s:%d\n", strrchr(__FILE__,'/')+1, err, __FILE__, __LINE__);
        err = -1; goto endFn; }
    err = 0;
endFn:
    if( err < 0 ) err = -err;
    if( err > 0x7F ) err = 1;
    return err;
}

