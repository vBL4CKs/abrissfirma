@echo off
setlocal
cd /d "%~dp0"
set "GODOT_ENGINE=%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_ENGINE%" (
  echo Godot fehlt. Bitte die portable Windows-Version von godotengine.org laden.
  echo Alternativ project.godot in Godot 4 oeffnen und F6 oder F5 druecken.
  pause
  exit /b 1
)
start "Abrissfirma" "%GODOT_ENGINE%" --path "%~dp0."
exit /b 0
