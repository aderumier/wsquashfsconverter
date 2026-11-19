/* SensApi.dll stand-in: keeps a multithreaded COM apartment alive for the process
 * (games calling CoCreateInstance from threads that never called CoInitialize rely on
 * an implicit MTA, which Windows usually has and wine doesn't), and answers the SENS calls. */
#include <windows.h>
#include <objbase.h>

static DWORD WINAPI mta_thread(LPVOID arg)
{
    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    SetEvent((HANDLE)arg);
    for (;;) Sleep(INFINITE);
    return 0;
}

BOOL WINAPI IsNetworkAlive(LPDWORD flags) { if (flags) *flags = 1; return TRUE; }
BOOL WINAPI IsDestinationReachableA(LPCSTR dest, void *qoc) { return TRUE; }
BOOL WINAPI IsDestinationReachableW(LPCWSTR dest, void *qoc) { return TRUE; }

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        HANDLE ready = CreateEventW(NULL, TRUE, FALSE, NULL);
        DisableThreadLibraryCalls(inst);
        CloseHandle(CreateThread(NULL, 0, mta_thread, ready, 0, NULL));
        /* the loader lock is held here, so don't wait for CoInitializeEx in DllMain */
        CloseHandle(ready);
    }
    return TRUE;
}
