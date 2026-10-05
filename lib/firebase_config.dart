import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Set these values from the Firebase project settings at build time.
/// Values are public app identifiers, never server credentials or private keys.
class FirebaseConfig {
  // Firebase client configuration is public app metadata. Authorization is
  // enforced by Firebase Auth, Security Rules, and App Check.
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBZs1gEmuqCN9vbaXT7CGY0x6M_jNDnuUE',
  );
  static const appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:923347040194:android:6fff16a782f9520195485b',
  );
  static const messagingSenderId =
      String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '923347040194',
      );
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'usta-kz',
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'usta-kz.firebasestorage.app',
  );

  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty;

  static const storageEnabled = bool.fromEnvironment(
    'FIREBASE_STORAGE_ENABLED',
    defaultValue: false,
  );

  static bool get hasStorage => storageEnabled && storageBucket.isNotEmpty;

  static FirebaseOptions? get options {
    if (!isConfigured) return null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }
}
