@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash-t50.ps1" -Image "%~dp0boot-t50-timed.img" -Sha256 "27074a84b090d5a118ab52e6b66278db1a68bcbfea9cba5c5e4c93f010d3fc9b"
pause
