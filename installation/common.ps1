# Utilidades compartidas por install-android-toolchain.ps1 e
# install-windows-toolchain.ps1. Dot-sourced por ambos (". (Join-Path
# $PSScriptRoot '..\common.ps1')"), no se ejecuta por si solo.
#
# Casi toda esta logica es identica entre los dos instaladores (descargas,
# deteccion de comandos, resumen final...); vivia duplicada en cada script y
# ya causo una inconsistencia real (uno de los dos actualizaba $gitFound tras
# instalar Git con winget, el otro no). Un unico sitio para esto evita que
# ambos scripts puedan volver a divergir en silencio.

# Fuerza TLS 1.2 - en una maquina Windows poco actualizada (el publico
# objetivo de este instalador), el conjunto de protocolos por defecto de
# .NET Framework puede no incluirlo, y las descargas HTTPS fallarian con
# "No se pudo crear el canal seguro SSL/TLS".
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

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

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Ejecuta un comando nativo capturando stdout+stderr sin que reviente. En
# PowerShell 5.1, con $ErrorActionPreference = "Stop" (fijado en ambos
# scripts), CUALQUIER salida por stderr de un comando nativo capturada con
# 2>&1 - incluidos mensajes normales sin error real, como el propio
# "Cloning into '...'" de git o el banner de version de java, que ambos
# escriben a stderr por diseno, no porque algo vaya mal - se convierte en un
# NativeCommandError que aborta el script aunque el comando termine con
# exito. Verificado en vivo contra este interprete concreto (PowerShell 5.1):
# tanto `git clone ... 2>&1` como `java -version 2>&1` lanzan bajo EAP=Stop
# aunque el proceso termine con exit code 0. Esta funcion aisla el
# workaround (bajar el EAP solo alrededor de la llamada nativa) en un unico
# sitio bien probado en vez de repetirlo suelto en cada punto de llamada.
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

# [System.IO.Compression.ZipFile] vive en System.IO.Compression.FileSystem,
# que Windows PowerShell 5.1 NO carga por defecto - sin este Add-Type,
# ZipFile ni siquiera existe como tipo, la llamada lanza, y esta funcion
# devolveria $false SIEMPRE, marcando cualquier descarga valida como
# corrupta. Verificado en vivo: sin el Add-Type, referenciar el tipo lanza
# "No se encuentra el tipo [System.IO.Compression.ZipFile]".
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-ZipValid([string]$path) {
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
        $zip.Dispose()
        return $true
    } catch {
        return $false
    }
}

# Espacio libre en la unidad de $path. OJO: Resolve-Path sobre un mero
# calificador de unidad ("D:") NO resuelve a la raiz de esa unidad - resuelve
# contra el directorio "actual" recordado por Windows para esa unidad
# (el mismo mecanismo que hace que `cd D:` sin barra final, seguido de
# `D:` en otra consola, te lleve de vuelta a donde estabas). Verificado en
# vivo: con la sesion posicionada en D:\Programs\NexusKeys,
# `Resolve-Path "D:"` devolvio "D:\Programs\NexusKeys", no "D:\" - lo cual
# rompia el Get-PSDrive de abajo (y por tanto todo el script, sin try/catch
# alrededor) cada vez que la carpeta de instalacion estaba en la misma
# unidad que la terminal invocante. Evitamos el problema del todo: no hace
# falta Resolve-Path aqui, el nombre de la unidad ya viene en el propio
# calificador.
function Test-FreeSpace([string]$path, [int]$minGB) {
    $qualifier = Split-Path $path -Qualifier
    $driveLetter = $qualifier.TrimEnd(':')
    $freeBytes = (Get-PSDrive -Name $driveLetter).Free
    $freeGB = [math]::Round($freeBytes / 1GB, 1)
    return @{ FreeGB = $freeGB; Enough = ($freeGB -ge $minGB) }
}

# --- Resumen final -----------------------------------------------------

$script:results = [ordered]@{}
$script:hasFailure = $false

# $Failed decide si esto cuenta como fallo (color y exit code); el texto en
# si es solo para mostrar, ya no se interpreta con "-like FALLO*" en ningun
# sitio que decida el resultado.
function Add-Result([string]$Name, [string]$Message, [bool]$Failed = $false) {
    $script:results[$Name] = @{ Message = $Message; Failed = $Failed }
    if ($Failed) { $script:hasFailure = $true }
}

function Write-InstallSummary {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Magenta
    Write-Host " RESUMEN" -ForegroundColor Magenta
    Write-Host "================================================================" -ForegroundColor Magenta

    $maxLen = 10
    foreach ($key in $script:results.Keys) { if ($key.Length -gt $maxLen) { $maxLen = $key.Length } }

    foreach ($key in $script:results.Keys) {
        $entry = $script:results[$key]
        $color = if ($entry.Failed) { "Red" } else { "Green" }
        Write-Host ("  {0,-$maxLen}: {1}" -f $key, $entry.Message) -ForegroundColor $color
    }

    Write-Host ""
    if ($script:hasFailure) {
        Write-Host "Algunos componentes necesitan atencion manual (ver arriba y en el install-log.txt)." -ForegroundColor Yellow
        Write-Host "Puedes volver a ejecutar este script las veces que haga falta: lo que" -ForegroundColor Yellow
        Write-Host "ya este instalado correctamente se detecta y no se reinstala." -ForegroundColor Yellow
    } else {
        Write-Host "Todo listo." -ForegroundColor Green
    }
    Write-Host "Abre una terminal NUEVA para que las variables de entorno surtan efecto," -ForegroundColor Green
    Write-Host "y ejecuta 'flutter doctor' otra vez para confirmarlo." -ForegroundColor Green
}

