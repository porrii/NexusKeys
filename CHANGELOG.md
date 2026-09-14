# Registro de cambios

Todos los cambios relevantes de NexusKeys se documentan aquí. El formato se
basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/), y el
proyecto sigue el [Versionado Semántico](https://semver.org/lang/es/).

## [1.2.2] - 2026-09-14

### Corregido

- **Desbloquear la bóveda podía quedarse colgado para siempre**, mostrando el
  spinner del botón "Desbloquear" sin llegar nunca a un resultado ni a un
  error — reproducido en Windows. La causa: en escritorio, la derivación de
  la clave (Argon2id) reparte el cálculo entre varios procesos auxiliares
  internos, y si uno no respondía a tiempo, la excepción resultante no se
  capturaba en ningún punto de la cadena de desbloqueo. Ahora la derivación
  evita ese mecanismo por completo, y cualquier fallo inesperado durante el
  desbloqueo (este u otro futuro) se convierte en un mensaje de error visible
  en vez de dejar la app colgada.

## [1.2.1] - 2026-09-10

Primera release de Windows, más correcciones encontradas al probar las builds
reales en Android y Windows.

### Añadido

- **Windows de escritorio ya es un objetivo real y distribuible.** Dos formas
  de instalar:
  - `NexusKeys-Setup-1.2.1.exe` — un instalador de verdad (Inno Setup):
    instala solo para tu usuario o para toda la máquina, te deja elegir la
    ubicación, añade accesos en el Menú Inicio (y opcionalmente en el
    Escritorio) y registra un desinstalador. El desinstalador ofrece
    —desactivado por defecto— borrar también los datos de la bóveda.
  - `NexusKeys-1.2.1-portable-windows-x64.zip` — descomprime donde quieras y
    ejecuta `nexuskeys.exe`, sin instalación.
- Política de privacidad ([PRIVACY.md](PRIVACY.md)).

### Cambiado

- **Las subpáginas de Ajustes se quedan dentro del layout en pantallas
  anchas.** En tablets y Windows, abrir Idioma, Tema, Bloqueo automático,
  Cambiar contraseña maestra o Importar / Exportar ahora intercambia el
  contenido en el sitio, con la barra lateral de navegación aún visible, en
  vez de abrir una pantalla completa nueva — igual que ya hacían Papelera,
  Recientes y Etiquetas.
- **Etiquetas y Papelera ya no aparecen dentro de Ajustes en los layouts
  anchos**, donde ya son destinos propios de la barra lateral.
- **La Autenticación biométrica se oculta en los Ajustes en Windows**, que no
  tiene hardware biométrico que esta app pueda usar.
- La pantalla de bloqueo solo muestra el botón de huella y "Otras opciones"
  cuando el desbloqueo biométrico está realmente activado — se acabaron los
  controles atenuados que no hacían nada.
- Los datos de la app en Windows (`vault.db`) se guardan directamente en
  `%APPDATA%\NexusKeys\` en vez de anidados bajo el nombre del autor.
- La pantalla de Idioma ya no estira su única opción para llenar el panel; se
  distribuye como el selector de Tema, tanto con una opción como con varias.

### Corregido

- **El bloqueo automático ("Bloqueo automático") ahora funciona de verdad.**
  Era un ajuste que se guardaba pero que nada aplicaba — la bóveda nunca se
  bloqueaba sola en ninguna plataforma. Ahora se bloquea al volver a la app
  después del tiempo de inactividad configurado, y "Bloquear al cerrar"
  bloquea en el momento en que la app deja el primer plano. (El tiempo de
  inactividad *dentro* de la app todavía no se cuenta — un seguimiento
  deliberado.)
- **El desbloqueo biométrico ahora pregunta cada vez.** Tras la primera
  huella correcta de una sesión, volver a pulsar el icono de huella en la
  pantalla de bloqueo te dejaba entrar sin volver a escanear, porque el
  almacenamiento seguro mantiene su cifrado desbloqueado en memoria durante
  el resto del proceso. Ahora cada intento de desbloqueo exige una
  comprobación biométrica nueva.
- La app siempre muestra primero su propia pantalla de bloqueo al arrancar;
  ya no aparece un prompt biométrico del sistema antes de que se vea la
  pantalla de bloqueo.
- Windows: "Aplicaciones y características" mostraba la app como "NexusKeys
  versión 1.2.1" en la columna Nombre; ahora muestra solo "NexusKeys" (la
  versión tiene su propia columna).
- Windows: corregido un error de deprecación de MSVC con
  `<experimental/coroutine>` que rompía la build de release en algunas
  versiones de Visual Studio.

## [1.2.0] - 2026-08-26

Primera release firmada para producción. **Solo Android** — la plataforma
Windows aún no estaba lista en este tag.

### Añadido

- Las builds de release se firman con un keystore de subida dedicado en vez
  de con la clave de depuración.
- Icono de la app, README y licencia MIT.

### Cambiado

- Limpieza del repositorio: los archivos internos de herramientas
  (`.metadata`, cachés de build) ya no se versionan.

## [1.1.1] - 2026-08-25

Prelanzamiento. Gestor de bóveda base: autenticación con contraseña maestra
(Argon2id) sobre una base de datos cifrada con SQLCipher, CRUD completo para
inicios de sesión / tarjetas / notas / identidades / Wi-Fi, desbloqueo
biométrico opcional respaldado por el Keystore, generador de contraseñas,
etiquetas, favoritos, búsqueda en vivo y papelera con borrado suave, más
exportación / importación cifrada. Layout adaptable —compacto en móvil, barra
lateral + lista + detalle en tablets y Windows— con navegación inferior
persistente en móvil.

[1.2.2]: https://github.com/porrii/NexusKeys/releases/tag/v1.2.2
[1.2.1]: https://github.com/porrii/NexusKeys/releases/tag/v1.2.1
[1.2.0]: https://github.com/porrii/NexusKeys/releases/tag/v1.2.0
[1.1.1]: https://github.com/porrii/NexusKeys/releases/tag/v1.1.1
