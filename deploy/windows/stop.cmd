@echo off
setlocal
set "_PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%_PS_EXE%" goto run
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "_PS_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe" & goto run
if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" set "_PS_EXE=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" & goto run
echo [error] PowerShell executable not found.
exit /b 1

:run
"%_PS_EXE%" -ExecutionPolicy Bypass -File "%~dp0stop.ps1" %*
set "_EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %_EXIT_CODE%
