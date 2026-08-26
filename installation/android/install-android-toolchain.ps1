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
$script:results = [ordered]@{}
$script:MinFreeGB = 8

# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    [YA ESTABA] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    [FALLO] $msg" -ForegroundColor Red }

function Test-CommandExists($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Ejecuta un comando nativo capturando stdout+stderr sin que reviente.
# En PowerShell 5.1, con $ErrorActionPreference = "Stop" (fijado al
# principio de este script), CUALQUIER salida por stderr de un comando
# nativo - incluidos mensajes normales sin error real, como el propio
# "Cloning into..." de git o el banner de version de java, que Java
# escribe a stderr por diseno - se convierte en un NativeCommandError
# que aborta el script aunque el comando termine con exito. Esta
# funcion aisla ese comportamiento en un unico sitio bien probado en
# vez de repetir el workaround en cada llamada.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$StdIn = $null
    )
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($StdIn) {
            $lines = $StdIn | & $FilePath @ArgumentList 2>&1
        } else {
            $lines = & $FilePath @ArgumentList 2>&1
        }
        $exitCode = $LASTEXITCODE
        $text = ($lines | ForEach-Object { "$_" }) -join "`n"
        return @{ Output = $text; ExitCode = $exitCode; Success = ($exitCode -eq 0 -or $null -eq $exitCode) }
    } catch {
        return @{ Output = "$_"; ExitCode = -1; Success = $false }
    } finally {
        $ErrorActionPreference = $prevEAP
    }
}

function Get-JavaMajorVersion([string]$javaExe) {
    if (-not (Test-Path $javaExe)) { return $null }
    $r = Invoke-Native -FilePath $javaExe -ArgumentList @("-version")
    if ($r.Output -match 'version "?(\d+)') { return [int]$Matches[1] }
    return $null
}

# Descarga con reintentos y backoff exponencial. Devuelve $true/$false.
function Invoke-DownloadWithRetry {
    param(
        [string]$Uri,
        [string]$OutFile,
        [int]$MaxRetries = 3
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "    Descargando (intento $i/$MaxRetries): $Uri"
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 180
            $size = (Get-Item $OutFile -ErrorAction SilentlyContinue).Length
            if ($size -gt 0) {
                Write-Ok "Descargado ($([math]::Round($size / 1MB, 1)) MB)"
                return $true
            }
            throw "El archivo descargado esta vacio"
        } catch {
            Write-Fail "Intento $i fallido: $($_.Exception.Message)"
            Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
            if ($i -lt $MaxRetries) {
                $wait = [math]::Pow(2, $i)
                Write-Host "    Reintentando en $wait s..."
                Start-Sleep -Seconds $wait
            }
        }
    }
    return $false
}

