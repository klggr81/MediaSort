@echo off
rem MediaSort launcher
rem Starts Run-MediaTools.ps1 in Windows PowerShell as Administrator.
rem Windows shows a UAC prompt; answer Yes to continue.

setlocal
set "SCRIPT=%~dp0Run-MediaTools.ps1"

if not exist "%SCRIPT%" (
    echo Run-MediaTools.ps1 was not found next to run.bat:
    echo   %SCRIPT%
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File','\"%SCRIPT%\"'"

if errorlevel 1 (
    echo.
    echo Could not start PowerShell as Administrator ^(UAC prompt declined?^).
    pause
)
endlocal
