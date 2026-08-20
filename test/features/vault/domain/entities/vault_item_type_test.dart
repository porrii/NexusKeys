import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';

void main() {
  test('every type round-trips through its storage key', () {
    for (final type in VaultItemType.values) {
      expect(VaultItemType.fromStorageKey(type.storageKey), type);
    }
  });

  test('storage keys are unique', () {
    final keys = VaultItemType.values.map((t) => t.storageKey).toSet();
    expect(keys.length, VaultItemType.values.length);
  });

  test('fromStorageKey throws on an unknown key', () {
    expect(() => VaultItemType.fromStorageKey('not-a-real-type'), throwsArgumentError);
  });
}
