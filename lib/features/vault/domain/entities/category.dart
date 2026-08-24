import 'package:equatable/equatable.dart';

/// A managed entry in "Gestionar categorías" (img/11_categories.png).
///
/// Deliberately separate from [VaultItem.category] (a plain freeform string
/// every item carries): that field can hold any text, including one that
/// doesn't match a [Category] here — this table only exists so a category
/// can be created — and listed with a "0" count — before any item uses it.
class Category extends Equatable {
  const Category({required this.name, required this.createdAt, this.id});

  final int? id;
  final String name;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {'name': name, 'created_at': createdAt.toUtc().millisecondsSinceEpoch};
  }

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int, isUtc: true),
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt];
}