# --- Git -----------------------------------------------------------------

# Devuelve $true si Git quedo disponible (ya estaba, o se instalo ahora).
function Install-GitIfMissing {
    param([switch]$Force)

    Write-Step "Comprobando Git..."
    if ((Test-CommandExists "git") -and -not $Force) {
        $v = (Invoke-Native -FilePath "git" -ArgumentList @("--version")).Output
        Write-Skip "Git ya esta instalado ($v)"
        Add-Result "Git" "Ya instalado ($v)"
        return $true
    }

    if (-not (Test-CommandExists "winget")) {
        Write-Fail "winget no esta disponible en esta maquina."
        Write-Host "    Instala Git manualmente desde https://git-scm.com/download/win y vuelve a ejecutar este script." -ForegroundColor Yellow
        Add-Result "Git" "FALLO - winget no disponible, instalar manualmente" $true
        return (Test-CommandExists "git")
    }

    Write-Host "    Instalando Git con winget..."
    try {
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements --silent
        $env:Path = "$env:Path;$env:ProgramFiles\Git\cmd;$env:LocalAppData\Programs\Git\cmd"
        if (Test-CommandExists "git") {
            Write-Ok "Git instalado correctamente"
            Add-Result "Git" "Instalado con winget"
            return $true
        }
        throw "git sigue sin encontrarse tras la instalacion"
    } catch {
        Write-Fail "No se pudo instalar Git con winget: $($_.Exception.Message)"
        Write-Host "    Plan B: descarga manual desde https://git-scm.com/download/win" -ForegroundColor Yellow
        Add-Result "Git" "FALLO - instalar manualmente desde git-scm.com" $true
        return $false
    }
}

# --- Flutter ---------------------------------------------------------------

# Devuelve la carpeta raiz del SDK de Flutter (existente o recien clonado), o
# $null si no se pudo conseguir de ninguna forma.
function Install-FlutterIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [bool]$GitAvailable,
        [switch]$Force
    )

    Write-Step "Comprobando Flutter..."

    if ((Test-CommandExists "flutter") -and -not $Force) {
        $flutterCmd = (Get-Command flutter).Source
        $flutterDir = Split-Path (Split-Path $flutterCmd)
        $v = ((Invoke-Native -FilePath "flutter" -ArgumentList @("--version")).Output -split "`n" | Select-Object -First 1)
        Write-Skip "Flutter ya esta instalado en $flutterDir ($v)"
        Add-Result "Flutter" "Ya instalado en $flutterDir"
        return $flutterDir
    }

    $flutterDir = Join-Path $InstallDir "flutter"
    if ((Test-Path (Join-Path $flutterDir "bin\flutter.bat")) -and -not $Force) {
        Write-Skip "Ya existe una copia de Flutter en $flutterDir"
        Add-Result "Flutter" "Ya instalado en $flutterDir"
        return $flutterDir
    }

    if (-not $GitAvailable) {
        Write-Fail "Git no esta disponible, no se puede clonar Flutter."
        Write-Host "    Plan B: descarga el SDK como zip desde https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
        Add-Result "Flutter" "FALLO - instalar Git primero, o descargar Flutter como zip" $true
        return $null
    }

    Write-Host "    Clonando el SDK de Flutter (canal stable)..."
    try {
        if (Test-Path $flutterDir) { Remove-Item $flutterDir -Recurse -Force }
        $cloneResult = Invoke-Native -FilePath "git" -ArgumentList @("clone", "--depth", "1", "https://github.com/flutter/flutter.git", "-b", "stable", $flutterDir)
        if (-not (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
            throw "flutter.bat no aparecio tras clonar (git salio con codigo $($cloneResult.ExitCode)): $($cloneResult.Output)"
        }
        Write-Ok "Flutter clonado en $flutterDir"
        Add-Result "Flutter" "Instalado en $flutterDir"
        return $flutterDir
    } catch {
        Write-Fail "Error clonando Flutter: $($_.Exception.Message)"
        Write-Host "    Plan B: descarga el SDK como zip desde https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
        Add-Result "Flutter" "FALLO - $($_.Exception.Message)" $true
        return $null
    }
}

# --- PATH persistente --------------------------------------------------

# Añade $paths al PATH de usuario (persistente) y a la sesion actual, sin
# duplicados. Usa comprobacion de subcadena literal, no -like/-notlike: los
# propios paths pueden contener corchetes u otros caracteres que -like
# interpretaria como comodines (p. ej. "D:\Dev [x64]\bin"), haciendo que la
# comprobacion de "ya esta" de falsos negativos y el PATH crezca con
# entradas duplicadas en cada re-ejecucion.
function Add-ToPersistentPath {
    param([string[]]$Paths)

    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $changed = $false
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        if (-not $oldPath.Contains($p)) {
            $oldPath = "$oldPath;$p"
            $changed = $true
        }
        if (-not $env:Path.Contains($p)) {
            $env:Path = "$env:Path;$p"
        }
    }
    if ($changed) {
        [System.Environment]::SetEnvironmentVariable("Path", $oldPath, "User")
    }
}
