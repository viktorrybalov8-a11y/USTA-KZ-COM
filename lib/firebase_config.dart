import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Set these values from the Firebase project settings at build time.
/// Values are public app identifiers, never server credentials or private keys.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'usta-kz',
  );
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty;

  static bool get hasStorage => storageBucket.isNotEmpty;

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
