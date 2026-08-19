import 'dart:typed_data';

/// Best-effort memory hygiene helpers.
///
/// Dart offers no API to lock pages out of swap (`mlock`/`VirtualLock`) or
/// to guarantee a buffer is never copied by the GC before this runs — doing
/// that correctly would require a native platform channel. What we *can*
/// do from pure Dart is overwrite key material the instant we're done with
/// it, which is what [wipe] does; call it in a `finally` block around every
/// use of derived keys, nonces, or plaintext secrets.
void wipe(Uint8List bytes) {
  bytes.fillRange(0, bytes.length, 0);
}

/// Wipes every buffer, even if [action] throws.
Future<T> withWipe<T>(List<Uint8List> buffers, Future<T> Function() action) async {
  try {
    return await action();
  } finally {
    for (final buffer in buffers) {
      wipe(buffer);
    }
  }
}
