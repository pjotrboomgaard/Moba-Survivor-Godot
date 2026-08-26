@echo off
setlocal
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "GODOT=C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT%" (
    echo Godot not found:
    echo   %GODOT%
    pause
    exit /b 1
)

start "" "%GODOT%" --path "%ROOT%"
endlocal
