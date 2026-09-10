# Entorno de compilación para Windows

Todo lo necesario para compilar NexusKeys como app de escritorio Windows desde cero en una
máquina nueva.

## Opción rápida: script automático

Ejecuta [`install-windows-toolchain.bat`](install-windows-toolchain.bat) (doble clic, o desde una
terminal). Se relanza solo pidiendo permisos de administrador si hace falta (Visual Studio los
necesita), te pedirá una carpeta donde instalar lo que falte, y se encargará del resto. La
instalación de Visual Studio Build Tools es la parte más larga (varios GB, puede tardar bastante
según la conexión).

El script **detecta lo que ya tienes instalado** (Git, Flutter, y si ya existe una instalación de
Visual Studio con la carga C++ de escritorio, vía `vswhere`) y no lo reinstala; si algún paso falla
continúa con el resto en vez de abortar, y al final muestra un resumen de qué quedó listo y qué
necesita revisión manual. Puedes volver a ejecutarlo las veces que haga falta. Cada ejecución deja
un `install-log.txt` con el detalle completo en la carpeta que elijas.

Al terminar, **abre una terminal nueva** y ejecuta:

```
flutter doctor
```

El script instala:

- **Flutter SDK** (canal `stable`), clonado con git.
- **Visual Studio 2022 Build Tools** con la carga de trabajo "Desarrollo para el escritorio con
  C++" — es lo que Flutter necesita para compilar la parte nativa de Windows (no hace falta la
  IDE completa de Visual Studio, solo estas herramientas de compilación).
- Habilita el soporte de escritorio Windows en Flutter (`flutter config
  --enable-windows-desktop`).

## Qué necesita este proyecto exactamente

- **Flutter SDK**, canal `stable`, con el soporte de Windows desktop habilitado.
- **Visual Studio Build Tools 2022** (o la IDE completa, si ya la tienes) con la carga de trabajo
  **"Desarrollo para el escritorio con C++"** (`Microsoft.VisualStudio.Workload.VCTools`), que
  incluye el compilador de MSVC, CMake y el SDK de Windows — Flutter los usa para compilar el
  "runner" nativo de la app de escritorio.
- **Git**.

## Instalación manual (si no quieres usar el script)

1. Instala [Flutter](https://docs.flutter.dev/get-started/install/windows) (canal `stable`) y
   añade su carpeta `bin` al `PATH`.
2. Instala [Visual Studio Build Tools
   2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) con la
   carga de trabajo **"Desarrollo para el escritorio con C++"** marcada.
3. Ejecuta `flutter config --enable-windows-desktop`.
4. Ejecuta `flutter doctor` y confirma que "Visual Studio" aparece con un check verde.

## Compilar

Desde la raíz del repositorio:

```
flutter build windows --release
```

El ejecutable y sus DLLs se generan juntos dentro de `build\windows\x64\runner\Release\` — hay que
distribuir toda esa carpeta, no solo el `.exe`. Esa carpeta comprimida en un `.zip` es la
**versión portable** que se publica en Releases.

## Empaquetar el instalador

Para generar el `.exe` de instalación (además de la portable) hace falta
[Inno Setup 6](https://jrsoftware.org/isinfo.php). Con la app ya compilada (`flutter build windows
--release`), desde la raíz del repositorio:

```
iscc windows\installer\nexuskeys.iss
```

El instalador queda en `windows\installer\Output\NexusKeys-Setup-<versión>.exe`. Antes de una
release, sube el número de versión tanto en `pubspec.yaml` como en la línea `#define MyAppVersion`
de `windows\installer\nexuskeys.iss` — tienen que coincidir. El propio `.iss` tiene un comentario
de cabecera con el resto de detalles.

## Problema conocido: error de deprecación de coroutines en MSVC

Con ciertas versiones de Visual Studio/MSVC, la compilación puede fallar por un error de
deprecación relacionado con `<experimental/coroutine>` (usado internamente por el motor de Flutter
o alguna dependencia nativa). `windows/CMakeLists.txt` ya trae el fix aplicado:

```cmake
add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
```

Si compilas desde cero y te encuentras este error, comprueba que esa línea siga presente en
`windows/CMakeLists.txt` (justo después de `add_definitions(-DUNICODE -D_UNICODE)`).
