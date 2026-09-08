@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title BeaverSearch - Dev Launcher

echo ========================================
echo        BeaverSearch - Launcher
echo ========================================
echo.

call :detect_python
if defined PY_CMD goto :python_ready

echo [WARN] Compatible Python was not found.
echo BeaverSearch needs Python 3.12 or newer.
echo.
where winget >nul 2>&1
if errorlevel 1 goto :no_python

choice /C YN /N /M "Install Python 3.12 x64 automatically with winget? [Y/N]: "
if errorlevel 2 goto :no_python

echo.
echo [BOOTSTRAP] Installing Python 3.12 x64...
winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo.
    echo [ERROR] Python installation failed.
    echo Try manually: winget install --id Python.Python.3.12 -e
    pause
    exit /b 1
)

echo.
echo [BOOTSTRAP] Python installation finished. Detecting it...
call :detect_python
if not defined PY_CMD goto :no_python

:python_ready
echo [OK] Using: %PY_CMD%
%PY_CMD% --version
if errorlevel 1 goto :no_python

echo.
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
python -m pip install --disable-pip-version-check --upgrade pip
if errorlevel 1 goto :fail
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

:detect_python
set "PY_CMD="

rem Prefer the Windows Python launcher when available.
py -3.13 -c "import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py -3.13"
    goto :eof
)
py -3.12 -c "import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py -3.12"
    goto :eof
)

rem Try Python exposed directly through PATH.
python -c "import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    goto :eof
)
python3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python3"
    goto :eof
)

rem Python.org/winget default per-user locations. These also work immediately
rem after winget installation even before a new terminal inherits PATH changes.
if exist "%LocalAppData%\Programs\Python\Python313\python.exe" (
    set "PY_CMD=^"%LocalAppData%\Programs\Python\Python313\python.exe^""
    goto :eof
)
if exist "%LocalAppData%\Programs\Python\Python312\python.exe" (
    set "PY_CMD=^"%LocalAppData%\Programs\Python\Python312\python.exe^""
    goto :eof
)
if exist "%ProgramFiles%\Python313\python.exe" (
    set "PY_CMD=^"%ProgramFiles%\Python313\python.exe^""
    goto :eof
)
if exist "%ProgramFiles%\Python312\python.exe" (
    set "PY_CMD=^"%ProgramFiles%\Python312\python.exe^""
    goto :eof
)

rem Also check the standalone launcher location installed by python.org.
if exist "%LocalAppData%\Programs\Python\Launcher\py.exe" (
    "%LocalAppData%\Programs\Python\Launcher\py.exe" -3.12 -c "import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)" >nul 2>&1
    if not errorlevel 1 set "PY_CMD=^"%LocalAppData%\Programs\Python\Launcher\py.exe^" -3.12"
)
goto :eof

:no_python
echo.
echo [ERROR] Python 3.12+ is still unavailable.
echo Install it with this command:
echo.
echo     winget install --id Python.Python.3.12 -e

echo.
echo Then run run.bat again.
pause
exit /b 1

:fail
echo.
echo [ERROR] BeaverSearch setup failed. See the messages above.
pause
exit /b 1
