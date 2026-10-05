import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

const green = Color(0xFF146B5A);
final adminScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: const FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyBZs1gEmuqCN9vbaXT7CGY0x6M_jNDnuUE'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:923347040194:android:6fff16a782f9520195485b'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '923347040194'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'usta-kz'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'usta-kz.firebasestorage.app'),
  ));
  runApp(const UstaAdminApp());
}

class UstaAdminApp extends StatelessWidget {
  const UstaAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: adminScaffoldMessengerKey,
    title: 'USTA Администратор',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: green, scaffoldBackgroundColor: const Color(0xFFF4F7F6)),
    home: const AdminGate(),
  );
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, auth) {
      if (auth.connectionState == ConnectionState.waiting) return const LoadingScreen();
      final user = auth.data;
      if (user == null) return const AdminSignInScreen();
      if (user.email != null && !user.emailVerified) {
        return const AccessScreen(title: 'Подтвердите почту', message: 'Подтвердите адрес электронной почты, затем войдите снова.');
      }
      return AdminClaimGate(user: user);
    },
  );
}

class AdminClaimGate extends StatelessWidget {
  const AdminClaimGate({required this.user, super.key});
  final User user;
  @override
  Widget build(BuildContext context) => FutureBuilder<IdTokenResult>(
    future: user.getIdTokenResult(true),
    builder: (context, result) {
      if (result.connectionState == ConnectionState.waiting) return const LoadingScreen();
      if (result.hasError || result.data?.claims?['admin'] != true) {
        return AccessScreen(
          title: 'Нет доступа администратора',
          message: 'Для этого аккаунта нужно выдать серверное право администратора.',
          onExit: FirebaseAuth.instance.signOut,
        );
      }
      return const AdminDashboard();
    },
  );
}

class AdminSignInScreen extends StatefulWidget {
  const AdminSignInScreen({super.key});
  @override
  State<AdminSignInScreen> createState() => _AdminSignInScreenState();
}
class _AdminSignInScreenState extends State<AdminSignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 64, color: green),
          const SizedBox(height: 14),
          const Text('USTA Администратор', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Войдите в служебный аккаунт для обработки заявок.', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Электронная почта', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, onSubmitted: (_) => signIn(), decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder())),
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : signIn, child: Text(busy ? 'Входим…' : 'Войти')),
        ],
      )),
    ))),
  );

  Future<void> signIn() async {
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.code == 'too-many-requests' ? 'Слишком много попыток. Попробуйте позже.' : 'Проверьте почту и пароль.');
    } catch (_) {
      setState(() => error = 'Не удалось войти. Проверьте подключение.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class AdminPushService {
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _messageSubscription;

  static Future<void> initialize(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) await _saveToken(user.uid, token);
      await messaging.subscribeToTopic('usta_all');
      await messaging.subscribeToTopic('usta_admins');
      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen((value) {
        unawaited(_saveToken(user.uid, value));
      });
      await _messageSubscription?.cancel();
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        adminScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              [notification?.title, notification?.body]
                  .whereType<String>()
                  .where((part) => part.isNotEmpty)
                  .join(' · '),
            ),
          ),
        );
      });
    } catch (_) {
      // The admin dashboard remains usable if push setup is temporarily unavailable.
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    final id = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(id)
        .set({
      'token': token,
      'platform': 'android',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> detachAndSignOut() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          final id = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('devices')
              .doc(id)
              .delete();
        }
      }
      await FirebaseMessaging.instance.unsubscribeFromTopic('usta_all');
      await FirebaseMessaging.instance.unsubscribeFromTopic('usta_admins');
      await _tokenSubscription?.cancel();
      await _messageSubscription?.cancel();
    } catch (_) {
      // Signing out should still finish if the device is offline.
    }
    await FirebaseAuth.instance.signOut();
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) unawaited(AdminPushService.initialize(user));
  }


  const AdminDashboard({super.key});
  @override
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Заявки USTA.KZ'), actions: [
      IconButton(tooltip: 'Выйти', onPressed: AdminPushService.detachAndSignOut, icon: const Icon(Icons.logout)),
    ]),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('serviceRequests').orderBy('createdAt', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AccessScreen(title: 'Не удалось загрузить заявки', message: 'Проверьте подключение и права администратора.');
        if (!snapshot.hasData) return const LoadingScreen();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Заявок пока нет.'));
        final fresh = docs.where((d) => d.data()['status'] == 'new').length;
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Card(color: Colors.white, child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F3ED), child: Icon(Icons.inbox_outlined, color: green)),
            title: Text('${docs.length} последних заявок'),
            subtitle: Text('$fresh новых · обновляются автоматически'),
          ))),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => RequestCard(request: docs[i]),
          )),
        ]);
      },
    ),
  );
}

class RequestCard extends StatelessWidget {
  const RequestCard({required this.request, super.key});
  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final business = data['type'] == 'business';
    final status = data['status'] as String? ?? 'new';
    return Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(business ? 'USTA Business · 9 999 ₸/мес' : 'Реклама · ${data['placement'] ?? 'заявка'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        if (!business) ...[const SizedBox(height: 6), Text('${data['company'] ?? ''}'), Text('${data['message'] ?? ''}')],
        const SizedBox(height: 8),
        Text('Телефон: ${data['phone'] ?? '—'}'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: const ['new', 'in_progress', 'done', 'rejected'].contains(status) ? status : 'new',
          decoration: const InputDecoration(labelText: 'Статус', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'new', child: Text('Новая')),
            DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
            DropdownMenuItem(value: 'done', child: Text('Готово')),
            DropdownMenuItem(value: 'rejected', child: Text('Отклонена')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            try {
              await request.reference.update({'status': value, 'updatedAt': FieldValue.serverTimestamp()});
            } catch (_) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось изменить статус.')));
            }
          },
        ),
      ],
    )));
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class AccessScreen extends StatelessWidget {
  const AccessScreen({required this.title, required this.message, this.onExit, super.key});
  final String title;
  final String message;
  final Future<void> Function()? onExit;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.lock_outline, size: 48, color: green),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center),
      if (onExit != null) ...[const SizedBox(height: 16), OutlinedButton(onPressed: onExit, child: const Text('Выйти'))],
    ]),
  )));
}
