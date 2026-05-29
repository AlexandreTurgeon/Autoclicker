@echo off
rem Launch the autoclicker from the virtual environment next to this script.
rem Prefer pythonw.exe so the Tkinter window runs without a console window behind it.

set "VENV=%~dp0.venv"

if not exist "%VENV%\Scripts\python.exe" (
    echo Virtual environment not found at "%VENV%".
    echo.
    echo Set it up first, from this folder:
    echo     py -m venv .venv
    echo     .venv\Scripts\pip install -r requirements.txt
    echo.
    pause
    exit /b 1
)

if exist "%VENV%\Scripts\pythonw.exe" (
    start "" "%VENV%\Scripts\pythonw.exe" "%~dp0autoclicker.py"
) else (
    "%VENV%\Scripts\python.exe" "%~dp0autoclicker.py"
)
