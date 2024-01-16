/*

  Shitty policies require shitty workarounds. Standard maven ships with a 'cmd'
  file for its execution. But as some shiny 'security' policies forbid
  execution of 'cmd' files, we need to waste our time writing stuff like this
  instead doing our work. Grrr...

  ${CC:?} -Wall -Werror -fmax-errors=3 -o build/bin/mvn-launch.exe src/main/c/postshit/launch/mvn/mvn-launch.c -Isrc/main/c/postshit/launch/mvn

*/

#include <windows.h>

#include <assert.h>
#include <stdio.h>

#define LOGDBG(...) fprintf(stderr, __VA_ARGS__)


static int appendArg( char*cmdline, int*cmdline_off, int cmdline_cap, const char*newArg, int newArg_len ){
    #define cmdline_off (*cmdline_off)
    int err;
    if( cmdline_cap < cmdline_off + newArg_len + sizeof" \"\"" ){
        fprintf(stderr, "ENOBUFS: %s cmdline too long\n", strrchr(__FILE__,'/')+1);
        err = -ENOBUFS; goto endFn;
    }
    cmdline[cmdline_off++] = ' ';
    cmdline[cmdline_off++] = '"';
    for(; newArg[0] != '\0' ; ++newArg ){
        if( newArg[0] == '"' ){
            fprintf(stderr, "ENOTSUP: %s not impl to handle quotes inside args (TODO_H0cCAJtBAg)\n",
                strrchr(__FILE__,'/'));
            err = -ENOTSUP; goto endFn;
        }
        cmdline[cmdline_off++] = newArg[0];
    }
    cmdline[cmdline_off++] = '"';
    err = 0;
endFn:
    return err;
    #undef cmdline_off
}


static int appendFromEnvironIfNotEmpty( char*cmdline, int*cmdline_off, int cmdline_cap, const char*envKey ){
    #define cmdline_off (*cmdline_off)
    assert(envKey != NULL);
    int err;
    char envval[0x7FFF];
    const int envval_cap = sizeof envval;
    err = GetEnvironmentVariable(envKey, envval, envval_cap-1);
    if( err >= envval_cap-1 ){
        LOGDBG("ENOBUFS: %s: environ.%s too long\n", strrchr(__FILE__,'/'), envKey);
        err = -ENOBUFS; goto endFn;
    }
    if( cmdline_cap < cmdline_off + err ){
        LOGDBG("ENOBUFS: %s: Argument list too long\n", strrchr(__FILE__,'/'));
        err = -ENOBUFS; goto endFn;
    }
    if( err > 0 ){
        appendArg(cmdline, cmdline_off, cmdline_cap, envval, err);
        cmdline_off += err;
    }
    err = 0;
endFn:
    return err;
    #undef cmdline_off
}


int main( int argc, char**argv ){
    int err;
    char envval[0x7FFF];
    const int envval_cap = sizeof envval;

    /*[see](https://stackoverflow.com/questions/3205027/#comment17734587_3205048)*/
    char cmdline[32767] = ""

        //"%JAVA_HOME%/bin/java.exe"
        "C:/work/tmp/arg-printer.exe"

        //" %MAVEN_OPTS%" /*inherit from environ*/
        //" %MAVEN_DEBUG_OPTS%" /*inherit from environ*/
        " -classpath %CLASSWORLDS_JAR%"
        " -Dclassworlds.conf=C:/Users/fankhauseand/.opt/maven/bin/m2.conf"
        " -Dmaven.home=C:/Users/fankhauseand/.opt/maven" /*MUST NOT end with slash*/
        " -Dmaven.multiModuleProjectDirectory=%WDIR%" /*TODO dir of where the pom resides (LIKELY cwd)*/
        " org.codehaus.plexus.classworlds.launcher.Launcher"
        /*TODO append argv1..argvN here*/
        "\0";
    const int cmdline_cap = sizeof cmdline;
    int cmdline_off = 0;
    for(; cmdline[cmdline_off] != '\0' ; ++cmdline_off );

    err = 0
        || appendFromEnvironIfNotEmpty(cmdline, &cmdline_off, cmdline_cap, "JVM_CONFIG_MAVEN_PROPS")
        || appendFromEnvironIfNotEmpty(cmdline, &cmdline_off, cmdline_cap, "MAVEN_OPTS")
        || appendFromEnvironIfNotEmpty(cmdline, &cmdline_off, cmdline_cap, "MAVEN_DEBUG_OPTS")
        || appendArg(cmdline, &cmdline_off, cmdline_cap, "-classpath", 10)
        ;
    if( err ){ LOGDBG("[TRACE] %s:%d\n", __FILE__, __LINE__); goto endFn; }

    /*append all other args*/
    for( int iA=1 ; iA < argc ; ++iA ){
        char *arg = argv[iA];
        int len = strlen(arg);
        appendArg(cmdline, it-cmdline, cmdline_cap, envval, len);
        it += len;
    }

    fprintf(stderr, "[DEBUG] cmdline is:\n%.*s\n", (int)(it-cmdline), cmdline);

    STARTUPINFOA lpsui = { .lpDesktop = NULL, .lpTitle = NULL, .dwFlags = 0, };
    lpsui.cb = sizeof(lpsui);
    PROCESS_INFORMATION proc;
    fprintf(stderr, "%s: [WARN ] TODO_qgsCALx5AgC2EgIAEggCADEsAgCeawIA\n", strrchr(__FILE__,'/')+1);
    /*TODO try CREATE_NO_WINDOW|BELOW_NORMAL_PRIORITY_CLASS */
    err = CreateProcessA(NULL, cmdline, NULL, NULL, !0, 0,
        NULL, NULL, &lpsui, &proc);
    if( err == 0 ){
        fprintf(stderr, "%s, CreateProcess(): 0x%0lX\n", strrchr(__FILE__,'/')+1, GetLastError());
        err = -1; goto endFn;
    }
    err = 0;
endFn:
    if( err < 0 ) err = -err;
    if( err > 0x7F ) err = 1;
    return err;
}

