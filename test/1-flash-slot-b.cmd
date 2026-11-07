@echo off
rem Double-click this to write the probe image into slot b.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash-slot-b.ps1"
echo.
pause
