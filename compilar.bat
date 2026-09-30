@echo off
rem Compila NexusKeys para Android o Windows.
rem
rem Antes de compilar, comprueba que esta maquina tiene lo necesario para la
rem plataforma pedida - y SOLO esa: pedir --windows no exige el SDK de
rem Android, ni al reves. Si falta algo, avisa de TODO lo que falta de una
rem vez (con una explicacion y la URL de donde conseguirlo cada uno), en vez
rem de pararse en el primer hueco. No instala nada por si mismo a proposito:
rem cada herramienta (JDK, Android SDK, Visual Studio Build Tools...) la
rem instala el usuario donde y como prefiera.
rem
rem Si todo esta en orden, compila con la salida de flutter/iscc en directo
rem en la consola.
rem
rem Uso:
rem   compilar.bat --android [--limpio] [--debug]
rem   compilar.bat --windows [--instalador] [--limpio] [--debug]
rem   compilar.bat --ayuda
rem
rem Batch puro a proposito (sin depender de un .ps1 aparte): en una maquina
rem Windows nueva, doble clic sobre este archivo ya basta, sin tocar
rem politicas de ejecucion de PowerShell ni nada parecido.

setlocal EnableDelayedExpansion
chcp 65001 >nul
title NexusKeys - Compilar
cd /d "%~dp0"

rem --- Colores ANSI (Windows 10+); si la consola no los soporta, los
rem     codigos de escape no rompen nada, como mucho no se ven bonitos.
for /f %%A in ('echo prompt $E^|cmd') do set "ESC=%%A"
set "C_CYAN=%ESC%[36m"
set "C_GREEN=%ESC%[32m"
set "C_RED=%ESC%[31m"
set "C_YELLOW=%ESC%[33m"
set "C_MAGENTA=%ESC%[35m"
set "C_GRAY=%ESC%[90m"
set "C_RESET=%ESC%[0m"

rem --- Parseo de argumentos --------------------------------------------

set "PLATFORM="
set "INSTALLER=0"
set "CLEANBUILD=0"
set "DEBUGBUILD=0"
set "SKIPCHECKS=0"
set "SHOWHELP=0"

:parse_args
if "%~1"=="" goto args_done
set "ARG=%~1"
rem OJO: aqui hace falta una cadena if/else-if, NO una secuencia de "if"
rem sueltos uno detras de otro - con 9 "if" independientes en fila (uno por
rem cada flag reconocida), este cmd.exe concreto fallaba con "El sistema no
rem encuentra la etiqueta por lotes especificada: args_done" (verificado en
rem vivo, reproducido incluso sin ningun otro codigo alrededor - un limite
rem interno de cmd.exe al analizar muchos "if" simples seguidos, no algo
rem relacionado con el contenido de las comparaciones). La cadena if/else-if
rem de abajo hace exactamente lo mismo pero evita el patron que lo dispara.
if /I "!ARG!"=="--android" (
    set "PLATFORM=android"
) else if /I "!ARG!"=="--windows" (
    set "PLATFORM=windows"
) else if /I "!ARG!"=="--instalador" (
    set "INSTALLER=1"
) else if /I "!ARG!"=="--limpio" (
    set "CLEANBUILD=1"
) else if /I "!ARG!"=="--debug" (
    set "DEBUGBUILD=1"
) else if /I "!ARG!"=="--sin-comprobar" (
    set "SKIPCHECKS=1"
) else if /I "!ARG!"=="--ayuda" (
    set "SHOWHELP=1"
) else if /I "!ARG!"=="-h" (
    set "SHOWHELP=1"
) else if /I "!ARG!"=="--help" (
    set "SHOWHELP=1"
)
shift
goto parse_args
:args_done

if "%SHOWHELP%"=="1" (
    call :usage
    exit /b 0
)
if not defined PLATFORM (
    call :usage
    exit /b 1
)

if "%INSTALLER%"=="1" if not "%PLATFORM%"=="windows" (
    echo %C_YELLOW%--instalador solo tiene sentido con --windows; se ignora.%C_RESET%
    set "INSTALLER=0"
)

call :banner
echo.
echo Plataforma: !PLATFORM!

rem --- Comprobacion de requisitos ---------------------------------------

echo.
echo %C_CYAN%==^> Comprobando requisitos para !PLATFORM!...%C_RESET%
echo.

set /a MISSING=0

where flutter >nul 2>&1
if errorlevel 1 (
    call :missing "Flutter SDK"
    call :detail "Necesario para compilar cualquier plataforma." "https://docs.flutter.dev/get-started/install/windows"
    set /a MISSING+=1
) else (
    call :ok "Flutter SDK"
)

