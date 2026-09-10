import 'package:local_auth/local_auth.dart';

import '../../domain/services/biometric_service.dart';

class BiometricServiceImpl implements BiometricService {
  BiometricServiceImpl({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isDeviceSupported() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) return false;
    final available = await _localAuth.getAvailableBiometrics();
    return available.isNotEmpty;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(localizedReason: reason, biometricOnly: true);
    } on LocalAuthException catch (error) {
      // Cualquier otro código (cancelado, bloqueado por intentos, sin
      // biometría registrada, hardware no disponible, ...) es un "ahora
      // mismo no se puede desbloquear así" que la pantalla del prompt
      // biométrico ya trata igual que un intento fallido normal.
      switch (error.code) {
        case LocalAuthExceptionCode.authInProgress:
        case LocalAuthExceptionCode.deviceError:
        case LocalAuthExceptionCode.unknownError:
          rethrow;
        default:
          return false;
      }
    }
  }
}
