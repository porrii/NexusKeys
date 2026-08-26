# Política de privacidad de NexusKeys

**Última actualización: 26 de agosto de 2026**

## Resumen

NexusKeys no recopila, almacena, transmite ni comparte ningún dato personal. No tiene servidores,
no tiene cuentas de usuario, y no se conecta a internet. Todo lo que gestionas con la app —tu
contraseña maestra, tus contraseñas guardadas, cualquier dato que introduzcas— se queda
exclusivamente en tu dispositivo, cifrado.

Si buscas la versión corta: **no recogemos nada porque no hay ningún sitio al que enviarlo.**

## Qué datos gestiona la app

NexusKeys almacena localmente, en tu dispositivo:

- Tu contraseña maestra (nunca en texto plano — solo se deriva de ella una clave criptográfica
  mediante Argon2id, que tampoco se guarda).
- Los elementos que guardes en tu bóveda (contraseñas, notas seguras, tarjetas, identidades,
  redes Wi-Fi), cifrados con AES-256 mediante SQLCipher.
- Tus preferencias de la app (tema, bloqueo automático, etc.).

Nada de esto sale de tu dispositivo salvo que tú mismo lo exportes explícitamente (Ajustes >
Importar/Exportar) para hacer una copia de seguridad, en cuyo caso el archivo resultante —también
cifrado— lo guardas donde tú decidas. La app nunca lo envía a ningún sitio por su cuenta.

## Qué datos NO recopilamos

- No hay analítica ni telemetría de ningún tipo.
- No hay reporte de fallos (crash reporting) que salga del dispositivo.
- No hay cuentas, registro, ni inicio de sesión.
- No hay sincronización en la nube.
- No se recopila tu ubicación, contactos, ni ningún otro dato del dispositivo.
- La compilación publicada de la app **no solicita permiso de acceso a internet** — no puede
  enviar datos aunque quisiera.

## Desbloqueo biométrico

Si activas el desbloqueo por huella/rostro, la app usa las APIs de seguridad del propio sistema
operativo (Android Keystore) para proteger la clave de tu bóveda. Tus datos biométricos los
gestiona el sistema operativo, no NexusKeys — la app nunca los recibe, ve, ni almacena.

## Enlaces externos

Si guardas una URL en un elemento (por ejemplo, la web de un servicio) y decides tocarla desde la
app, se abre en tu navegador — como cualquier enlace. Esa acción la haces tú, deliberadamente, y
la conexión la hace tu navegador, no NexusKeys.

## Terceros

NexusKeys no usa ningún servicio de terceros (analítica, publicidad, backend, etc.). Las
únicas dependencias son librerías de código abierto usadas para construir la app en sí (puedes
consultarlas en la app, en Ajustes > Acerca de > Licencias); ninguna de ellas transmite datos
fuera del dispositivo como parte de su uso en NexusKeys.

## Menores de edad

NexusKeys no está dirigida específicamente a menores y no recopila datos de nadie,
independientemente de su edad, precisamente porque no recopila datos de nadie en absoluto.

## Cambios en esta política

Si esta política cambia alguna vez (por ejemplo, al añadir una función nueva que sí implique
algún tipo de dato), se actualizará esta misma página con la fecha de la revisión.

## Contacto

Si tienes cualquier duda sobre esta política o sobre NexusKeys, puedes abrir un issue en el
repositorio: <https://github.com/porrii/NexusKeys/issues>.