where git >nul 2>&1
if errorlevel 1 (
    call :missing "Git"
    call :detail "Lo usan el propio Flutter SDK y 'flutter pub get'." "https://git-scm.com/download/win"
    set /a MISSING+=1
) else (
    call :ok "Git"
)

if /I "!PLATFORM!"=="android" (
    call :find_java17
    if not defined JAVA17_HOME (
        call :missing "JDK 17"
        call :detail "Gradle/Kotlin de este proyecto necesitan exactamente Java 17, ni 21 ni 11. Instalalo y define JAVA_HOME." "https://adoptium.net/temurin/releases/?version=17"
        set /a MISSING+=1
    ) else (
        call :ok "JDK 17"
    )

    call :find_android_sdk
    if not defined SDK_ROOT (
        call :missing "Android SDK - platform-tools"
        call :detail "Instala las command-line tools, coloca 'adb' en <sdk>\platform-tools\, y define ANDROID_HOME/ANDROID_SDK_ROOT." "https://developer.android.com/studio#command-tools"
        set /a MISSING+=1
    ) else (
        call :ok "Android SDK - platform-tools"
        if exist "!SDK_ROOT!\licenses\android-sdk-license" (
            call :ok "Licencias del Android SDK aceptadas"
        ) else (
            call :missing "Licencias del Android SDK aceptadas"
            call :detail "Ejecuta: sdkmanager --licenses, o flutter doctor --android-licenses." "https://developer.android.com/studio#command-tools"
            set /a MISSING+=1
        )
    )
)

if /I "!PLATFORM!"=="windows" (
    call :check_vc_tools
    if "!VC_OK!"=="1" (
        call :ok "Visual Studio Build Tools - carga C++ de escritorio"
    ) else (
        call :missing "Visual Studio Build Tools - carga C++ de escritorio"
        call :detail "Instala Visual Studio Build Tools 2022, o la IDE completa, con la carga 'Desarrollo para el escritorio con C++' marcada." "https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022"
        set /a MISSING+=1
    )

    if "!INSTALLER!"=="1" (
        call :find_innosetup
        if defined ISCC (
            call :ok "Inno Setup 6 - necesario para --instalador"
        ) else (
            call :missing "Inno Setup 6 - necesario para --instalador"
            call :detail "Necesario solo para empaquetar el instalador .exe; el portable no lo necesita." "https://jrsoftware.org/isinfo.php"
            set /a MISSING+=1
        )
    )
)

if !MISSING! GTR 0 if "!SKIPCHECKS!"=="0" (
    echo.
    echo %C_RED%Requisitos pendientes antes de poder compilar: !MISSING!%C_RESET%
    echo %C_YELLOW%Instala cada cosa donde prefieras y vuelve a ejecutar este script - no hace%C_RESET%
    echo %C_YELLOW%falta que sea todo de golpe, pero no se compilara nada hasta que este todo listo.%C_RESET%
    echo %C_GRAY%--sin-comprobar salta esta comprobacion, para quien ya sabe que esta bien.%C_RESET%
    exit /b 1
)

if !MISSING! GTR 0 (
    echo.
    echo %C_YELLOW%[AVISO] Comprobacion saltada por --sin-comprobar - requisitos pendientes: !MISSING!; si la compilacion falla, sera por esto.%C_RESET%
)

echo.
echo %C_GREEN%Requisitos en orden. Empezando a compilar...%C_RESET%

rem --- Version del proyecto ---------------------------------------------

set "FULLVERSION="
for /f "tokens=1,* delims= " %%K in ('findstr /b /r "^version:" pubspec.yaml') do (
    if not defined FULLVERSION set "FULLVERSION=%%L"
)
if not defined FULLVERSION (
    echo %C_RED%No se pudo leer la version desde pubspec.yaml%C_RESET%
    exit /b 1
)
for /f "delims=+ tokens=1" %%V in ("!FULLVERSION!") do set "VERSION=%%V"
echo Version: !FULLVERSION!

rem --- Compilacion ---------------------------------------------------------

if /I "!PLATFORM!"=="android" (
    if defined JAVA17_HOME set "JAVA_HOME=!JAVA17_HOME!"
    if defined SDK_ROOT (
        set "ANDROID_HOME=!SDK_ROOT!"
        set "ANDROID_SDK_ROOT=!SDK_ROOT!"
    )
)

if "!CLEANBUILD!"=="1" (
    echo.
    echo %C_CYAN%==^> flutter clean%C_RESET%
    call flutter clean
    if errorlevel 1 (
        echo %C_RED%FALLO: flutter clean%C_RESET%
        exit /b 1
    )
)

echo.
echo %C_CYAN%==^> flutter pub get%C_RESET%
call flutter pub get
if errorlevel 1 (
    echo %C_RED%FALLO: flutter pub get%C_RESET%
    exit /b 1
)

