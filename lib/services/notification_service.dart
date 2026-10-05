import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_config.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  Stream<String>? _tokenChanges;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _initializedKey;

  Future<void> initialize(User user, {required String role}) async {
    final result = await user.getIdTokenResult();
    final isAdmin = result.claims?['admin'] == true;
    final configKey = '${user.uid}:$role:$isAdmin';
    if (_initializedKey == configKey) return;
    _initializedKey = configKey;
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await messaging.getToken();
    if (token != null) await _saveToken(user.uid, token);
    await messaging.subscribeToTopic('usta_all');
    if (role == 'master' || role == 'company') await messaging.subscribeToTopic('usta_masters');
    if (isAdmin) await messaging.subscribeToTopic('usta_admins');
    _tokenChanges ??= messaging.onTokenRefresh;
    await _tokenSubscription?.cancel();
    _tokenSubscription = _tokenChanges!.listen((value) {
      if (FirebaseAuth.instance.currentUser?.uid == user.uid) unawaited(_saveToken(user.uid, value));
    });
    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('USTA.KZ notification received: ${message.messageId ?? 'message'}');
    });
  }

  Future<void> detach(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final id = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(id).delete();
      }
      await FirebaseMessaging.instance.unsubscribeFromTopic('usta_all');
      await FirebaseMessaging.instance.unsubscribeFromTopic('usta_masters');
      await FirebaseMessaging.instance.unsubscribeFromTopic('usta_admins');
    } catch (_) {
      // Signing out should still finish if the device is offline.
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final id = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(id).set({
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = FirebaseConfig.options;
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
  debugPrint('USTA.KZ background notification: ${message.messageId ?? 'message'}');
}
