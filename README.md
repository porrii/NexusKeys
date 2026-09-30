# NexusKeys

Un gestor de contraseñas privado y totalmente sin conexión para Android y
Windows. Sin cuenta, sin servidor, sin telemetría: todo se deriva y se guarda
en local, cifrado en reposo.

[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-blue.svg)](LICENSE)
[![Plataforma](https://img.shields.io/badge/plataforma-Android%20%7C%20Windows-informational)](#)

## Descargar

Coge la última versión desde la página de [Releases](https://github.com/porrii/NexusKeys/releases):

- **Android** — `NexusKeys-<versión>.apk`. Instalación manual (sideload);
  tendrás que permitir instalar desde tu navegador o gestor de archivos, ya
  que no está en Play Store.
- **Windows (instalador)** — `NexusKeys-Setup-<versión>.exe`. Instala solo
  para tu usuario o para toda la máquina, eliges la ubicación, y deja un
  desinstalador normal. La base de datos de la bóveda se guarda en
  `%APPDATA%\NexusKeys\` independientemente de dónde se instale la app.
- **Windows (portable)** — `NexusKeys-<versión>-portable-windows-x64.zip`.
  Descomprime donde quieras y ejecuta `nexuskeys.exe`; no se instala nada.

Consulta [CHANGELOG.md](CHANGELOG.md) para ver qué cambió en cada versión.

## Características

- **Desbloqueo con contraseña maestra**, con desbloqueo biométrico opcional
  (huella / cara) respaldado por el Keystore del sistema para un acceso más
  rápido.
- **CRUD completo de la bóveda** para inicios de sesión, tarjetas bancarias,
  notas seguras, identidades y credenciales Wi-Fi, cada uno con sus campos.
- **Generador de contraseñas** integrado, con longitud y conjuntos de
  caracteres configurables.
- **Etiquetas y favoritos** para organizar y filtrar la bóveda rápidamente,
  más una búsqueda en vivo por título, usuario y etiquetas.
- **Papelera con borrado suave**: los elementos eliminados se pueden
  restaurar antes de que desaparezcan del todo.
- **Exportación / importación cifrada** a un único archivo de copia de
  seguridad.
- **Bloqueo automático**: bloquea al salir de primer plano, o tras un tiempo
  de inactividad configurable, comprobado al volver.
- **Interfaz adaptable**: diseño compacto en móvil y un diseño persistente de
  barra lateral + lista + detalle en tablets y Windows.
- **Temas**: claro, oscuro, negro OLED o seguir el del sistema.

## Arquitectura de seguridad

NexusKeys se apoya en tres primitivas bien establecidas, elegidas
específicamente para un gestor de contraseñas local y no para una app de
propósito general:

| Capa | Primitiva | Propósito |
|---|---|---|
| Derivación de clave | **Argon2id** (64 MiB, 3 iteraciones, 4 carriles) | Convierte la contraseña maestra en la clave de cifrado de la bóveda. Los parámetros de coste se guardan junto a la bóveda, así que se pueden subir más adelante sin romper las bóvedas existentes. |
| Datos en reposo | **SQLCipher** (AES-256) | Toda la base de datos de la bóveda es un archivo SQLite cifrado: nunca se escribe nada en disco en texto plano. |
| Secretos a nivel de campo | **AES-256-GCM** | Cifrado autenticado de las copias de seguridad exportadas y del material protegido por el Keystore. |
| Desbloqueo biométrico | **Android Keystore + `local_auth`** | La clave de la bóveda vive en una entrada del Keystore que exige autenticación biométrica para descifrarse: una barrera a nivel de hardware, no una comprobación de la app. Además, la app exige un `BiometricPrompt` nuevo en *cada* intento de desbloqueo (la capa del Keystore por sí sola solo pregunta una vez por proceso y luego reutiliza el cifrado ya desbloqueado). No disponible en Windows. |

Ningún secreto en texto plano —contraseña maestra, clave derivada o contenido
de la bóveda— se escribe nunca en disco ni se envía a ningún sitio. NexusKeys
no necesita permiso de red más allá de abrir una URL que el usuario pulse
explícitamente, y no incluye ninguna dependencia de analítica, informes de
fallos ni telemetría.

Este proyecto no ha pasado una auditoría de seguridad independiente de
terceros. Trátalo como cualquier otro software de código abierto sin auditar.

## Tecnologías

- [Flutter](https://flutter.dev) / Dart, organizado como Clean Architecture
  (`domain` / `data` / `presentation`) por cada feature.
- [`get_it`](https://pub.dev/packages/get_it) para inyección de dependencias,
  [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) para el
  estado.
- [`sqlite3`](https://pub.dev/packages/sqlite3) con su build hook de SQLCipher
  para la base de datos local cifrada.
- [`cryptography`](https://pub.dev/packages/cryptography) /
  [`cryptography_flutter`](https://pub.dev/packages/cryptography_flutter) para
  Argon2id y AES-256-GCM.
- [`local_auth`](https://pub.dev/packages/local_auth) y
  [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  para el desbloqueo biométrico respaldado por el Keystore.

## Primeros pasos

```bash
flutter pub get
flutter run
```

La build cifrada de SQLite se descarga automáticamente mediante los build
hooks de Dart (ver la sección `hooks:` en `pubspec.yaml`): no hace falta
ninguna configuración nativa aparte.

Para compilar sin tener que hacerlo todo a mano, usa
[`compilar.bat`](compilar.bat) (Windows) o [`compilar.sh`](compilar.sh)
(Linux, solo Android — Windows no se puede compilar de forma cruzada) desde
la raíz del repositorio:

```
compilar.bat --android
compilar.bat --windows --instalador

./compilar.sh --android
```

Antes de compilar comprueba que la máquina tiene lo necesario para esa
plataforma (JDK 17 + Android SDK para `--android`, Visual Studio Build Tools
para `--windows`) y, si falta algo, avisa de todo lo que falta a la vez —con
una URL para conseguir cada cosa— en vez de pararse en el primer hueco. Si
todo está en orden, compila con la salida de `flutter`/`iscc` en directo y
deja el resultado en `dist/android/` o `dist/windows/`. Ejecuta `--ayuda`
para ver el resto de opciones (`--limpio`, `--debug`, `--instalador`...).

### Tests

```bash
flutter test
```

### Generar los artefactos de release

```
compilar.bat --android
compilar.bat --windows --instalador
```

Deja el APK, el portable (zip) y el instalador (si se pidió) ya nombrados con
la versión en `dist\android\` / `dist\windows\`. Antes de generar una
release, sube la versión tanto en `pubspec.yaml` como en
`windows/installer/nexuskeys.iss`.

Si prefieres compilar a mano en vez de usar el script:

```bash
# Android
flutter build apk --release          # -> build/app/outputs/flutter-apk/app-release.apk

# Windows (compila la app y luego empaqueta el instalador)
flutter build windows --release      # -> build/windows/x64/runner/Release/
iscc windows/installer/nexuskeys.iss  # -> windows/installer/Output/NexusKeys-Setup-<versión>.exe
```

El zip portable de Windows es simplemente el contenido de
`build/windows/x64/runner/Release/` comprimido tal cual.

## Estructura del proyecto

```
lib/
  core/            # DI, temas, base de datos y servicios de cripto comunes
  features/
    auth/          # Contraseña maestra, desbloqueo biométrico, ciclo de la bóveda
    vault/         # Elementos de la bóveda: CRUD, búsqueda, etiquetas, papelera
    generator/     # Generador de contraseñas
    backup/        # Exportación / importación cifrada
    settings/      # Ajustes, gestión de etiquetas, acerca de
```

Cada feature sigue la misma división interna: `domain` (entidades, interfaces
de repositorio), `data` (implementaciones de repositorio, fuentes de datos
locales) y `presentation` (páginas, widgets).

## Licencia

MIT — ver [LICENSE](LICENSE).
