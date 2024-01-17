/*

  Shitty policies require shitty workarounds. Standard maven ships with a 'cmd'
  file for its execution. But as some shiny 'security' policies forbid
  execution of 'cmd' files, we need to waste our time writing stuff like this
  instead doing our work. Grrr...

  ${CC:?} -o build/bin/mvn-versions-set.exe \
    -Wall -Werror -fmax-errors=3 -Wno-error=unused-function -Wno-error=unused-variable \
    -DPROJECT_VERSION=0.0.0-$(date -u +%s) \
    src/main/c/postshit/launch/mvn/mvn-versions-set.c \

*/

#include <windows.h>
#include <assert.h>
#include <stdio.h>

#define LOGERR(...) fprintf(stderr, __VA_ARGS__)
#define LOGDBG(...) fprintf(stderr, __VA_ARGS__)

#define STR_QUOT_3q9o58uhzjad(s) #s
#define STR_QUOT(s) STR_QUOT_3q9o58uhzjad(s)


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


int main( int argc, char**argv ){
    register int err;
    int isHelp = 0;
    const char *newVersion = NULL;

    /*parse args*/
    for( err = 1 ; err < argc ; ++err ){
        const char *arg = argv[err];
        if( !strcmp(arg, "--help") ){
            isHelp = !0; break;
        }else if( newVersion == NULL ){
            newVersion = arg;
        }else{
            LOGERR("EINVAL: Only ONE arg expected. But got: %s\n", arg); err = -1; goto endFn;
        }
    }
    if( isHelp ){
        printf("\n"
            "  %s  " STR_QUOT(PROJECT_VERSION) "\n"
            "  \n"
            "  Set a specific maven version. Usage:\n"
            "  \n"
            "    %s  0.0.0-SNAPSHOT\n"
            "\n", strrchr(__FILE__,'/')+1, argv[0]);
        err = -1; goto endFn;
    }
    if( newVersion == NULL ){
        LOGERR("EINVAL: new version to use missing. Try --help\n");
        err = -1; goto endFn;
    }
    const int newVersion_len = strlen(newVersion);

    char cmdline[32767]; /*[length](https://stackoverflow.com/questions/3205027/#comment17734587_3205048)*/
    cmdline[0] = '\0';
    const int cmdline_cap = sizeof cmdline;
    int cmdline_len = 0;

    err = 0
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "mvn versions:set -DgenerateBackupPoms=false \"-DnewVersion=", 58) < 0
        || appendQuotEscaped(cmdline, &cmdline_len, cmdline_cap, newVersion, newVersion_len)
        || appendRaw(cmdline, &cmdline_len, cmdline_cap, "\"", 1) < 0
        ;
    if( err ){ LOGDBG("[TRACE]   at %s:%d", __FILE__, __LINE__); err = -1; goto endFn; }

    STARTUPINFOA startInfo = { .lpDesktop = NULL, .lpTitle = NULL, .dwFlags = 0, };
    startInfo.cb = sizeof(startInfo);
    PROCESS_INFORMATION proc;
    err = CreateProcessA(NULL, cmdline, NULL, NULL, !0, 0, NULL, NULL, &startInfo, &proc);
    if( err == 0 ){
        LOGERR("ERROR: CreateProcess(): 0x%0lX. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn;
    }
    err = WaitForSingleObject(proc.hProcess, INFINITE);
    if( err != WAIT_OBJECT_0 ){ LOGERR("ERROR: WaitForSingleObject() -> %lu. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    long unsigned exitCode;
    err = GetExitCodeProcess(proc.hProcess, &exitCode);
    if( err == 0 ){ LOGERR("ERROR: GetExitCodeProcess(): %lu. %s:%d\n", GetLastError(), strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn; }
    if( (exitCode & 0x7FFFFFFF) != exitCode ){
        LOGERR("EDOM: Exit code %lu out of bounds. %s:%d\n", exitCode, strrchr(__FILE__,'/')+1, __LINE__);
        err = -1; goto endFn;
    }
    err = exitCode;
endFn:
    if( err != 0 && cmdline_len > 0 ){ LOGDBG("[DEBUG] %.*s\n", cmdline_len, cmdline); }
    if( err < 0 ) err = -err;
    return err;
}


