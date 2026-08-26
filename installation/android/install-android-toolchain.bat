@echo off
setlocal

echo ================================================================
echo  NexusKeys - instalador del entorno de compilacion para Android
echo ================================================================
echo.
echo Esto va a comprobar que tienes ya instalado y, para lo que falte,
echo descargarlo e instalarlo en una carpeta que elijas:
echo   - Git (si no esta ya instalado)
echo   - Temurin JDK 17 - se reutiliza si ya tienes un JDK 17 instalado
echo   - Android SDK command-line tools + platform-tools + build-tools
echo     - se reutiliza si ya tienes un Android SDK valido
echo   - El SDK de Flutter (canal stable) - se reutiliza si ya lo tienes
echo   - Variables de entorno persistentes (JAVA_HOME, ANDROID_HOME, PATH)
echo.
echo Si algun paso falla (sin conexion, descarga interrumpida, etc.) el
echo script continua con el resto y te indica al final que revisar a mano.
echo Puedes volver a ejecutarlo las veces que haga falta.
echo.
echo Necesitas conexion a internet. Puede tardar varios minutos.
echo.

set /p INSTALL_DIR="Carpeta donde instalar lo que falte (ej. D:\DevTools\Android): "

if "%INSTALL_DIR%"=="" (
    echo No se indico ninguna carpeta. Cancelado.
    pause
    exit /b 1
)

rem Quita una barra invertida final si la hay (p.ej. "D:\DevTools\") - si no,
rem la comilla de cierre que rodea a %INSTALL_DIR% al pasarlo a PowerShell
rem quedaria escapada por esa barra en vez de cerrar la cadena, y PowerShell
rem recibiria la ruta con una comilla suelta pegada al final.
if "%INSTALL_DIR:~-1%"=="\" set "INSTALL_DIR=%INSTALL_DIR:~0,-1%"

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo.
echo Instalando en: %INSTALL_DIR%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-android-toolchain.ps1" -InstallDir "%INSTALL_DIR%"
set SCRIPT_RESULT=%errorlevel%

echo.
if %SCRIPT_RESULT% neq 0 (
    echo Algunos componentes necesitan atencion manual - revisa el resumen de
    echo arriba, el archivo install-log.txt en la carpeta de instalacion, y
    echo SETUP.md para las alternativas manuales.
    echo.
    echo Nota: si el fallo fue por falta de permisos ^(p.ej. instalando Git
    echo con winget^), prueba a ejecutar este .bat como administrador.
) else (
    echo Todo listo. Consulta SETUP.md si algo no ha ido como se esperaba.
)
pause
