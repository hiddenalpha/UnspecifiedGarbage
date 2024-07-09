/*

  && HOST_=x86_64-w64-mingw32- \
  && CC=${HOST_}gcc \
  && LD=${HOST_}gcc \
  && OBJDUMP=${HOST_}objdump \
  && BINEXT=.exe \
  && CFLAGS="-Wall -Werror -pedantic -fmax-errors=1 -Iimport/include" \
  && LDFLAGS="-Wl,--gc-sections,--as-needed,-dn,-lgarbage,-lcJSON,-lexpat,-lmbedtls,-lmbedx509,-lmbedcrypto,-lcustom_pthread,-dy,-lws2_32,-Limport/lib" \

  && PROJECT_VERSION="$(date -u +0.0.0-%Y%m%d.%H%M%S)" \
  && mkdir -p build/bin \
  && ${CC:?} -c -o /tmp/ZwQCAGohAgDuOwIA src/main/paisa/JenkinsReBuild.c ${CFLAGS:?} -DPROJECT_VERSION=${PROJECT_VERSION:?} \
  && ${LD:?} -o build/bin/JenkinsReBuild$BINEXT /tmp/ZwQCAGohAgDuOwIA ${LDFLAGS:?} \

  && bullshit=$(${OBJDUMP?} -p build/bin/JenkinsReBuild$BINEXT|grep DLL\ Name|egrep -v ' (KERNEL32.dll|SHELL32.dll|WS2_32.dll|ADVAPI32.dll|msvcrt.dll)$'||true) \
  && if test -n "$bullshit"; then printf '\n  ERROR: Bullshit has sneaked in:\n\n%s\n\n' "$bullshit"; rm build/bin/JenkinsReBuild$BINEXT; false; fi \

 */


typedef  struct App  App;


#define App_mAGIC 0x787C0200
struct App {
    int mAGIC;
    int flg;
    int exitCode;
};


static void printHelp( void ){
    fprintf(stdout, "%s%s%s",
        "  \n"
        "  PatchReverse (v", STR_QUOT(PROJECT_VERSION),").\n"
        "  \n"
        "  Read a patch file from stdin and write it in reversed form to stdout.\n"
        "  \n"
    );
}


static int parseArgs( App*app, int argc, char**argv ){
    register int iA = 0;
nextArg:;
    char *arg = argv[++iA];
    if( arg == NULL ){ goto verify; }
    if( !strcmp(arg, "--help") ){
        app->flg |= FLG_isHelp; return 0;
    }else{
        LOGERR("EINVAL: %s\n", arg); return-1;
    }
    goto nextArg;
verify:
    //if( argc <= 1 ){ LOGERR("EINVAL: Zero-arg-nonsense. Tell me what you want please.\n"); return -1; }
    return 0;
}


static int run( App*app ){
    assert(!"TODO_YHYCAOUsAgAsWAIA");
}


int main( int argc, char**argv ){
    App app = {0}; assert((void*)0 == NULL);
    #define app (&app)
    app->mAGIC = App_mAGIC;
    app->exitCode = -1;
    if( parseArgs(app, argc, argv) ){ goto endFn; }
    if( app->flg & FLG_isHelp ){ printHelp(); goto endFn; }
    app->exitCode = 0;
    run(app);
endFn:
    return !!app->exitCode;
    #undef app
}



