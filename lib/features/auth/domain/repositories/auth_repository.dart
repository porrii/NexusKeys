import '../entities/auth_result.dart';

/// Configuración y verificación de la contraseña maestra. Las
/// implementaciones nunca deben guardar la contraseña en sí ni la clave
/// derivada en crudo — solo el salt, los parámetros del KDF y un
/// verificador autenticado (ver [AuthConfig]).
abstract interface class AuthRepository {
  /// Si ya se ha configurado una contraseña maestra en este dispositivo.
  Future<bool> isVaultInitialized();

  /// Configuración inicial: genera un salt aleatorio, deriva una clave de
  /// [password] con Argon2id y guarda la cabecera de autenticación. El
  /// caso [AuthFailureReason.vaultNotInitialized] no ocurre aquí — la
  /// configuración siempre tiene éxito salvo que falle la escritura del
  /// almacenamiento subyacente, en cuyo caso se propaga la excepción de
  /// escritura.
  Future<AuthResult> setupMasterPassword(String password);

  /// Vuelve a derivar la clave de [password] y la comprueba contra el
  /// verificador guardado.
  Future<AuthResult> verifyMasterPassword(String password);

  /// Vuelve a cifrar el verificador guardado bajo una clave derivada de
  /// [newPassword], tras confirmar que [currentPassword] es correcta.
  /// Devuelve [AuthFailureReason.wrongPassword] sin cambiar nada si
  /// [currentPassword] no coincide.
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Borra la cabecera de autenticación (salt, parámetros del KDF,
  /// verificador) tras confirmar que [password] es correcta — el archivo
  /// de base de datos de la bóveda es un asunto aparte, que borra quien
  /// llama a través de [VaultSession] una vez esto tiene éxito. Devuelve
  /// [AuthFailureReason.wrongPassword] sin borrar nada si [password] no
  /// coincide.
  Future<AuthResult> deleteVault({required String password});
}
