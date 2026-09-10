import 'dart:typed_data';

/// Guarda la clave de la bóveda derivada para el desbloqueo biométrico,
/// para que esa vía pueda saltarse el volver a derivarla de la contraseña
/// maestra. Las implementaciones deben respaldarlo con almacenamiento del
/// Keystore del SO (nunca prefs/registro en plano) — ver
/// `SecureVaultKeyStore`, que respalda [read]/[save] con una clave del
/// Keystore que exige autenticación biométrica real para
/// descifrar/cifrar.
///
/// [read] no está fiablemente protegido por eso por sí solo, eso sí: en
/// Android, el almacenamiento subyacente solo muestra el prompt nativo la
/// primera vez que este proceso lo toca, y luego mantiene el cifrado
/// desbloqueado en memoria y lo reutiliza en silencio durante el resto del
/// proceso — ver [hasWarmedUpCipher]. `BiometricPromptPage` es lo que hace
/// que cada intento pregunte de verdad, llamando él mismo primero a
/// `BiometricService.authenticate` siempre que [hasWarmedUpCipher] diga
/// que [read] no preguntaría por su cuenta.
abstract interface class VaultKeyStore {
  Future<bool> get hasStoredKey;

  Future<void> save(Uint8List vaultKey);

  /// Null si no se ha guardado nada (o se limpió).
  Future<Uint8List?> read();

  Future<void> clear();

  /// True una vez [read] o [save] ha hecho que el almacenamiento
  /// subyacente se autentique al menos una vez durante este proceso de la
  /// app. Siempre false en el arranque en frío, y vuelve a ser false tras
  /// el *siguiente* arranque en frío — esto sigue la caché de cifrado en
  /// memoria del propio plugin, no nada persistido. Ver la doc de la clase
  /// para saber por qué lo necesita `BiometricPromptPage`.
  bool get hasWarmedUpCipher;
}
