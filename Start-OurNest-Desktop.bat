@echo off
title OurNest Desktop Application (ARKIS PTE LTD)
echo Starting OurNest Desktop App...
cd /d "%~dp0"

rem Audit F28: the old fallback opened http://192.168.18.19:8080 - a private
rem developer machine on a local network, over plain http. It now only runs the
rem bundled copy on this PC, and otherwise explains what to do.

where python >nul 2>nul
if %errorlevel%==0 (
    start /b "" python -m http.server 8765 --bind 127.0.0.1 >nul 2>nul
    timeout /t 1 /nobreak >nul
    start "" msedge --app="http://127.0.0.1:8765/index.html" 2>nul || start "" chrome --app="http://127.0.0.1:8765/index.html" 2>nul || start "" "http://127.0.0.1:8765/index.html"
    exit /b 0
)

echo.
echo  Python was not found on this computer, so the desktop copy cannot start.
echo.
echo  Easiest option: open the OurNest web app in Microsoft Edge or Chrome,
echo  then choose "Install OurNest" from the browser menu. It will then open
echo  like a normal Windows app from the Start menu.
echo.
echo  Or install Python from https://www.python.org/downloads/ and run this file again.
echo.
pause
