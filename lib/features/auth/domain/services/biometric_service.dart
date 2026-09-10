/// Envuelve el prompt biométrico propio de la plataforma (BiometricPrompt
/// de Android, Windows Hello). NexusKeys nunca tiene acceso directo al
/// sensor — ninguna app Flutter lo tiene — así que [authenticate] no es
/// más que "pídele al SO que muestre su diálogo nativo y dinos si tuvo
/// éxito".
abstract interface class BiometricService {
  /// Si este dispositivo tiene hardware biométrico usable con al menos una
  /// credencial registrada. Falso en emuladores/dispositivos sin nada
  /// configurado.
  Future<bool> isDeviceSupported();

  /// Muestra el prompt biométrico del SO con [reason] como texto de
  /// justificación. Devuelve si el usuario se autenticó correctamente;
  /// false cubre tanto "cancelado" como "fallido", ya que quien llama aquí
  /// no debe tratarlos de forma distinta.
  Future<bool> authenticate({required String reason});
}
