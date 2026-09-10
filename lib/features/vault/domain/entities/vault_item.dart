import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'vault_item_type.dart';

/// Una entrada de la bóveda. Cubre todos los tipos de elemento de
/// [VaultItemType] con los campos comunes que todos comparten; los campos
/// específicos de cada tipo (el número de una tarjeta, el número de
/// documento de una identidad, ...) viven en [extraData] en su lugar — ver
/// las constantes `key*` de abajo para saber qué claves lee y escribe de
/// verdad cada tipo.
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
    this.extraData = const {},
    this.isFavorite = false,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Campos extra de [VaultItemType.card].
  static const keyCardholder = 'cardholder';
  static const keyCardNumber = 'card_number';
  static const keyCardExpiry = 'card_expiry';
  static const keyCardCvv = 'card_cvv';

  /// Campos extra de [VaultItemType.identity].
  static const keyFullName = 'full_name';
  static const keyDocumentNumber = 'document_number';
  static const keyPhone = 'phone';

  /// Campo extra de [VaultItemType.wifi] — el SSID de la red. Su contraseña
  /// reutiliza el campo común [password] en vez de uno extra, ya que "la
  /// contraseña de la red" encaja directamente con lo que ese campo ya
  /// significa para el resto de tipos.
  static const keySsid = 'ssid';

  /// Null para un elemento que todavía no se ha guardado.
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

  /// Campos específicos de cada tipo, indexados por las constantes `key*`
  /// de arriba. Nunca contiene una entrada para un campo que el propio
  /// [type] del elemento no usa.
  final Map<String, String> extraData;

  /// Una segunda línea corta para una fila de lista — el primer campo que
  /// de verdad significa algo para el tipo de este elemento, ya que
  /// username/url solo se rellenan para [VaultItemType.password]. Cadena
  /// vacía (nunca null) cuando no aplica nada, para que quien la use pueda
  /// hacerlo directamente.
  String get subtitleHint {
    return username ??
        url ??
        extraData[keyCardNumber] ??
        extraData[keyFullName] ??
        extraData[keySsid] ??
        category ??
        '';
  }

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
    Map<String, String>? extraData,
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
      extraData: extraData ?? this.extraData,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Solo depende del Dart de base (dart:convert) para que la capa de
  /// dominio se mantenga libre de cualquier motor de almacenamiento
  /// concreto — la capa de datos es la responsable de convertir una Row de
  /// `sqlite3` en el mapa plano que espera [fromMap].
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
      'extra_data': extraData.isEmpty ? null : jsonEncode(extraData),
      'is_favorite': isFavorite ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      // Normalizado a UTC antes de guardar: la columna INTEGER de SQLite es
      // solo un instante epoch sin zona horaria propia, y la igualdad de
      // DateTime de Dart es sensible al flag isUtc — reconstruir como local
      // lo que originalmente era un valor UTC (o al revés) haría que un
      // VaultItem por lo demás idéntico se comparara como distinto de sí
      // mismo.
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
      'deleted_at': deletedAt?.toUtc().millisecondsSinceEpoch,
    };
  }

  factory VaultItem.fromMap(Map<String, Object?> map) {
    final tagsJson = map['tags'] as String?;
    final extraDataJson = map['extra_data'] as String?;
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
      extraData: extraDataJson == null
          ? const {}
          : Map<String, String>.from(jsonDecode(extraDataJson) as Map),
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
        extraData,
        isFavorite,
        isDeleted,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
