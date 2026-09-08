@echo off
setlocal
cd /d "%~dp0"
title BeaverSearch - Dev Launcher

echo ========================================
echo        BeaverSearch - Launcher
echo ========================================
echo.

set "PY_CMD=py -3.12"
%PY_CMD% --version >nul 2>&1
if errorlevel 1 (
    set "PY_CMD=python"
)

%PY_CMD% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3.12 or newer is required.
    echo Install Python 3.12 x64 and enable the Python launcher/PATH.
    echo.
    pause
    exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
    echo [1/3] Creating virtual environment...
    %PY_CMD% -m venv .venv
    if errorlevel 1 goto :fail
) else (
    echo [1/3] Virtual environment found.
)

call ".venv\Scripts\activate.bat"
if errorlevel 1 goto :fail

echo [2/3] Installing/updating BeaverSearch dependencies...
python -m pip install --disable-pip-version-check -e .
if errorlevel 1 goto :fail

echo [3/3] Starting BeaverSearch...
echo.
python -m beaversearch.main
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo BeaverSearch exited with code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%

:fail
echo.
echo [ERROR] BeaverSearch setup failed. See the messages above.
pause
exit /b 1
