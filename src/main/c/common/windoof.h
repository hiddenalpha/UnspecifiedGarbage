
#if 0
#   include <windows.h>
#else

#include <stdint.h>

//#define HANDLE void*
//typedef  int  BOOL;
//typedef  unsigned long  LPDWORD;


typedef struct _PROCESS_INFORMATION {
    void* hProcess;
    void* hThread;
    uint32_t  dwProcessId;
    uint32_t  dwThreadId;
} PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;


typedef struct _SECURITY_ATTRIBUTES {
    uint32_t nLength;
    void* lpSecurityDescriptor;
    int bInheritHandle;
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;


typedef struct _STARTUPINFOA {
  uint32_t cb;
  char *lpReserved;
  char *lpDesktop;
  char *lpTitle;
  uint32_t dwX;
  uint32_t dwY;
  uint32_t dwXSize;
  uint32_t dwYSize;
  uint32_t dwXCountChars;
  uint32_t dwYCountChars;
  uint32_t dwFillAttribute;
  uint32_t dwFlags;
  short wShowWindow;
  short cbReserved2;
  uint8_t lpReserved2;
  void *hStdInput, *hStdOutput, *hStdError;
} STARTUPINFOA, *LPSTARTUPINFOA;



int  CreateProcessA( char const*, char*, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, int, uint32_t,
        void*, char const*, LPSTARTUPINFOA, LPPROCESS_INFORMATION );


int  GetExitCodeProcess(void*, unsigned long*);





#endif /*manual windoof on/off switch*/
