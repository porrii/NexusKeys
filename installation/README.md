# Instalación del entorno de compilación

Scripts y guías para preparar una máquina nueva desde cero y poder compilar NexusKeys, sin tener
que instalar nada a mano ni recordar qué versión de qué herramienta hace falta.

- [`android/`](android/SETUP.md) — entorno para compilar la app Android (JDK, Android SDK,
  Flutter).
- [`windows/`](windows/SETUP.md) — entorno para compilar la app de escritorio Windows (Flutter,
  Visual Studio Build Tools).

Cada carpeta tiene su propio `SETUP.md` con el detalle de qué instala y por qué, y un `.bat` que
lo automatiza: pregunta en qué carpeta quieres instalarlo todo y se encarga del resto.