function Test-ZipValid([string]$path) {
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
        $zip.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Test-FreeSpace([string]$path, [int]$minGB) {
    $drive = (Resolve-Path (Split-Path $path -Qualifier)).Path
    $freeBytes = (Get-PSDrive -Name $drive.TrimEnd(':', '\')).Free
    $freeGB = [math]::Round($freeBytes / 1GB, 1)
    return @{ FreeGB = $freeGB; Enough = ($freeGB -ge $minGB) }
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

Write-Step "Comprobando Git..."
$gitFound = Test-CommandExists "git"
if ($gitFound -and -not $Force) {
    $v = (Invoke-Native -FilePath "git" -ArgumentList @("--version")).Output
    Write-Skip "Git ya esta instalado ($v)"
    $script:results["Git"] = "Ya instalado ($v)"
} else {
    if (Test-CommandExists "winget") {
        Write-Host "    Instalando Git con winget..."
        try {
            winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements --silent
            $env:Path = "$env:Path;$env:ProgramFiles\Git\cmd"
            if (Test-CommandExists "git") {
                Write-Ok "Git instalado correctamente"
                $script:results["Git"] = "Instalado con winget"
            } else {
                throw "git sigue sin encontrarse tras la instalacion"
            }
        } catch {
            Write-Fail "No se pudo instalar Git con winget: $($_.Exception.Message)"
            Write-Host "    Plan B: descarga manual desde https://git-scm.com/download/win" -ForegroundColor Yellow
            $script:results["Git"] = "FALLO - instalar manualmente desde git-scm.com"
        }
    } else {
        Write-Fail "winget no esta disponible en esta maquina."
        Write-Host "    Instala Git manualmente desde https://git-scm.com/download/win y vuelve a ejecutar este script." -ForegroundColor Yellow
        $script:results["Git"] = "FALLO - winget no disponible, instalar manualmente"
    }
}

# --------------------------------------------------------------------------
# 2. JDK 17
# --------------------------------------------------------------------------

Write-Step "Comprobando JDK 17..."
$javaHome = $null

# a) JAVA_HOME ya definido y valido
if ($env:JAVA_HOME -and (Get-JavaMajorVersion (Join-Path $env:JAVA_HOME "bin\java.exe")) -eq 17) {
    $javaHome = $env:JAVA_HOME
}

# b) Ubicaciones habituales de instalaciones existentes
if (-not $javaHome) {
    $candidateRoots = @(
        "$env:ProgramFiles\Eclipse Adoptium",
        "$env:ProgramFiles\Java",
        "$env:ProgramFiles\Microsoft",
        "$env:ProgramFiles\Android\Android Studio\jbr",
        (Join-Path $InstallDir "")
    )
    foreach ($root in $candidateRoots) {
        if (-not (Test-Path $root)) { continue }
        $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'jdk-?17' }
        foreach ($d in $dirs) {
            if ((Get-JavaMajorVersion (Join-Path $d.FullName "bin\java.exe")) -eq 17) {
                $javaHome = $d.FullName
                break
            }
        }
        if ($javaHome) { break }
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
    $script:results["JDK 17"] = "Ya instalado en $javaHome"
} else {
    Write-Host "    Descargando Temurin JDK 17..."
    $jdkZip = Join-Path $InstallDir "temurin17.zip"
    $jdkUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
    $downloaded = Invoke-DownloadWithRetry -Uri $jdkUrl -OutFile $jdkZip

    if (-not $downloaded) {
        Write-Fail "No se pudo descargar el JDK tras varios intentos."
        Write-Host "    Plan B: descargalo a mano desde https://adoptium.net/temurin/releases/?version=17 y define JAVA_HOME." -ForegroundColor Yellow
        $script:results["JDK 17"] = "FALLO - descargar manualmente desde adoptium.net"
    } elseif (-not (Test-ZipValid $jdkZip)) {
        Write-Fail "El archivo descargado no es un zip valido (descarga corrupta)."
        Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
        $script:results["JDK 17"] = "FALLO - descarga corrupta, reintenta el script"
    } else {
        try {
            Write-Host "    Extrayendo JDK..."
            Expand-Archive -Path $jdkZip -DestinationPath $InstallDir -Force
            Remove-Item $jdkZip -Force
            $jdkDir = Get-ChildItem -Path $InstallDir -Directory | Where-Object { $_.Name -like "jdk-17*" } | Select-Object -First 1
            if (-not $jdkDir) { throw "No se encontro la carpeta jdk-17* tras extraer" }
            $javaHome = $jdkDir.FullName
            if ((Get-JavaMajorVersion (Join-Path $javaHome "bin\java.exe")) -ne 17) {
                throw "java.exe extraido no reporta version 17"
            }
            Write-Ok "JDK 17 instalado en $javaHome"
            $script:results["JDK 17"] = "Instalado en $javaHome"
        } catch {
            Write-Fail "Error extrayendo/verificando el JDK: $($_.Exception.Message)"
            $script:results["JDK 17"] = "FALLO - $($_.Exception.Message)"
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

$existingRoots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk") | Where-Object { $_ }
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
    $script:results["Android SDK"] = "Ya instalado en $sdkRoot"
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
        $script:results["Android SDK"] = "FALLO - instalar cmdline-tools manualmente"
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
            $script:results["Android SDK"] = "Instalado en $sdkRoot"
        } catch {
            Write-Fail "Error configurando el Android SDK: $($_.Exception.Message)"
            $script:results["Android SDK"] = "FALLO - $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "    Nota: la plataforma (compileSdk/targetSdk) y el NDK los instala Gradle" -ForegroundColor DarkGray
Write-Host "    automaticamente la primera vez que hacen falta (licencias ya aceptadas)." -ForegroundColor DarkGray

# --------------------------------------------------------------------------
# 4. Flutter SDK
# --------------------------------------------------------------------------

Write-Step "Comprobando Flutter..."
$flutterDir = $null

if ((Test-CommandExists "flutter") -and -not $Force) {
    $flutterCmd = (Get-Command flutter).Source
    $flutterDir = Split-Path (Split-Path $flutterCmd)
    $v = ((Invoke-Native -FilePath "flutter" -ArgumentList @("--version")).Output -split "`n" | Select-Object -First 1)
    Write-Skip "Flutter ya esta instalado en $flutterDir ($v)"
    $script:results["Flutter"] = "Ya instalado en $flutterDir"
}

if (-not $flutterDir) {
    $flutterDir = Join-Path $InstallDir "flutter"
    if ((Test-Path (Join-Path $flutterDir "bin\flutter.bat")) -and -not $Force) {
        Write-Skip "Ya existe una copia de Flutter en $flutterDir"
        $script:results["Flutter"] = "Ya instalado en $flutterDir"
    } elseif (-not $gitFound -and -not (Test-CommandExists "git")) {
        Write-Fail "Git no esta disponible, no se puede clonar Flutter."
        Write-Host "    Plan B: descarga el SDK como zip desde https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
        $script:results["Flutter"] = "FALLO - instalar Git primero, o descargar Flutter como zip"
    } else {
        Write-Host "    Clonando el SDK de Flutter (canal stable)..."
        try {
            if (Test-Path $flutterDir) { Remove-Item $flutterDir -Recurse -Force }
            $cloneResult = Invoke-Native -FilePath "git" -ArgumentList @("clone", "--depth", "1", "https://github.com/flutter/flutter.git", "-b", "stable", $flutterDir)
            if (-not (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
                throw "flutter.bat no aparecio tras clonar (git salio con codigo $($cloneResult.ExitCode)): $($cloneResult.Output)"
            }
            Write-Ok "Flutter clonado en $flutterDir"
            $script:results["Flutter"] = "Instalado en $flutterDir"
        } catch {
            Write-Fail "Error clonando Flutter: $($_.Exception.Message)"
            Write-Host "    Plan B: descarga el SDK como zip desde https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
            $script:results["Flutter"] = "FALLO - $($_.Exception.Message)"
        }
    }
}

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

    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $additions = @()
    if ($flutterDir) { $additions += (Join-Path $flutterDir "bin") }
    if ($javaHome) { $additions += (Join-Path $javaHome "bin") }
    if ($sdkRoot) {
        $additions += (Join-Path $sdkRoot "platform-tools")
        $latestTools = Join-Path $sdkRoot "cmdline-tools\latest\bin"
        if (Test-Path $latestTools) { $additions += $latestTools }
    }
    foreach ($a in $additions) {
        if ($oldPath -notlike "*$a*") { $oldPath = "$oldPath;$a" }
        if ($env:Path -notlike "*$a*") { $env:Path = "$env:Path;$a" }
    }
    [System.Environment]::SetEnvironmentVariable("Path", $oldPath, "User")
    Write-Ok "Variables de entorno actualizadas"
} catch {
    Write-Fail "No se pudieron guardar las variables de entorno: $($_.Exception.Message)"
    Write-Host "    Añadelas a mano: JAVA_HOME, ANDROID_HOME, ANDROID_SDK_ROOT y el PATH." -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 6. flutter doctor
# --------------------------------------------------------------------------

if ($flutterDir -and (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
    Write-Step "Ejecutando 'flutter doctor' (primera vez, puede tardar)..."
    & "$flutterDir\bin\flutter.bat" doctor
}

# --------------------------------------------------------------------------
# Resumen final
# --------------------------------------------------------------------------

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host " RESUMEN" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta

$hasFailure = $false
foreach ($key in $script:results.Keys) {
    $value = $script:results[$key]
    if ($value -like "FALLO*") {
        Write-Host ("  {0,-14}: {1}" -f $key, $value) -ForegroundColor Red
        $hasFailure = $true
    } else {
        Write-Host ("  {0,-14}: {1}" -f $key, $value) -ForegroundColor Green
    }
}

Write-Host ""
if ($hasFailure) {
    Write-Host "Algunos componentes necesitan atencion manual (ver arriba y en $logFile)." -ForegroundColor Yellow
    Write-Host "Puedes volver a ejecutar este script las veces que haga falta: lo que" -ForegroundColor Yellow
    Write-Host "ya este instalado correctamente se detecta y no se reinstala." -ForegroundColor Yellow
} else {
    Write-Host "Todo listo." -ForegroundColor Green
}
Write-Host "Abre una terminal NUEVA para que las variables de entorno surtan efecto," -ForegroundColor Green
Write-Host "y ejecuta 'flutter doctor' otra vez para confirmarlo." -ForegroundColor Green
Write-Host "Registro completo guardado en: $logFile"

Stop-Transcript | Out-Null

if ($hasFailure) { exit 1 } else { exit 0 }
