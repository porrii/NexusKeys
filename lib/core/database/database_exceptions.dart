/// Thrown when opening the vault database with a key that doesn't match
/// the one it was created with. SQLCipher doesn't reject a wrong key
/// immediately on open — the file is only proven unreadable once a query
/// is attempted — so [VaultDatabase] converts that first failed query into
/// this explicit, typed error.
class InvalidDatabaseKeyException implements Exception {
  const InvalidDatabaseKeyException();

  @override
  String toString() => 'InvalidDatabaseKeyException: the vault key could not decrypt the database';
}
