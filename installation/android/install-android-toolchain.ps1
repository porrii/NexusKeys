#Requires -Version 5.1
<#
  Instalador del entorno de compilacion Android para NexusKeys.
  Detecta herramientas ya instaladas antes de descargar nada, reintenta las
  descargas, verifica cada paso, y sigue adelante (en vez de abortar) si un
  componente concreto falla - al final da un resumen claro de que quedo
  listo y que necesita atencion manual.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir,

    # Fuerza reinstalar aunque ya se detecte una herramienta valida.
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\common.ps1")

$script:MinFreeGB = 8

function Get-JavaMajorVersion([string]$javaExe) {
    if (-not (Test-Path $javaExe)) { return $null }
    $r = Invoke-Native -FilePath $javaExe -ArgumentList @("-version")
    if ($r.Output -match 'version "?(\d+)') { return [int]$Matches[1] }
    return $null
}

# --------------------------------------------------------------------------
# Inicio
# --------------------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$InstallDir = (Resolve-Path $InstallDir).Path

$logFile = Join-Path $InstallDir "install-log.txt"
Start-Transcript -Path $logFile -Append | Out-Null

Write-Host "================================================================" -ForegroundColor Magenta
Write-Host " NexusKeys - entorno de compilacion Android" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta

$space = Test-FreeSpace -path $InstallDir -minGB $script:MinFreeGB
Write-Host "Espacio libre en $($InstallDir): $($space.FreeGB) GB"
if (-not $space.Enough) {
    Write-Fail "Se recomiendan al menos $($script:MinFreeGB) GB libres. Libera espacio antes de continuar."
    $answer = $null
    try {
        $answer = Read-Host "Continuar de todas formas? (s/N)"
    } catch {
        Write-Host "    (No se puede pedir confirmacion en esta sesion; cancelando por seguridad.)" -ForegroundColor Yellow
    }
    if ($answer -notmatch '^[sS]') {
        Stop-Transcript | Out-Null
        exit 1
    }
}

# --------------------------------------------------------------------------
# 1. Git
# --------------------------------------------------------------------------

$gitFound = Install-GitIfMissing -Force:$Force

# --------------------------------------------------------------------------
# 2. JDK 17
# --------------------------------------------------------------------------

Write-Step "Comprobando JDK 17..."
$javaHome = $null

# a) JAVA_HOME ya definido y valido
if ($env:JAVA_HOME -and (Get-JavaMajorVersion (Join-Path $env:JAVA_HOME "bin\java.exe")) -eq 17) {
    $javaHome = $env:JAVA_HOME
}

# b) Ubicaciones habituales de instalaciones existentes. Cada entrada es o
# bien una carpeta que ES DIRECTAMENTE un JDK home (su bin\java.exe cuelga
# justo debajo, como el JBR que trae Android Studio), o bien una carpeta que
# CONTIENE subcarpetas versionadas tipo jdk-17.x.x (como el layout habitual
# de Temurin/Eclipse Adoptium bajo Program Files).
if (-not $javaHome) {
    $directCandidates = @(
        "$env:ProgramFiles\Android\Android Studio\jbr"
    )
    foreach ($root in $directCandidates) {
        if ((Get-JavaMajorVersion (Join-Path $root "bin\java.exe")) -eq 17) {
            $javaHome = $root
            break
        }
    }

    $containerCandidates = @(
        "$env:ProgramFiles\Eclipse Adoptium",
        "$env:ProgramFiles\Java",
        "$env:ProgramFiles\Microsoft",
        $InstallDir
    )
    foreach ($root in $containerCandidates) {
        if ($javaHome -or -not (Test-Path $root)) { continue }
        $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'jdk-?17' }
        foreach ($d in $dirs) {
            if ((Get-JavaMajorVersion (Join-Path $d.FullName "bin\java.exe")) -eq 17) {
                $javaHome = $d.FullName
                break
            }
        }
    }
}

# c) java en el PATH
if (-not $javaHome -and (Test-CommandExists "java")) {
    $javaCmd = (Get-Command java).Source
    if ((Get-JavaMajorVersion $javaCmd) -eq 17) {
        $javaHome = Split-Path (Split-Path $javaCmd)
    }
}

