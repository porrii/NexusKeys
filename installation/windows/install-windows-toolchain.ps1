#Requires -Version 5.1
<#
  Instalador del entorno de compilacion Windows (desktop) para NexusKeys.
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
$script:MinFreeGB = 15
$VCWorkloadId = "Microsoft.VisualStudio.Workload.VCTools"

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
# "Cloning into..." de git - se convierte en un NativeCommandError que
# aborta el script aunque el comando termine con exito. Esta funcion
# aisla ese comportamiento en un unico sitio bien probado en vez de
# repetir el workaround en cada llamada.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @()
    )
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = & $FilePath @ArgumentList 2>&1
        $exitCode = $LASTEXITCODE
        $text = ($lines | ForEach-Object { "$_" }) -join "`n"
        return @{ Output = $text; ExitCode = $exitCode; Success = ($exitCode -eq 0 -or $null -eq $exitCode) }
    } catch {
        return @{ Output = "$_"; ExitCode = -1; Success = $false }
    } finally {
        $ErrorActionPreference = $prevEAP
    }
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-DownloadWithRetry {
    param([string]$Uri, [string]$OutFile, [int]$MaxRetries = 3)
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

function Test-FreeSpace([string]$path, [int]$minGB) {
    $drive = (Resolve-Path (Split-Path $path -Qualifier)).Path
    $freeBytes = (Get-PSDrive -Name $drive.TrimEnd(':', '\')).Free
    $freeGB = [math]::Round($freeBytes / 1GB, 1)
    return @{ FreeGB = $freeGB; Enough = ($freeGB -ge $minGB) }
}

function Find-VsWhere {
    $paths = @(
        "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe",
        "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

function Test-VCToolsInstalled {
    $vswhere = Find-VsWhere
    if (-not $vswhere) { return $false }
    $r = Invoke-Native -FilePath $vswhere -ArgumentList @("-products", "*", "-requires", $VCWorkloadId, "-property", "installationPath")
    return [bool]($r.Output.Trim())
}

# --------------------------------------------------------------------------
# Inicio
# --------------------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$InstallDir = (Resolve-Path $InstallDir).Path

$logFile = Join-Path $InstallDir "install-log.txt"
Start-Transcript -Path $logFile -Append | Out-Null

Write-Host "================================================================" -ForegroundColor Magenta
Write-Host " NexusKeys - entorno de compilacion Windows (desktop)" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta

if (-not (Test-IsAdmin)) {
    Write-Fail "Este script necesita permisos de administrador para instalar Visual Studio Build Tools."
    Write-Host "    Vuelve a ejecutar install-windows-toolchain.bat con 'Ejecutar como administrador'." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 1
}

$space = Test-FreeSpace -path $InstallDir -minGB $script:MinFreeGB
Write-Host "Espacio libre en $($InstallDir): $($space.FreeGB) GB"
if (-not $space.Enough) {
    Write-Fail "Se recomiendan al menos $($script:MinFreeGB) GB libres (Visual Studio Build Tools ocupa varios GB)."
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
                $gitFound = $true
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
# 2. Flutter SDK
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
    } elseif (-not $gitFound) {
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

if ($flutterDir) { $env:Path = "$env:Path;$flutterDir\bin" }

# --------------------------------------------------------------------------
# 3. Visual Studio Build Tools (carga C++ de escritorio)
# --------------------------------------------------------------------------

Write-Step "Comprobando Visual Studio (carga C++ de escritorio)..."
if ((Test-VCToolsInstalled) -and -not $Force) {
    Write-Skip "Ya hay una instalacion de Visual Studio con la carga C++ de escritorio"
    $script:results["VS Build Tools"] = "Ya instalado"
} else {
    Write-Host "    Descargando el instalador de Visual Studio Build Tools 2022..."
    $vsInstallDir = Join-Path $InstallDir "VSBuildTools"
    $bootstrapper = Join-Path $InstallDir "vs_buildtools.exe"
    $downloaded = Invoke-DownloadWithRetry -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $bootstrapper

    if (-not $downloaded) {
        Write-Fail "No se pudo descargar el instalador de Visual Studio."
        Write-Host "    Plan B: descargalo a mano desde https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor Yellow
        Write-Host "    y marca la carga 'Desarrollo para el escritorio con C++'." -ForegroundColor Yellow
        $script:results["VS Build Tools"] = "FALLO - descargar manualmente"
    } else {
        Write-Host "    Instalando (silencioso, puede tardar 15-40 minutos segun la conexion)..."
        try {
            $proc = Start-Process -FilePath $bootstrapper -ArgumentList @(
                "--quiet", "--wait", "--norestart", "--nocache",
                "--installPath", "`"$vsInstallDir`"",
                "--add", $VCWorkloadId,
                "--includeRecommended"
            ) -Wait -PassThru

            # Codigos de salida documentados por el instalador de VS:
            # 0 = exito; 3010 = exito, requiere reinicio; 5004 = cancelado por el usuario
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                if (Test-VCToolsInstalled) {
                    Write-Ok "Visual Studio Build Tools instalado correctamente"
                    $script:results["VS Build Tools"] = "Instalado en $vsInstallDir"
                    if ($proc.ExitCode -eq 3010) {
                        Write-Host "    Hace falta reiniciar la maquina para terminar la instalacion." -ForegroundColor Yellow
                        $script:results["VS Build Tools"] += " (reinicio pendiente)"
                    }
                } else {
                    throw "El instalador termino sin error pero la carga C++ no se detecta"
                }
            } else {
                throw "El instalador devolvio el codigo $($proc.ExitCode)"
            }
        } catch {
            Write-Fail "Error instalando Visual Studio: $($_.Exception.Message)"
            Write-Host "    Plan B: ejecuta manualmente $bootstrapper y elige 'Desarrollo para el escritorio con C++'." -ForegroundColor Yellow
            $script:results["VS Build Tools"] = "FALLO - $($_.Exception.Message)"
        } finally {
            Remove-Item $bootstrapper -Force -ErrorAction SilentlyContinue
        }
    }
}

# --------------------------------------------------------------------------
# 4. Habilitar Windows desktop en Flutter + variables de entorno
# --------------------------------------------------------------------------

if ($flutterDir -and (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
    Write-Step "Habilitando el soporte de escritorio Windows en Flutter..."
    & "$flutterDir\bin\flutter.bat" config --enable-windows-desktop | Out-Null
    Write-Ok "Habilitado"
}

Write-Step "Configurando PATH persistente (usuario)..."
try {
    if ($flutterDir) {
        $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $addition = Join-Path $flutterDir "bin"
        if ($oldPath -notlike "*$addition*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$oldPath;$addition", "User")
        }
    }
    Write-Ok "PATH actualizado"
} catch {
    Write-Fail "No se pudo guardar el PATH: $($_.Exception.Message)"
    Write-Host "    Añade manualmente $flutterDir\bin al PATH." -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 5. flutter doctor
# --------------------------------------------------------------------------

if ($flutterDir -and (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
    Write-Step "Ejecutando 'flutter doctor'..."
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
        Write-Host ("  {0,-16}: {1}" -f $key, $value) -ForegroundColor Red
        $hasFailure = $true
    } else {
        Write-Host ("  {0,-16}: {1}" -f $key, $value) -ForegroundColor Green
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
