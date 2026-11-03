@echo off
title OurNest Desktop Application (ARKIS PTE LTD)
echo Starting OurNest Desktop App...
cd /d "%~dp0"
where python >nul 2>nul
if %errorlevel%==0 (
    start /b "" python -m http.server 8765 --bind 127.0.0.1 >nul 2>nul
    timeout /t 1 /nobreak >nul
    start "" msedge --app="http://127.0.0.1:8765/index.html" 2>nul || start "" chrome --app="http://127.0.0.1:8765/index.html" 2>nul || start "" "http://127.0.0.1:8765/index.html"
) else (
    start "" msedge --app="http://192.168.18.19:8080/app/" 2>nul || start "" chrome --app="http://192.168.18.19:8080/app/" 2>nul || start "" "http://192.168.18.19:8080/app/"
)
