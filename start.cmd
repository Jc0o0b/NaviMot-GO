@echo off
cd /d "%~dp0"
C:\tools\flutter\bin\dart.bat run --enable-vm-service:0 tool\serve.dart
pause
