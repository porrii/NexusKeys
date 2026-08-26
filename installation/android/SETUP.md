# Entorno de compilación para Android

Todo lo necesario para compilar NexusKeys para Android desde cero en una máquina nueva.

## Opción rápida: script automático

Ejecuta [`install-android-toolchain.bat`](install-android-toolchain.bat) (doble clic, o desde una
terminal). Te pedirá una carpeta donde instalar lo que falte y se encargará del resto.

El script **detecta lo que ya tienes instalado** (por `JAVA_HOME`/`ANDROID_HOME` o el `PATH`) y no
lo reinstala; si algún paso falla (sin conexión, descarga corrupta, permisos...) continúa con el
resto en vez de abortar, y al final muestra un resumen de qué quedó listo y qué necesita revisión
manual. Puedes volver a ejecutarlo las veces que haga falta — es seguro, no repite lo que ya
funcionó. Cada ejecución deja un `install-log.txt` con el detalle completo en la carpeta que
elijas.

Al terminar, **abre una terminal nueva** (para que las variables de entorno surtan efecto) y
ejecuta:

```
flutter doctor
```

Si `flutter doctor` señala algo pendiente (por ejemplo, licencias del SDK sin aceptar), sigue sus
propias instrucciones — suele bastar con `flutter doctor --android-licenses`.

El script instala:

- **Temurin JDK 17** — la versión de Java que usan Gradle/Kotlin en este proyecto.
- **Android SDK command-line tools** + `platform-tools` + `build-tools`, con las licencias
  aceptadas.
- **Flutter SDK** (canal `stable`), clonado con git.
- Variables de entorno persistentes: `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, y las
  añade al `PATH` del usuario.

No instala una plataforma (`platforms;android-XX`) ni el NDK fijos a una versión concreta a
propósito — Gradle/AGP los descarga automáticamente la primera vez que hacen falta (con las
licencias ya aceptadas, ese paso es transparente). Así el script no queda desactualizado cada vez
que Flutter cambia su versión de SDK/NDK recomendada.

## Qué necesita este proyecto exactamente

- **Java 17** — fijado en `android/app/build.gradle.kts` (`sourceCompatibility`,
  `targetCompatibility`, `kotlin { jvmTarget }`). Otras versiones de Java pueden dar errores de
  compilación de Kotlin difíciles de diagnosticar.
- **Android SDK** con `platform-tools` (para `adb`) y las licencias aceptadas. La plataforma
  (`compileSdk`/`targetSdk`) y el NDK los decide Flutter dinámicamente
  (`flutter.compileSdkVersion` / `flutter.ndkVersion` en `build.gradle.kts`) — no hace falta
  fijarlos a mano.
- **Flutter SDK**, canal `stable`. Cualquier versión reciente sirve; el proyecto no depende de una
  revisión concreta.
- **Git** — lo necesita el propio Flutter SDK y `flutter pub get`.

## Problema conocido: paquetes de API 37 con versión menor

Si el SDK de Android instalado solo trae paquetes de la API 37 con sufijo de versión menor (p. ej.
`android-37.0` en vez de `android-37`), Android Gradle Plugin puede fallar al parsear su XML con
un error como:

```
This version only understands SDK XML versions up to 3 but an SDK XML file of version 4 was
encountered.
```

Este proyecto ya trae un workaround para esto en `android/build.gradle.kts` (fija `compileSdk` a
36 para los subproyectos de plugins afectados). Si el propio módulo `:app` diera el mismo error,
instala explícitamente la plataforma `platforms;android-36` con `sdkmanager` y vuelve a intentar.

## Instalación manual (si no quieres usar el script)

1. Instala [Temurin JDK 17](https://adoptium.net/temurin/releases/?version=17) y define
   `JAVA_HOME` apuntando a su carpeta de instalación.
2. Descarga las [Android command-line tools](https://developer.android.com/studio#command-tools),
   colócalas en `<sdk>\cmdline-tools\latest\` (la carpeta debe llamarse `latest`, no
   `cmdline-tools`), y define `ANDROID_HOME`/`ANDROID_SDK_ROOT` apuntando a `<sdk>`.
3. Con `sdkmanager` (dentro de `cmdline-tools\latest\bin`), instala `platform-tools` y acepta las
   licencias: `sdkmanager --licenses`.
4. Instala [Flutter](https://docs.flutter.dev/get-started/install/windows) (canal `stable`) y
   añade su carpeta `bin` al `PATH`.
5. Añade `%ANDROID_HOME%\platform-tools` y `%ANDROID_HOME%\cmdline-tools\latest\bin` al `PATH`.
6. Ejecuta `flutter doctor` y sigue lo que te indique.

## Compilar

Desde la raíz del repositorio:

```
flutter build apk --release
```

El APK firmado (si tienes configurado `android/key.properties`, ver el README principal) se genera
en `build\app\outputs\flutter-apk\app-release.apk`.
