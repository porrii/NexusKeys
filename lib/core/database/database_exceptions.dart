/// Se lanza al abrir la base de datos de la bóveda con una clave que no
/// coincide con la que se usó al crearla. SQLCipher no rechaza una clave
/// incorrecta nada más abrir el archivo — solo se comprueba que es
/// ilegible al intentar una consulta — así que [VaultDatabase] convierte
/// esa primera consulta fallida en este error explícito y tipado.
class InvalidDatabaseKeyException implements Exception {
  const InvalidDatabaseKeyException();

  @override
  String toString() => 'InvalidDatabaseKeyException: the vault key could not decrypt the database';
}
