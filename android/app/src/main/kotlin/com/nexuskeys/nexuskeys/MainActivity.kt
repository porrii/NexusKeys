package com.nexuskeys.nexuskeys

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's BiometricPrompt integration requires a FragmentActivity —
// plain FlutterActivity doesn't implement the interfaces it needs.
class MainActivity : FlutterFragmentActivity()
