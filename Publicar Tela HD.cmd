@echo off
setlocal
title Publicacao de Tela Facial HD
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Publicar-Tela.ps1"
set "resultado=%errorlevel%"
echo.
pause
exit /b %resultado%
