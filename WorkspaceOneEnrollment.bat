@echo off
setlocal DisableDelayedExpansion
if not exist "C:\Users\jtomchick\Downloads\AirwatchAgent (18).msi" (
    echo ERROR: AirWatchAgent.msi was not found at the configured path.
    exit /b 2
)

echo Starting Workspace ONE Intelligent Hub enrollment...
msiexec.exe /i "C:\Users\jtomchick\Downloads\AirwatchAgent (18).msi" /q ENROLL=Y SERVER="DS2225.awmdm.com" LGName="JDT1194" USERNAME="staging" PASSWORD="Test" ASSIGNTOLOGGEDINUSER=Y
exit /b %ERRORLEVEL%