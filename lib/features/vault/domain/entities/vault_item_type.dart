import 'package:flutter/material.dart';

/// Every kind of secret the vault can hold, per the spec's list. Each has a
/// Spanish display label and a default color/icon used when a new item of
/// that type is created — both are then stored per-item (the "Color/Icono"
/// field every item has) so the user can override them freely afterwards.
enum VaultItemType {
  password(label: 'Contraseña', icon: Icons.lock_outline, color: Color(0xFF0D49D2)),
  account(label: 'Usuario', icon: Icons.person_outline, color: Color(0xFF1E88E5)),
  email(label: 'Email', icon: Icons.email_outlined, color: Color(0xFF5E35B1)),
  url(label: 'URL', icon: Icons.language, color: Color(0xFF00897B)),
  card(label: 'Tarjeta bancaria', icon: Icons.credit_card_outlined, color: Color(0xFF1565C0)),
  license(label: 'Licencia', icon: Icons.verified_outlined, color: Color(0xFF6D4C41)),
  secureNote(label: 'Nota segura', icon: Icons.note_outlined, color: Color(0xFFF9A825)),
  identity(label: 'Identidad', icon: Icons.badge_outlined, color: Color(0xFF8E24AA)),
  document(label: 'Documento', icon: Icons.description_outlined, color: Color(0xFF3949AB)),
  ssh(label: 'Cuenta SSH', icon: Icons.terminal, color: Color(0xFF37474F)),
  api(label: 'API', icon: Icons.api, color: Color(0xFF00838F)),
  token(label: 'Token', icon: Icons.vpn_key_outlined, color: Color(0xFF6D4C41)),
  privateKey(label: 'Clave privada', icon: Icons.key_outlined, color: Color(0xFFAD1457)),
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
        VaultItemType.account => 'account',
        VaultItemType.email => 'email',
        VaultItemType.url => 'url',
        VaultItemType.card => 'card',
        VaultItemType.license => 'license',
        VaultItemType.secureNote => 'secure_note',
        VaultItemType.identity => 'identity',
        VaultItemType.document => 'document',
        VaultItemType.ssh => 'ssh',
        VaultItemType.api => 'api',
        VaultItemType.token => 'token',
        VaultItemType.privateKey => 'private_key',
        VaultItemType.wifi => 'wifi',
      };

  static VaultItemType fromStorageKey(String key) =>
      VaultItemType.values.firstWhere(
        (t) => t.storageKey == key,
        orElse: () => throw ArgumentError('Unknown VaultItemType storage key: $key'),
      );
}
