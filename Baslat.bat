@echo off
rem Discord Baslatici - bu dosya byedpi ve goodbyedpi klasorlerinin yaninda durur.

set "PS1=%~dp0byedpi\discord_tepsi.ps1"
if not exist "%PS1%" (
    echo discord_tepsi.ps1 bulunamadi:
    echo %PS1%
    pause
    exit /b
)

start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS1%"
