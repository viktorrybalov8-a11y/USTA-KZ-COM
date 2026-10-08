import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

const green = Color(0xFF146B5A);
final adminScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: const FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyBZs1gEmuqCN9vbaXT7CGY0x6M_jNDnuUE'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:923347040194:android:3ead2046493d3b3b95485b'),
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
        return EmailVerificationScreen(user: user);
      }
      return AdminClaimGate(user: user);
    },
  );
}


class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({required this.user, super.key});
  final User user;
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool busy = false;
  String? message;

  Future<void> resend() async {
    setState(() { busy = true; message = null; });
    try {
      await widget.user.sendEmailVerification();
      if (mounted) setState(() => message = 'Письмо для подтверждения отправлено на ${widget.user.email}.');
    } on FirebaseAuthException {
      if (mounted) setState(() => message = 'Не удалось отправить письмо. Попробуйте позже.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    setState(() { busy = true; message = null; });
    try {
      await widget.user.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        await widget.user.getIdToken(true);
      } else if (mounted) {
        setState(() => message = 'Почта пока не подтверждена. Откройте письмо и нажмите ссылку подтверждения.');
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Не удалось проверить подтверждение. Проверьте подключение.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 56, color: green),
          const SizedBox(height: 16),
          const Text('Подтвердите email', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Для доступа к панели подтвердите адрес ${widget.user.email ?? ''}.', textAlign: TextAlign.center),
          if (message != null) ...[const SizedBox(height: 12), Text(message!, textAlign: TextAlign.center)],
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : resend, child: const Text('Отправить письмо повторно')),
          TextButton(onPressed: busy ? null : refresh, child: const Text('Я подтвердил email')),
          TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text('Выйти')),
        ],
      )),
    ))),
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
      final claims = result.data?.claims;
      final isAdmin = claims?['admin'] == true;
      final isManager = claims?['manager'] == true;
      if (result.hasError || (!isAdmin && !isManager)) {
        return AccessScreen(
          title: 'Нет доступа администратора',
          message: 'Доступ выдаётся владельцем USTA по приглашению.',
          onExit: FirebaseAuth.instance.signOut,
        );
      }
      return AdminDashboard(isOwner: isAdmin);
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : resetPassword,
            child: const Text('Забыли пароль?'),
          ),
        ],
      )),
    ))),
  );

  Future<void> resetPassword() async {
    final address = email.text.trim();
    if (address.isEmpty) {
      setState(() => error = 'Сначала укажите электронную почту.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
      if (mounted) {
        adminScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Если аккаунт зарегистрирован, письмо для сброса пароля отправлено.')),
        );
      }
    } on FirebaseAuthException {
      if (mounted) setState(() => error = 'Не удалось отправить письмо. Проверьте адрес и настройки Firebase.');
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось отправить письмо. Проверьте подключение.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
  const AdminDashboard({required this.isOwner, super.key});
  final bool isOwner;

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


  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Заявки USTA.KZ'), actions: [
      if (widget.isOwner) IconButton(
        tooltip: 'Управляющие',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminManagersScreen())),
        icon: const Icon(Icons.manage_accounts_outlined),
      ),
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


class AdminManagersScreen extends StatefulWidget {
  const AdminManagersScreen({super.key});
  @override
  State<AdminManagersScreen> createState() => _AdminManagersScreenState();
}

class _AdminManagersScreenState extends State<AdminManagersScreen> {
  bool loading = true;
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> managers = [];

  HttpsCallable get callable => FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('manageAdminAccess');

  @override
  void initState() {
    super.initState();
    loadManagers();
  }

  Future<void> loadManagers() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await callable.call(<String, dynamic>{'action': 'list'});
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = (data['managers'] as List<dynamic>? ?? const []);
      if (mounted) setState(() => managers = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList());
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => error = e.code == 'permission-denied' ? 'Управление доступно только владельцу.' : 'Не удалось загрузить список. Проверьте подключение.');
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось загрузить список управляющих.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> inviteManager() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Пригласить управляющего'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Электронная почта', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Создать доступ')),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final response = await callable.call(<String, dynamic>{'action': 'invite', 'email': email.trim()});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['created'] == true) {
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
          if (mounted) adminScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('Доступ создан. Письмо для установки пароля отправлено на ${email.trim()}.')),
          );
        } on FirebaseAuthException {
          if (mounted) adminScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('Доступ создан, но письмо не отправлено. Попросите управляющего воспользоваться «Забыли пароль?» на экране входа.')),
          );
        }
      } else if (mounted) {
        adminScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Права управляющего выданы для ${email.trim()}. Используется его текущий пароль USTA.')),
        );
      }
      await loadManagers();
    } on FirebaseFunctionsException catch (e) {
      final text = e.code == 'already-exists'
          ? 'Этот email уже имеет полный доступ администратора.'
          : e.code == 'invalid-argument'
              ? 'Проверьте адрес электронной почты.'
              : 'Не удалось создать доступ. Проверьте настройки сервера.';
      if (mounted) setState(() => error = text);
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось создать доступ. Проверьте подключение.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revokeManager(Map<String, dynamic> manager) async {
    final uid = manager['uid']?.toString() ?? '';
    final email = manager['email']?.toString() ?? 'этого пользователя';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отозвать доступ?'),
        content: Text('Управляющий $email больше не сможет открывать заявки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Отозвать')),
        ],
      ),
    );
    if (confirmed != true || uid.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await callable.call(<String, dynamic>{'action': 'revoke', 'uid': uid});
      await loadManagers();
      if (mounted) adminScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Доступ управляющего отозван.')));
    } on FirebaseFunctionsException {
      if (mounted) setState(() => error = 'Не удалось отозвать доступ. Проверьте права и подключение.');
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось отозвать доступ.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Управляющие'), actions: [
      IconButton(onPressed: loading || busy ? null : loadManagers, tooltip: 'Обновить', icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : inviteManager,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Пригласить'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.red))),
            Expanded(child: managers.isEmpty
                ? const Center(child: Text('Пока нет приглашённых управляющих.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: managers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final manager = managers[index];
                      return Card(child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.manage_accounts_outlined)),
                        title: Text(manager['email']?.toString() ?? 'Без email'),
                        subtitle: const Text('Управление заявками'),
                        trailing: IconButton(
                          tooltip: 'Отозвать доступ',
                          onPressed: busy ? null : () => revokeManager(manager),
                          icon: const Icon(Icons.person_remove_alt_1_outlined),
                        ),
                      ));
                    },
                  )),
          ]),
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