if "!DEBUGBUILD!"=="1" (set "BUILDMODE=debug") else (set "BUILDMODE=release")
set "DISTDIR=dist\!PLATFORM!"
if not exist "!DISTDIR!" mkdir "!DISTDIR!"

if /I "!PLATFORM!"=="android" (
    if not exist "key.properties" (
        echo %C_YELLOW%[AVISO] No hay key.properties: el APK se firmara con la clave de depuracion, no valida para una release real.%C_RESET%
    )

    echo.
    echo %C_CYAN%==^> flutter build apk --!BUILDMODE!%C_RESET%
    call flutter build apk --!BUILDMODE!
    if errorlevel 1 (
        echo %C_RED%FALLO: flutter build apk%C_RESET%
        exit /b 1
    )

    set "APKSRC=build\app\outputs\flutter-apk\app-!BUILDMODE!.apk"
    if not exist "!APKSRC!" (
        echo %C_RED%No se encontro el APK generado en !APKSRC!%C_RESET%
        exit /b 1
    )

    set "APKDEST=!DISTDIR!\NexusKeys-!VERSION!.apk"
    copy /Y "!APKSRC!" "!APKDEST!" >nul
    call :ok "APK copiado a !APKDEST!"
)

if /I "!PLATFORM!"=="windows" (
    echo.
    echo %C_CYAN%==^> flutter build windows --!BUILDMODE!%C_RESET%
    call flutter build windows --!BUILDMODE!
    if errorlevel 1 (
        echo %C_RED%FALLO: flutter build windows%C_RESET%
        exit /b 1
    )

    if "!DEBUGBUILD!"=="1" (set "RELEASESUBDIR=Debug") else (set "RELEASESUBDIR=Release")
    set "RELEASEDIR=build\windows\x64\runner\!RELEASESUBDIR!"
    if not exist "!RELEASEDIR!\nexuskeys.exe" (
        echo %C_RED%No se encontro nexuskeys.exe en !RELEASEDIR!%C_RESET%
        exit /b 1
    )

    echo.
    echo %C_CYAN%==^> Empaquetando el portable...%C_RESET%
    set "ZIPDEST=%~dp0!DISTDIR!\NexusKeys-!VERSION!-portable-windows-x64.zip"
    if exist "!ZIPDEST!" del /F /Q "!ZIPDEST!"
    pushd "!RELEASEDIR!"
    tar -a -cf "!ZIPDEST!" *
    set "TARRESULT=!ERRORLEVEL!"
    popd
    if not "!TARRESULT!"=="0" (
        echo %C_RED%FALLO: no se pudo empaquetar el portable con tar%C_RESET%
        exit /b 1
    )
    call :ok "Portable copiado a !DISTDIR!\NexusKeys-!VERSION!-portable-windows-x64.zip"

    if "!INSTALLER!"=="1" (
        call :find_innosetup
        if not defined ISCC (
            echo %C_RED%No se encontro el comando iscc de Inno Setup para empaquetar el instalador.%C_RESET%
            exit /b 1
        )

        echo.
        echo %C_CYAN%==^> Empaquetando el instalador con Inno Setup...%C_RESET%
        "!ISCC!" "windows\installer\nexuskeys.iss"
        if errorlevel 1 (
            echo %C_RED%FALLO: iscc%C_RESET%
            exit /b 1
        )

        set "SETUPSRC=windows\installer\Output\NexusKeys-Setup-!VERSION!.exe"
        if not exist "!SETUPSRC!" (
            echo %C_RED%No se encontro el instalador generado en !SETUPSRC!%C_RESET%
            exit /b 1
        )
        set "SETUPDEST=!DISTDIR!\NexusKeys-Setup-!VERSION!.exe"
        copy /Y "!SETUPSRC!" "!SETUPDEST!" >nul
        call :ok "Instalador copiado a !SETUPDEST!"
    )
)

echo.
echo %C_MAGENTA%========================================================%C_RESET%
echo %C_GREEN% Compilacion completa: !DISTDIR!%C_RESET%
echo %C_MAGENTA%========================================================%C_RESET%
exit /b 0

rem =========================================================================
rem Subrutinas
rem =========================================================================

:banner
echo %C_MAGENTA%========================================================%C_RESET%
echo %C_MAGENTA%   NexusKeys - script de compilacion%C_RESET%
echo %C_MAGENTA%========================================================%C_RESET%
goto :eof

