#include <windows.h>
#define PERL_NO_GET_CONTEXT
#define NO_XSLOCKS
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Win32::Shell		PACKAGE = Win32::Shell

PROTOTYPES: DISABLE

void
FindExecutable(char *document)
PPCODE:
{
    char executable[MAX_PATH];
    HINSTANCE hInst = FindExecutable(document, "", executable);
    if ((int)hInst > 32)
        XSRETURN_PV(executable);
    else
        XSRETURN_UNDEF;
}

void
_ShellExecute(SV *file, SV *parameters)
PPCODE:
{
    SHELLEXECUTEINFO info;
    memset(&info, 0, sizeof(info));
    info.cbSize = sizeof(info);
    info.lpVerb = "open";
    info.nShow = SW_NORMAL;
    if (SvPOK(file))
        info.lpFile = SvPV_nolen(file);
    if (SvPOK(parameters))
        info.lpParameters = SvPV_nolen(parameters);
    if (ShellExecuteEx(&info))
        XSRETURN_IV(0);
    else
        XSRETURN_IV(GetLastError());
}
