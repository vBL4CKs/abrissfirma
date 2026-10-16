@echo off
setlocal
cd /d "%~dp0"
set "GODOT_ENGINE=%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_ENGINE%" (
  echo Bitte Godot 4 von godotengine.org herunterladen und project.godot importieren.
  pause
  exit /b 1
)
start "Godot - Abrissfirma" "%GODOT_ENGINE%" --editor --path "%~dp0."
exit /b 0
