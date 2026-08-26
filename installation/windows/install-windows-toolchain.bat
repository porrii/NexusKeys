@echo off
setlocal

echo ================================================================
echo  NexusKeys - instalador del entorno de compilacion para Windows
echo ================================================================
echo.
echo Esto va a descargar e instalar, en una carpeta que elijas:
echo   - El SDK de Flutter (canal stable)
echo   - Visual Studio Build Tools 2022 (carga C++ de escritorio)
echo   - Habilita el soporte de escritorio Windows en Flutter
echo.
echo Necesitas conexion a internet. La instalacion de Visual Studio
echo Build Tools puede tardar bastante (varios GB).
echo.

set /p INSTALL_DIR="Carpeta donde instalar todo (ej. D:\DevTools\Windows): "

if "%INSTALL_DIR%"=="" (
    echo No se indico ninguna carpeta. Cancelado.
    pause
    exit /b 1
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo.
echo Instalando en: %INSTALL_DIR%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows-toolchain.ps1" -InstallDir "%INSTALL_DIR%"

if errorlevel 1 (
    echo.
    echo Algo fallo durante la instalacion. Revisa el mensaje de arriba.
    pause
    exit /b 1
)

echo.
echo Hecho. Consulta SETUP.md si algo no ha ido como se esperaba.
pause
