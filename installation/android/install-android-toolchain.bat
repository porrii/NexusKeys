@echo off
setlocal

echo ================================================================
echo  NexusKeys - instalador del entorno de compilacion para Android
echo ================================================================
echo.
echo Esto va a descargar e instalar, en una carpeta que elijas:
echo   - Temurin JDK 17
echo   - Android SDK command-line tools + platform-tools + build-tools
echo   - El SDK de Flutter (canal stable)
echo   - Variables de entorno persistentes (JAVA_HOME, ANDROID_HOME, PATH)
echo.
echo Necesitas conexion a internet. Puede tardar varios minutos.
echo.

set /p INSTALL_DIR="Carpeta donde instalar todo (ej. D:\DevTools\Android): "

if "%INSTALL_DIR%"=="" (
    echo No se indico ninguna carpeta. Cancelado.
    pause
    exit /b 1
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo.
echo Instalando en: %INSTALL_DIR%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-android-toolchain.ps1" -InstallDir "%INSTALL_DIR%"

if errorlevel 1 (
    echo.
    echo Algo fallo durante la instalacion. Revisa el mensaje de arriba.
    pause
    exit /b 1
)

echo.
echo Hecho. Consulta SETUP.md si algo no ha ido como se esperaba.
pause