:usage
call :banner
echo.
echo Uso:
echo   compilar.bat --android [--limpio] [--debug]
echo   compilar.bat --windows [--instalador] [--limpio] [--debug]
echo.
echo Opciones:
echo   --android        Compila el APK de Android.
echo   --windows        Compila la app de escritorio Windows (portable).
echo   --instalador     (solo con --windows) Ademas del portable, empaqueta
echo                    el instalador .exe con Inno Setup.
echo   --limpio         Ejecuta 'flutter clean' antes de compilar.
echo   --debug          Compila en modo debug en vez de release.
echo   --sin-comprobar  Salta la comprobacion de requisitos (para quien ya
echo                    sabe que su maquina esta lista).
echo   --ayuda, -h      Muestra esta ayuda.
echo.
echo El resultado se copia a dist\android\ o dist\windows\, nombrado con la
echo version leida de pubspec.yaml.
goto :eof

:ok
echo %C_GREEN%    [OK]    %~1%C_RESET%
goto :eof

:missing
echo %C_RED%    [FALTA] %~1%C_RESET%
goto :eof

:detail
echo         %~1
echo %C_CYAN%        %~2%C_RESET%
goto :eof

rem --- Deteccion de JDK 17 --------------------------------------------------

:check_java_exe
rem %1 = ruta (entre comillas) a java.exe. Deja el major version en JAVA_MAJOR.
rem Vuelca "java -version" a un archivo temporal en vez de leerlo con un
rem for /f sobre un pipe directo - con %1 ya entrecomillado (rutas con
rem espacios), meter ese comando entrecomillado dentro de un for /f
rem ('...' ) confunde el analizado de comillas anidadas de cmd.exe y falla
rem con "el nombre de archivo... no son correctos" (verificado en vivo).
set "JAVA_MAJOR="
if not exist %1 goto :eof
set "JAVATMP=%TEMP%\nk_javaver_%RANDOM%.txt"
%1 -version >"%JAVATMP%" 2>&1
set "JV="
for /f "tokens=3" %%V in ('findstr /i "version" "%JAVATMP%"') do if not defined JV set "JV=%%V"
del /f /q "%JAVATMP%" >nul 2>&1
if not defined JV goto :eof
set "JV=!JV:"=!"
for /f "delims=. tokens=1" %%M in ("!JV!") do set "JAVA_MAJOR=%%M"
goto :eof

:find_java17
set "JAVA17_HOME="

if defined JAVA_HOME (
    call :check_java_exe "%JAVA_HOME%\bin\java.exe"
    if "!JAVA_MAJOR!"=="17" set "JAVA17_HOME=%JAVA_HOME%"
)

if not defined JAVA17_HOME (
    call :check_java_exe "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe"
    if "!JAVA_MAJOR!"=="17" set "JAVA17_HOME=%ProgramFiles%\Android\Android Studio\jbr"
)

if not defined JAVA17_HOME (
    for %%R in ("%ProgramFiles%\Eclipse Adoptium" "%ProgramFiles%\Java" "%ProgramFiles%\Microsoft") do (
        if not defined JAVA17_HOME if exist "%%~R" (
            for /d %%D in ("%%~R\jdk-17*") do (
                if not defined JAVA17_HOME (
                    call :check_java_exe "%%~D\bin\java.exe"
                    if "!JAVA_MAJOR!"=="17" set "JAVA17_HOME=%%~D"
                )
            )
        )
    )
)

if not defined JAVA17_HOME (
    where java >nul 2>&1
    if not errorlevel 1 (
        set "JAVAEXE="
        for /f "delims=" %%J in ('where java') do if not defined JAVAEXE set "JAVAEXE=%%J"
        if defined JAVAEXE (
            call :check_java_exe "!JAVAEXE!"
            if "!JAVA_MAJOR!"=="17" (
                for %%B in ("!JAVAEXE!") do set "JBIN=%%~dpB"
                for %%H in ("!JBIN!..") do set "JAVA17_HOME=%%~fH"
            )
        )
    )
)
goto :eof

rem --- Deteccion del Android SDK --------------------------------------------

:find_android_sdk
set "SDK_ROOT="
for %%R in ("%ANDROID_HOME%" "%ANDROID_SDK_ROOT%" "%LOCALAPPDATA%\Android\Sdk") do (
    if not defined SDK_ROOT if exist "%%~R\platform-tools\adb.exe" set "SDK_ROOT=%%~R"
)
goto :eof

rem --- Deteccion de Visual Studio Build Tools --------------------------------

:find_vswhere
set "VSWHERE="
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not defined VSWHERE if exist "%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
goto :eof

:check_vc_tools
set "VC_OK=0"
call :find_vswhere
if defined VSWHERE (
    for /f "usebackq delims=" %%P in (`"!VSWHERE!" -products * -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath`) do (
        if not "%%P"=="" set "VC_OK=1"
    )
)
goto :eof

rem --- Deteccion de Inno Setup ------------------------------------------------

:find_innosetup
set "ISCC="
where iscc >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%I in ('where iscc') do if not defined ISCC set "ISCC=%%I"
)
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
goto :eof
