import 'package:equatable/equatable.dart';

/// Parámetros de coste de Argon2id usados para derivar la clave maestra de
/// la contraseña maestra del usuario. Se guardan junto al salt para que
/// una bóveda creada con un perfil de coste se pueda seguir
/// verificando/actualizando más adelante aunque cambien los valores por
/// defecto recomendados.
class Argon2idParams extends Equatable {
  const Argon2idParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// Perfil de nivel OWASP para una operación poco frecuente y de alto
  /// valor (desbloquear un gestor de contraseñas): 64 MiB de memoria, 3
  /// pasadas, 4 carriles. Es deliberadamente más pesado que un perfil de
  /// Argon2id típico de login web porque solo se ejecuta una vez por
  /// desbloqueo, no por petición.
  factory Argon2idParams.recommended() => const Argon2idParams(
        memoryKiB: 65536,
        iterations: 3,
        parallelism: 4,
      );

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, int> toJson() => {
        'memoryKiB': memoryKiB,
        'iterations': iterations,
        'parallelism': parallelism,
      };

  factory Argon2idParams.fromJson(Map<String, dynamic> json) => Argon2idParams(
        memoryKiB: json['memoryKiB'] as int,
        iterations: json['iterations'] as int,
        parallelism: json['parallelism'] as int,
      );

  @override
  List<Object?> get props => [memoryKiB, iterations, parallelism];
}
