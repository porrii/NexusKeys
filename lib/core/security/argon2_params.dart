import 'package:equatable/equatable.dart';

/// Argon2id cost parameters used to derive the master key from the user's
/// master password. Stored alongside the salt so a vault created with one
/// cost profile can still be verified/upgraded later even if the
/// recommended defaults change.
class Argon2idParams extends Equatable {
  const Argon2idParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP-grade profile for an infrequent, high-value operation (unlocking
  /// a password manager): 64 MiB of memory, 3 passes, 4 lanes. This is
  /// deliberately heavier than a typical web-login Argon2id profile because
  /// it only runs once per unlock, not per request.
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
