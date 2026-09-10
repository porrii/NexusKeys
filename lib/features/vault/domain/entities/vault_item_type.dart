import 'package:flutter/material.dart';

/// Todos los tipos de secreto que puede guardar la bóveda. Se mantiene en
/// un conjunto pequeño de tipos genuinamente distintos — cada uno muestra
/// sus propios campos en EditVaultItemPage en vez de un formulario único
/// para todo — en vez de la lista mucho más larga que podría sugerir la
/// especificación de un gestor de contraseñas genérico, la mayoría de la
/// cual nunca se usaría de verdad y de todas formas no se vería distinta de
/// "Contraseña".
enum VaultItemType {
  password(label: 'Contraseña', icon: Icons.lock_outline, color: Color(0xFF0D49D2)),
  card(label: 'Tarjeta bancaria', icon: Icons.credit_card_outlined, color: Color(0xFF1565C0)),
  secureNote(label: 'Nota segura', icon: Icons.note_outlined, color: Color(0xFFF9A825)),
  identity(label: 'Identidad', icon: Icons.badge_outlined, color: Color(0xFF8E24AA)),
  wifi(label: 'WiFi', icon: Icons.wifi, color: Color(0xFF2E7D32));

  const VaultItemType({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  /// La cadena estable que se guarda en `vault_items.type` —
  /// deliberadamente separada de [name] para que renombrar más tarde un
  /// valor del enum en el código no cambie en silencio lo que ya está en
  /// disco.
  String get storageKey => switch (this) {
        VaultItemType.password => 'password',
        VaultItemType.card => 'card',
        VaultItemType.secureNote => 'secure_note',
        VaultItemType.identity => 'identity',
        VaultItemType.wifi => 'wifi',
      };

  static VaultItemType fromStorageKey(String key) =>
      VaultItemType.values.firstWhere(
        (t) => t.storageKey == key,
        orElse: () => throw ArgumentError('Unknown VaultItemType storage key: $key'),
      );
}
