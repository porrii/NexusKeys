import 'package:flutter/material.dart';

/// Every kind of secret the vault can hold. Kept to a small set of
/// genuinely distinct kinds — each one shows its own fields in
/// EditVaultItemPage rather than a one-size-fits-all form — instead of the
/// much longer list a generic password manager spec might suggest, most of
/// which would never actually get used and wouldn't look any different
/// from "Contraseña" anyway.
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

  /// The stable string persisted in `vault_items.type` — deliberately
  /// separate from [name] so renaming an enum value in code later can't
  /// silently change what's already on disk.
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
