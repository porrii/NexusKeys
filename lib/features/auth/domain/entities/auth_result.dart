import 'dart:typed_data';

/// Resultado de un intento de verificación o configuración de la
/// contraseña maestra.
sealed class AuthResult {
  const AuthResult();
}

/// La contraseña era correcta (o la configuración tuvo éxito). [vaultKey]
/// es la clave de 32 bytes en crudo derivada de ella — quien la reciba
/// debe limpiarla (ver `secure_bytes.dart`) una vez la haya usado para
/// desbloquear la base de datos cifrada.
class AuthSuccess extends AuthResult {
  const AuthSuccess(this.vaultKey);

  final Uint8List vaultKey;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;
}

enum AuthFailureReason {
  /// Todavía no se ha configurado ninguna contraseña maestra en este
  /// dispositivo.
  vaultNotInitialized,

  /// La contraseña no descifró el verificador guardado.
  wrongPassword,

  /// La cabecera de autenticación existe pero no se pudo parsear — lo más
  /// probable es un archivo corrupto o truncado, no una contraseña
  /// incorrecta.
  corruptedAuthData,
}
