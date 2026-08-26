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

# --- JDK 17 (Temurin) ------------------------------------------------------
Write-Step "Descargando Temurin JDK 17..."
$jdkZip = Join-Path $InstallDir "temurin17.zip"
$jdkUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZip -UseBasicParsing

Write-Step "Extrayendo JDK..."
Expand-Archive -Path $jdkZip -DestinationPath $InstallDir -Force
Remove-Item $jdkZip

$jdkDir = Get-ChildItem -Path $InstallDir -Directory | Where-Object { $_.Name -like "jdk-17*" } | Select-Object -First 1
$javaHome = $jdkDir.FullName
Write-Host "JAVA_HOME = $javaHome"

# --- Android SDK command-line tools ---------------------------------------
Write-Step "Descargando Android command-line tools..."
$sdkRoot = Join-Path $InstallDir "Android\Sdk"
$cmdlineZip = Join-Path $InstallDir "cmdline-tools.zip"
# Página de referencia: https://developer.android.com/studio#command-tools
$cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
Invoke-WebRequest -Uri $cmdlineUrl -OutFile $cmdlineZip -UseBasicParsing

$cmdlineToolsRoot = Join-Path $sdkRoot "cmdline-tools"
New-Item -ItemType Directory -Force -Path $cmdlineToolsRoot | Out-Null
Expand-Archive -Path $cmdlineZip -DestinationPath $cmdlineToolsRoot -Force
Remove-Item $cmdlineZip

# El zip extrae a cmdline-tools\cmdline-tools; sdkmanager espera cmdline-tools\latest
$extracted = Join-Path $cmdlineToolsRoot "cmdline-tools"
$latest = Join-Path $cmdlineToolsRoot "latest"
if (Test-Path $extracted) {
    if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }
    Rename-Item $extracted "latest"
}

$sdkManager = Join-Path $latest "bin\sdkmanager.bat"
$env:JAVA_HOME = $javaHome

Write-Step "Aceptando licencias del SDK..."
$licenses = (("y`n") * 30)
$licenses | & $sdkManager "--sdk_root=$sdkRoot" --licenses | Out-Null

Write-Step "Instalando platform-tools y build-tools..."
& $sdkManager "--sdk_root=$sdkRoot" "platform-tools" "build-tools;36.0.0"

Write-Host ""
Write-Host "Nota: la plataforma (compileSdk/targetSdk) y el NDK los instala Gradle" -ForegroundColor Yellow
Write-Host "automáticamente la primera vez que hacen falta (las licencias ya están" -ForegroundColor Yellow
Write-Host "aceptadas), así que no se fijan aquí a una versión concreta." -ForegroundColor Yellow

# --- Flutter SDK -----------------------------------------------------------
Write-Step "Clonando el SDK de Flutter (canal stable)..."
$flutterDir = Join-Path $InstallDir "flutter"
if (Test-Path $flutterDir) {
    Write-Host "Ya existe $flutterDir, saltando el clonado."
} else {
    git clone https://github.com/flutter/flutter.git -b stable $flutterDir
}

# --- Variables de entorno persistentes (usuario) ---------------------------
Write-Step "Configurando variables de entorno persistentes..."
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")

$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$additions = @(
    (Join-Path $flutterDir "bin"),
    (Join-Path $javaHome "bin"),
    (Join-Path $sdkRoot "platform-tools"),
    $latest + "\bin"
)
foreach ($a in $additions) {
    if ($oldPath -notlike "*$a*") { $oldPath = "$oldPath;$a" }
}
[System.Environment]::SetEnvironmentVariable("Path", $oldPath, "User")

Write-Step "Ejecutando 'flutter doctor' (primera vez, puede tardar)..."
$env:Path = "$env:Path;$($additions -join ';')"
& "$flutterDir\bin\flutter.bat" doctor

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host " Listo. Abre una terminal NUEVA para que las variables de" -ForegroundColor Green
Write-Host " entorno surtan efecto, y ejecuta 'flutter doctor' otra vez" -ForegroundColor Green
Write-Host " para confirmar que todo está en orden." -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
