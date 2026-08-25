# NexusKeys

A private, fully offline password manager for Android and Windows. No account,
no server, no telemetry — everything is derived and stored locally, encrypted
at rest.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-informational)](#)

## Features

- **Master password unlock**, with an optional OS-Keystore-backed biometric
  unlock (fingerprint / face) for faster access.
- **Full vault CRUD** for logins, bank cards, secure notes, identities and
  Wi-Fi credentials, each with its own relevant fields.
- **Built-in password generator** with configurable length and character sets.
- **Tags & favorites** for organizing and quickly filtering the vault, plus a
  live search across titles, usernames and tags.
- **Soft-delete trash** — deleted items can be restored before they're gone
  for good.
- **Encrypted export / import** to a single portable backup file.
- **Adaptive UI** — a compact layout on phones, and a persistent
  sidebar + list + detail layout on tablets and Windows.
- **Dark theme**, matched pixel-for-pixel to the app's design mockups.

## Security architecture

NexusKeys is built around three well-established primitives, chosen
specifically for a local password manager rather than a general-purpose app:

| Layer | Primitive | Purpose |
|---|---|---|
| Key derivation | **Argon2id** (64 MiB, 3 iterations, 4 lanes) | Turns the master password into the vault's encryption key. Cost parameters are stored alongside the vault, so they can be upgraded later without breaking existing vaults. |
| Data at rest | **SQLCipher** (AES-256) | The entire vault database is an encrypted SQLite file — nothing is ever written to disk in plaintext. |
| Field-level secrets | **AES-256-GCM** | Used for authenticated encryption of exported backups and Keystore-protected material. |
| Biometric unlock | **Android Keystore** | The stored vault key is gated by `BiometricPrompt` at the OS/hardware level — unlocking it is a Keystore operation, not an app-level check that can be bypassed. |

No plaintext secret — master password, derived key, or vault contents — is
ever written to disk or sent anywhere. NexusKeys has no network permission
requirement beyond opening a URL the user explicitly taps, and ships with
zero analytics, crash reporting, or telemetry dependencies.

This project has not undergone an independent third-party security audit.
Treat it as any other unaudited open-source software.

## Tech stack

- [Flutter](https://flutter.dev) / Dart, organized as Clean Architecture
  (`domain` / `data` / `presentation`) per feature.
- [`get_it`](https://pub.dev/packages/get_it) for dependency injection,
  [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) for state.
- [`sqlite3`](https://pub.dev/packages/sqlite3) with its SQLCipher build hook
  for the encrypted local database.
- [`cryptography`](https://pub.dev/packages/cryptography) /
  [`cryptography_flutter`](https://pub.dev/packages/cryptography_flutter) for
  Argon2id and AES-256-GCM.
- [`local_auth`](https://pub.dev/packages/local_auth) and
  [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  for Keystore-backed biometric unlock.

## Getting started

```bash
flutter pub get
flutter run
```

The encrypted SQLite build is fetched automatically via Dart's build hooks
(see the `hooks:` section in `pubspec.yaml`) — no separate native setup is
required.

### Tests

```bash
flutter test
```

## Project structure

```
lib/
  core/            # DI, theming, database, crypto services shared app-wide
  features/
    auth/          # Master password, biometric unlock, vault lifecycle
    vault/         # Vault items: CRUD, search, tags, trash
    generator/     # Password generator
    backup/        # Encrypted export / import
    settings/      # Settings, tags management, about
```

Each feature follows the same internal split: `domain` (entities,
repository interfaces), `data` (repository implementations, local data
sources) and `presentation` (pages, widgets).

## License

MIT — see [LICENSE](LICENSE).
