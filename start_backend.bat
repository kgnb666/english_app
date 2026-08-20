@echo off
cd /d "%~dp0backend"

echo ================================================
echo   AI English Coach - Backend Launcher
echo ================================================
echo.
echo  [1/2] LAN address for phone App (Server Settings):
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do echo       http://%%a:8002/api/v1
echo.
echo  [2/2] Starting backend service on http://0.0.0.0:8002 ...
echo        Close this window to stop the service.
echo ================================================
echo.

call ".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8002

echo.
echo Backend service stopped.
pause
