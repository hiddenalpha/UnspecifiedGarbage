#ifndef INCGUARD_8WICAEpuAgDVeQIAui8CAEFpAgBSJQIA
#define INCGUARD_8WICAEpuAgDVeQIAui8CAEFpAgBSJQIA


#define assert(expr) do{if(!(expr)){fprintf(stderr,"assert(%s)  %s:%d\n", #expr, __FILE__, __LINE__);}}while(0)

#define NULL ((void*)0)

#define INT_MAX ((int)0x7FFFFFFF)

#define ENOBUFS 119
#define ENOTSUP 129

#define CREATE_NO_WINDOW 0x08000000

#define BELOW_NORMAL_PRIORITY_CLASS 0x00004000


typedef struct {
    int   cb;
    char* lpReserved;
    char* lpDesktop;
    char* lpTitle;
    int   dwX;
    int   dwY;
    int   dwXSize;
    int   dwYSize;
    int   dwXCountChars;
    int   dwYCountChars;
    int   dwFillAttribute;
    int   dwFlags;
    short wShowWindow;
    short cbReserved2;
    void* lpReserved2;
    void* hStdInput;
    void* hStdOutput;
    void* hStdError;
} STARTUPINFOA;


typedef struct {
  void* hProcess;
  void* hThread;
  int   dwProcessId;
  int   dwThreadId;
} PROCESS_INFORMATION;


typedef struct {
    int   nLength;
    void* lpSecurityDescriptor;
    int   bInheritHandle;
} SECURITY_ATTRIBUTES;


long unsigned GetLastError(void);

int fprintf(struct _iobuf*, const char *, ...);

long long unsigned strlen(const char*);

char *strrchr(const char *s, int c);

int CreateProcessA(
    const char*          lpApplicationName,
    char*                lpCommandLine,
    SECURITY_ATTRIBUTES* lpProcessAttributes,
    SECURITY_ATTRIBUTES* lpThreadAttributes,
    int                  bInheritHandles,
    int                  dwCreationFlags,
    void*                lpEnvironment,
    const char*          lpCurrentDirectory,
    STARTUPINFOA*        lpStartupInfo,
    PROCESS_INFORMATION* lpProcessInformation
);



#endif /* INCGUARD_8WICAEpuAgDVeQIAui8CAEFpAgBSJQIA */
