@echo off
setlocal

rem Visual Studio Build Tools necesita permisos de administrador para
rem instalarse. Si no los tenemos, nos relanzamos a nosotros mismos con UAC.
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Se necesitan permisos de administrador. Solicitando elevacion...
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop } catch { Write-Host 'No se concedieron permisos de administrador.' -ForegroundColor Red; exit 1 }"
    if errorlevel 1 (
        echo.
        echo No se pudo obtener permisos de administrador ^(cancelaste el aviso de UAC,
        echo o esta bloqueado por politica^). Vuelve a ejecutar este .bat y acepta el
        echo aviso, o hazlo tu mismo con boton derecho ^> Ejecutar como administrador.
        pause
    )
    exit /b
)

echo ================================================================
echo  NexusKeys - instalador del entorno de compilacion para Windows
echo ================================================================
echo.
echo Esto va a comprobar que tienes ya instalado y, para lo que falte,
echo descargarlo e instalarlo en una carpeta que elijas:
echo   - Git (si no esta ya instalado)
echo   - El SDK de Flutter (canal stable) - se reutiliza si ya lo tienes
echo   - Visual Studio Build Tools 2022, carga C++ de escritorio
echo     (se salta si ya tienes Visual Studio con esa carga instalada)
echo   - Habilita el soporte de escritorio Windows en Flutter
echo.
echo Si algun paso falla (sin conexion, descarga interrumpida, etc.) el
echo script continua con el resto y te indica al final que revisar a mano.
echo Puedes volver a ejecutarlo las veces que haga falta.
echo.
echo Necesitas conexion a internet. La instalacion de Visual Studio
echo Build Tools puede tardar bastante (varios GB, 15-40 minutos).
echo.

set /p INSTALL_DIR="Carpeta donde instalar lo que falte (ej. D:\DevTools\Windows): "

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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows-toolchain.ps1" -InstallDir "%INSTALL_DIR%"
set SCRIPT_RESULT=%errorlevel%

echo.
if %SCRIPT_RESULT% neq 0 (
    echo Algunos componentes necesitan atencion manual - revisa el resumen de
    echo arriba, el archivo install-log.txt en la carpeta de instalacion, y
    echo SETUP.md para las alternativas manuales.
) else (
    echo Todo listo. Consulta SETUP.md si algo no ha ido como se esperaba.
)
pause
