import 'dart:typed_data';

/// Utilidades de higiene de memoria de mejor esfuerzo.
///
/// Dart no ofrece ninguna API para bloquear páginas fuera del swap
/// (`mlock`/`VirtualLock`) ni para garantizar que el GC no copie un búfer
/// antes de que esto se ejecute — hacer eso bien requeriría un canal de
/// plataforma nativo. Lo que *sí* podemos hacer desde Dart puro es
/// sobrescribir el material de clave en cuanto terminamos con él, que es
/// lo que hace [wipe]; llámalo en un bloque `finally` alrededor de cada
/// uso de claves derivadas, nonces o secretos en texto plano.
void wipe(Uint8List bytes) {
  bytes.fillRange(0, bytes.length, 0);
}

/// Limpia todos los búferes, aunque [action] lance una excepción.
Future<T> withWipe<T>(List<Uint8List> buffers, Future<T> Function() action) async {
  try {
    return await action();
  } finally {
    for (final buffer in buffers) {
      wipe(buffer);
    }
  }
}
