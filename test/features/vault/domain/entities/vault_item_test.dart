import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1, 12);
  final updatedAt = DateTime.utc(2026, 1, 2, 8, 30);

  VaultItem sample() => VaultItem(
        id: 7,
        type: VaultItemType.password,
        title: 'GitHub',
        username: 'ivan_dev',
        password: 's3cr3t',
        url: 'https://github.com',
        notes: 'work account',
        category: 'Trabajo',
        tags: const ['dev', 'work'],
        color: '#FF0000',
        icon: 'lock',
        isFavorite: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  test('toMap/fromMap round-trips every field', () {
    final restored = VaultItem.fromMap({...sample().toMap(), 'id': 7});

    expect(restored, sample());
  });

  test('toMap encodes booleans as 0/1 and tags as a JSON array string', () {
    final map = sample().toMap();

    expect(map['is_favorite'], 1);
    expect(map['is_deleted'], 0);
    expect(map['tags'], '["dev","work"]');
  });

  test('fromMap defaults tags to an empty list when null', () {
    final map = sample().toMap()..['tags'] = null;
    final restored = VaultItem.fromMap({...map, 'id': 7});

    expect(restored.tags, isEmpty);
  });

  test('copyWith overrides only the given fields', () {
    final renamed = sample().copyWith(title: 'GitHub (renamed)');

    expect(renamed.title, 'GitHub (renamed)');
    expect(renamed.username, sample().username);
    expect(renamed.id, sample().id);
  });

  test('copyWith cannot change createdAt — it is fixed at construction', () {
    final laterUpdate = sample().copyWith(updatedAt: DateTime.utc(2027));

    expect(laterUpdate.createdAt, createdAt);
  });

  test('two items with identical fields are equal', () {
    expect(sample(), sample());
  });

  test('a different id makes two otherwise-identical items unequal', () {
    expect(sample(), isNot(sample().copyWith(id: 8)));
  });
}
