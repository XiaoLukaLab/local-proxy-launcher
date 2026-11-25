@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Entry.ps1" -Action Network
set "launcher_code=%errorlevel%"
if not "%launcher_code%"=="0" pause
exit /b %launcher_code%
