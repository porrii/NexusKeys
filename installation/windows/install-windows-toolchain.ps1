param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Test-CommandExists($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$InstallDir = (Resolve-Path $InstallDir).Path

# --- Git -----------------------------------------------------------------
if (-not (Test-CommandExists "git")) {
    Write-Step "Git no encontrado. Instalando con winget..."
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    $env:Path = "$env:Path;$env:ProgramFiles\Git\cmd"
} else {
    Write-Step "Git ya está instalado, saltando."
}

# --- Flutter SDK -----------------------------------------------------------
Write-Step "Clonando el SDK de Flutter (canal stable)..."
$flutterDir = Join-Path $InstallDir "flutter"
if (Test-Path $flutterDir) {
    Write-Host "Ya existe $flutterDir, saltando el clonado."
} else {
    git clone https://github.com/flutter/flutter.git -b stable $flutterDir
}

$env:Path = "$env:Path;$flutterDir\bin"

# --- Visual Studio Build Tools 2022 (carga de trabajo C++ escritorio) ------
Write-Step "Descargando el instalador de Visual Studio Build Tools 2022..."
$vsInstallDir = Join-Path $InstallDir "VSBuildTools"
$bootstrapper = Join-Path $InstallDir "vs_buildtools.exe"
Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $bootstrapper -UseBasicParsing

Write-Step "Instalando Visual Studio Build Tools (carga C++ de escritorio)... esto puede tardar bastante."
$proc = Start-Process -FilePath $bootstrapper -ArgumentList @(
    "--quiet", "--wait", "--norestart", "--nocache",
    "--installPath", "`"$vsInstallDir`"",
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--includeRecommended"
) -Wait -PassThru

if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    Write-Host "El instalador de Visual Studio devolvió el código $($proc.ExitCode)." -ForegroundColor Yellow
    Write-Host "Puede que ya hubiera una instalación previa, o que falte reiniciar. Revisa 'flutter doctor' al final." -ForegroundColor Yellow
}
Remove-Item $bootstrapper -ErrorAction SilentlyContinue

# --- Habilitar Windows desktop en Flutter ----------------------------------
Write-Step "Habilitando el soporte de escritorio Windows en Flutter..."
& "$flutterDir\bin\flutter.bat" config --enable-windows-desktop

# --- Variables de entorno persistentes (usuario) ---------------------------
Write-Step "Configurando PATH persistente..."
$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$addition = Join-Path $flutterDir "bin"
if ($oldPath -notlike "*$addition*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$oldPath;$addition", "User")
}

Write-Step "Ejecutando 'flutter doctor'..."
& "$flutterDir\bin\flutter.bat" doctor

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host " Listo. Abre una terminal NUEVA para que las variables de" -ForegroundColor Green
Write-Host " entorno surtan efecto. Si 'flutter doctor' no marca Visual" -ForegroundColor Green
Write-Host " Studio en verde, puede hacer falta reiniciar la maquina." -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