if ($javaHome -and -not $Force) {
    Write-Skip "JDK 17 ya disponible en $javaHome"
    Add-Result "JDK 17" "Ya instalado en $javaHome"
} else {
    Write-Host "    Descargando Temurin JDK 17..."
    $jdkZip = Join-Path $InstallDir "temurin17.zip"
    $jdkUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
    $downloaded = Invoke-DownloadWithRetry -Uri $jdkUrl -OutFile $jdkZip

    if (-not $downloaded) {
        Write-Fail "No se pudo descargar el JDK tras varios intentos."
        Write-Host "    Plan B: descargalo a mano desde https://adoptium.net/temurin/releases/?version=17 y define JAVA_HOME." -ForegroundColor Yellow
        Add-Result "JDK 17" "FALLO - descargar manualmente desde adoptium.net" $true
    } elseif (-not (Test-ZipValid $jdkZip)) {
        Write-Fail "El archivo descargado no es un zip valido (descarga corrupta)."
        Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
        Add-Result "JDK 17" "FALLO - descarga corrupta, reintenta el script" $true
    } else {
        try {
            Write-Host "    Extrayendo JDK..."
            # Limpia extracciones previas de una version distinta antes de
            # descomprimir la nueva - si no, un -Force en una fecha
            # posterior (la URL de Adoptium siempre apunta a "latest", asi
            # que puede traer una version distinta) deja ambas carpetas en
            # disco y la seleccion de cual usar como JAVA_HOME pasa a
            # depender del orden alfabetico, no de cual es la nueva.
            Get-ChildItem -Path $InstallDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "jdk-17*" } |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path $jdkZip -DestinationPath $InstallDir -Force
            Remove-Item $jdkZip -Force
            $jdkDir = Get-ChildItem -Path $InstallDir -Directory | Where-Object { $_.Name -like "jdk-17*" } | Select-Object -First 1
            if (-not $jdkDir) { throw "No se encontro la carpeta jdk-17* tras extraer" }
            $javaHome = $jdkDir.FullName
            if ((Get-JavaMajorVersion (Join-Path $javaHome "bin\java.exe")) -ne 17) {
                throw "java.exe extraido no reporta version 17"
            }
            Write-Ok "JDK 17 instalado en $javaHome"
            Add-Result "JDK 17" "Instalado en $javaHome"
        } catch {
            Write-Fail "Error extrayendo/verificando el JDK: $($_.Exception.Message)"
            Add-Result "JDK 17" "FALLO - $($_.Exception.Message)" $true
            $javaHome = $null
        }
    }
}

# --------------------------------------------------------------------------
# 3. Android SDK command-line tools
# --------------------------------------------------------------------------

Write-Step "Comprobando Android SDK..."
$sdkRoot = $null
$sdkManager = $null

function Find-SdkManager([string]$root) {
    if (-not (Test-Path $root)) { return $null }
    $found = Get-ChildItem -Path (Join-Path $root "cmdline-tools") -Filter "sdkmanager.bat" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    return $found
}

$existingRoots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk") |
    Where-Object { $_ } | Select-Object -Unique
foreach ($root in $existingRoots) {
    $sm = Find-SdkManager $root
    $adb = Join-Path $root "platform-tools\adb.exe"
    if ($sm -and (Test-Path $adb)) {
        $sdkRoot = $root
        $sdkManager = $sm.FullName
        break
    }
}

