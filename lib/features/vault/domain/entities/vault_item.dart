import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'vault_item_type.dart';

/// One entry in the vault. Covers every item kind in [VaultItemType] with
/// the common fields the spec requires for all of them; type-specific data
/// (card expiry, WiFi security, ...) will live in the `extra_data` JSON
/// column once the dedicated per-type forms are built.
class VaultItem extends Equatable {
  const VaultItem({
    required this.type,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.id,
    this.username,
    this.password,
    this.url,
    this.notes,
    this.category,
    this.tags = const [],
    this.color,
    this.icon,
    this.isFavorite = false,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Null for an item that hasn't been persisted yet.
  final int? id;
  final VaultItemType type;
  final String title;
  final String? username;
  final String? password;
  final String? url;
  final String? notes;
  final String? category;
  final List<String> tags;
  final String? color;
  final String? icon;
  final bool isFavorite;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  VaultItem copyWith({
    int? id,
    VaultItemType? type,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? category,
    List<String>? tags,
    String? color,
    String? icon,
    bool? isFavorite,
    bool? isDeleted,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Only depends on core Dart (dart:convert) so the domain layer stays
  /// free of any specific storage engine — the data layer is responsible
  /// for turning a `sqlite3` Row into the plain map [fromMap] expects.
  Map<String, Object?> toMap() {
    return {
      'type': type.storageKey,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'category': category,
      'tags': jsonEncode(tags),
      'color': color,
      'icon': icon,
      'is_favorite': isFavorite ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      // Normalized to UTC before storage: SQLite's INTEGER column is just
      // an epoch instant with no timezone of its own, and Dart's DateTime
      // equality is sensitive to the isUtc flag — reconstructing as local
      // for what was originally a UTC value (or vice versa) would make an
      // otherwise-identical VaultItem compare unequal to itself.
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
      'deleted_at': deletedAt?.toUtc().millisecondsSinceEpoch,
    };
  }

  factory VaultItem.fromMap(Map<String, Object?> map) {
    final tagsJson = map['tags'] as String?;
    final deletedAtMillis = map['deleted_at'] as int?;

    return VaultItem(
      id: map['id'] as int?,
      type: VaultItemType.fromStorageKey(map['type'] as String),
      title: map['title'] as String,
      username: map['username'] as String?,
      password: map['password'] as String?,
      url: map['url'] as String?,
      notes: map['notes'] as String?,
      category: map['category'] as String?,
      tags: tagsJson == null ? const [] : List<String>.from(jsonDecode(tagsJson) as List),
      color: map['color'] as String?,
      icon: map['icon'] as String?,
      isFavorite: (map['is_favorite'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int, isUtc: true),
      deletedAt: deletedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedAtMillis, isUtc: true),
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        username,
        password,
        url,
        notes,
        category,
        tags,
        color,
        icon,
        isFavorite,
        isDeleted,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
