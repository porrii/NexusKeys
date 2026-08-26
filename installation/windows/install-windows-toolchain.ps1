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
. (Join-Path $PSScriptRoot "..\common.ps1")

$script:MinFreeGB = 15
$VCWorkloadId = "Microsoft.VisualStudio.Workload.VCTools"

function Find-VsWhere {
    # OJO: "$env:ProgramFiles(x86)" NO interpola lo que parece - PowerShell
    # para de leer el nombre de variable en el primer caracter invalido
    # ('('), asi que esto se convertia en el valor de $env:ProgramFiles
    # seguido del texto literal "(x86)" sin espacio ("C:\Program
    # Files(x86)\..."), una ruta que no existe. Hace falta ${env:...} para
    # meter un caracter especial en el nombre de la variable de entorno.
    # Verificado en vivo: la version sin llaves nunca encuentra vswhere.exe
    # en ninguna maquina Windows de 64 bits (vswhere siempre vive bajo
    # Program Files (x86), incluso en instalaciones de VS de 64 bits), lo
    # que hacia que la deteccion de "ya esta instalado" no funcionara nunca
    # - cada ejecucion volvia a descargar e instalar Visual Studio entero, y
    # peor: una instalacion recien hecha con exito tambien se reportaba
    # como fallo, porque la comprobacion posterior tampoco lo encontraba.
    $paths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

function Test-VCToolsInstalled {
    $vswhere = Find-VsWhere
    if (-not $vswhere) { return $false }
    $r = Invoke-Native -FilePath $vswhere -ArgumentList @("-products", "*", "-requires", $VCWorkloadId, "-property", "installationPath")
    # Comprobar solo que la salida no este vacia no basta: si vswhere falla
    # y escribe un mensaje de error (en vez de una ruta) por stdout/stderr,
    # esa salida tambien es "no vacia" y esto devolveria $true por error.
    return ($r.Success -and [bool]($r.Output.Trim()))
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

$gitFound = Install-GitIfMissing -Force:$Force

# --------------------------------------------------------------------------
# 2. Flutter SDK
# --------------------------------------------------------------------------

$flutterDir = Install-FlutterIfMissing -InstallDir $InstallDir -GitAvailable $gitFound -Force:$Force
if ($flutterDir) { $env:Path = "$env:Path;$flutterDir\bin" }

# --------------------------------------------------------------------------
# 3. Visual Studio Build Tools (carga C++ de escritorio)
# --------------------------------------------------------------------------

Write-Step "Comprobando Visual Studio (carga C++ de escritorio)..."
if ((Test-VCToolsInstalled) -and -not $Force) {
    Write-Skip "Ya hay una instalacion de Visual Studio con la carga C++ de escritorio"
    Add-Result "VS Build Tools" "Ya instalado"
} else {
    Write-Host "    Descargando el instalador de Visual Studio Build Tools 2022..."
    $vsInstallDir = Join-Path $InstallDir "VSBuildTools"
    $bootstrapper = Join-Path $InstallDir "vs_buildtools.exe"
    $downloaded = Invoke-DownloadWithRetry -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $bootstrapper

    if (-not $downloaded) {
        Write-Fail "No se pudo descargar el instalador de Visual Studio."
        Write-Host "    Plan B: descargalo a mano desde https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor Yellow
        Write-Host "    y marca la carga 'Desarrollo para el escritorio con C++'." -ForegroundColor Yellow
        Add-Result "VS Build Tools" "FALLO - descargar manualmente" $true
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
                    $msg = "Instalado en $vsInstallDir"
                    if ($proc.ExitCode -eq 3010) {
                        Write-Host "    Hace falta reiniciar la maquina para terminar la instalacion." -ForegroundColor Yellow
                        $msg += " (reinicio pendiente)"
                    }
                    Add-Result "VS Build Tools" $msg
                } else {
                    throw "El instalador termino sin error pero la carga C++ no se detecta"
                }
            } else {
                throw "El instalador devolvio el codigo $($proc.ExitCode)"
            }
        } catch {
            Write-Fail "Error instalando Visual Studio: $($_.Exception.Message)"
            Write-Host "    Plan B: ejecuta manualmente $bootstrapper y elige 'Desarrollo para el escritorio con C++'." -ForegroundColor Yellow
            Add-Result "VS Build Tools" "FALLO - $($_.Exception.Message)" $true
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
    if ($flutterDir) { Add-ToPersistentPath -Paths @((Join-Path $flutterDir "bin")) }
    Write-Ok "PATH actualizado"
} catch {
    Write-Fail "No se pudo guardar el PATH: $($_.Exception.Message)"
    Write-Host "    Anade manualmente $flutterDir\bin al PATH." -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 5. flutter doctor
# --------------------------------------------------------------------------

if ($flutterDir -and (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
    Write-Step "Ejecutando 'flutter doctor'..."
    & "$flutterDir\bin\flutter.bat" doctor
}

Write-InstallSummary
Write-Host "Registro completo guardado en: $logFile"

Stop-Transcript | Out-Null

if ($script:hasFailure) { exit 1 } else { exit 0 }