if ($sdkRoot -and -not $Force) {
    Write-Skip "Android SDK ya disponible en $sdkRoot"
    Add-Result "Android SDK" "Ya instalado en $sdkRoot"
} else {
    Write-Host "    Descargando Android command-line tools..."
    $sdkRoot = Join-Path $InstallDir "Android\Sdk"
    $cmdlineZip = Join-Path $InstallDir "cmdline-tools.zip"
    # Pagina de referencia si esta URL queda desactualizada: https://developer.android.com/studio#command-tools
    $cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $downloaded = Invoke-DownloadWithRetry -Uri $cmdlineUrl -OutFile $cmdlineZip

    if (-not $downloaded -or -not (Test-ZipValid $cmdlineZip)) {
        Write-Fail "No se pudo descargar/validar las command-line tools."
        Write-Host "    Plan B: descargalas a mano desde https://developer.android.com/studio#command-tools" -ForegroundColor Yellow
        Write-Host "    y colocalas en $sdkRoot\cmdline-tools\latest\" -ForegroundColor Yellow
        Remove-Item $cmdlineZip -Force -ErrorAction SilentlyContinue
        Add-Result "Android SDK" "FALLO - instalar cmdline-tools manualmente" $true
    } else {
        try {
            $cmdlineToolsRoot = Join-Path $sdkRoot "cmdline-tools"
            New-Item -ItemType Directory -Force -Path $cmdlineToolsRoot | Out-Null
            Expand-Archive -Path $cmdlineZip -DestinationPath $cmdlineToolsRoot -Force
            Remove-Item $cmdlineZip -Force

            $extracted = Join-Path $cmdlineToolsRoot "cmdline-tools"
            $latest = Join-Path $cmdlineToolsRoot "latest"
            if (Test-Path $extracted) {
                if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }
                Rename-Item $extracted "latest"
            }
            $sdkManager = Join-Path $latest "bin\sdkmanager.bat"
            if (-not (Test-Path $sdkManager)) { throw "sdkmanager.bat no aparecio donde se esperaba" }

            if ($javaHome) { $env:JAVA_HOME = $javaHome }

            Write-Host "    Aceptando licencias del SDK..."
            $licenses = (("y`n") * 30)
            $licResult = Invoke-Native -FilePath $sdkManager -ArgumentList @("--sdk_root=$sdkRoot", "--licenses") -StdIn $licenses
            if (-not $licResult.Success) {
                Write-Host "    Aviso: sdkmanager --licenses devolvio codigo $($licResult.ExitCode); puede que alguna licencia quede sin aceptar." -ForegroundColor Yellow
            }

            Write-Host "    Instalando platform-tools y build-tools..."
            $instResult = Invoke-Native -FilePath $sdkManager -ArgumentList @("--sdk_root=$sdkRoot", "platform-tools", "build-tools;36.0.0")
            if (-not $instResult.Success) {
                Write-Host "    Aviso: sdkmanager devolvio codigo $($instResult.ExitCode) instalando paquetes." -ForegroundColor Yellow
            }

            $adb = Join-Path $sdkRoot "platform-tools\adb.exe"
            if (-not (Test-Path $adb)) { throw "adb.exe no aparecio tras instalar platform-tools" }

            Write-Ok "Android SDK instalado en $sdkRoot"
            Add-Result "Android SDK" "Instalado en $sdkRoot"
        } catch {
            Write-Fail "Error configurando el Android SDK: $($_.Exception.Message)"
            Add-Result "Android SDK" "FALLO - $($_.Exception.Message)" $true
        }
    }
}

Write-Host ""
Write-Host "    Nota: la plataforma (compileSdk/targetSdk) y el NDK los instala Gradle" -ForegroundColor DarkGray
Write-Host "    automaticamente la primera vez que hacen falta (licencias ya aceptadas)." -ForegroundColor DarkGray

# --------------------------------------------------------------------------
# 4. Flutter SDK
# --------------------------------------------------------------------------

$flutterDir = Install-FlutterIfMissing -InstallDir $InstallDir -GitAvailable $gitFound -Force:$Force

# --------------------------------------------------------------------------
# 5. Variables de entorno persistentes
# --------------------------------------------------------------------------

Write-Step "Configurando variables de entorno persistentes (usuario)..."
try {
    if ($javaHome) { [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User") }
    if ($sdkRoot) {
        [System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
        [System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")
    }

    $additions = @()
    if ($flutterDir) { $additions += (Join-Path $flutterDir "bin") }
    if ($javaHome) { $additions += (Join-Path $javaHome "bin") }
    if ($sdkRoot) {
        $additions += (Join-Path $sdkRoot "platform-tools")
        $latestTools = Join-Path $sdkRoot "cmdline-tools\latest\bin"
        if (Test-Path $latestTools) { $additions += $latestTools }
    }
    Add-ToPersistentPath -Paths $additions
    Write-Ok "Variables de entorno actualizadas"
} catch {
    Write-Fail "No se pudieron guardar las variables de entorno: $($_.Exception.Message)"
    Write-Host "    Anadelas a mano: JAVA_HOME, ANDROID_HOME, ANDROID_SDK_ROOT y el PATH." -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 6. flutter doctor
# --------------------------------------------------------------------------

if ($flutterDir -and (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
    Write-Step "Ejecutando 'flutter doctor' (primera vez, puede tardar)..."
    & "$flutterDir\bin\flutter.bat" doctor
}

Write-InstallSummary
Write-Host "Registro completo guardado en: $logFile"

Stop-Transcript | Out-Null

if ($script:hasFailure) { exit 1 } else { exit 0 }
