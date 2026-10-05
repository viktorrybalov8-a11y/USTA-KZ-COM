import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/job_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseError;
  var cloudEnabled = false;
  final options = FirebaseConfig.options;
  if (FirebaseConfig.isConfigured && options == null) {
    firebaseError = 'Для этой платформы Firebase-конфигурация ещё не подготовлена.';
  } else if (options != null) {
    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      cloudEnabled = true;
    } catch (error) {
      firebaseError = 'Не удалось подключить Firebase: $error';
    }
  }
  await JobRepository.instance.initialize();
  runApp(UstaApp(cloudEnabled: cloudEnabled, firebaseError: firebaseError));
}

class UstaApp extends StatelessWidget {
  const UstaApp({super.key, required this.cloudEnabled, this.firebaseError});

  final bool cloudEnabled;
  final String? firebaseError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'USTA.KZ',
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF146B5A),
      scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F6),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    home: firebaseError != null
        ? _FirebaseFailure(message: firebaseError!)
        : cloudEnabled
            ? const AuthGate()
            : const HomeScreen(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _subscription;
  User? _user;
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final previousUser = _user;
      if (previousUser != null && previousUser.uid != user?.uid) {
        await NotificationService.instance.detach(previousUser.uid);
      }
      await JobRepository.instance.connectCloud(
        firestore: FirebaseFirestore.instance,
        userId: user != null && (user.email == null || user.emailVerified) ? user.uid : null,
      );
      var isAdmin = false;
      if (user != null) {
        try {
          final token = await user.getIdTokenResult();
          isAdmin = token.claims?['admin'] == true;
        } catch (_) {
          isAdmin = false;
        }
      }
      if (!mounted) return;
      setState(() { _user = user; _isAdmin = isAdmin; _loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_user == null) return const AuthScreen();
    if (_user!.email != null && !_user!.emailVerified) {
      return EmailVerificationScreen(user: _user!, onVerified: _onEmailVerified);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return _FirebaseFailure(message: 'Не удалось прочитать профиль. Проверьте правила Firestore.');
        final profile = snapshot.data?.data();
        if (profile == null) return ProfileSetupScreen(user: _user!);
        unawaited(NotificationService.instance.initialize(
          _user!,
          role: profile['role'] as String? ?? 'customer',
        ).catchError((Object _) {}));
        return HomeScreen(currentUser: _user!, profile: profile, isAdmin: _isAdmin);
      },
    );
  }

  Future<void> _onEmailVerified(User user) async {
    await JobRepository.instance.connectCloud(
      firestore: FirebaseFirestore.instance,
      userId: user.uid,
    );
    var isAdmin = false;
    try {
      final token = await user.getIdTokenResult(true);
      isAdmin = token.claims?['admin'] == true;
    } catch (_) {
      isAdmin = false;
    }
    if (mounted) setState(() {
      _user = user;
      _isAdmin = isAdmin;
    });
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.user});
  final User user;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController(text: 'Петропавловск');
  String _role = 'customer';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.user.displayName ?? '';
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _city.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Настройка профиля')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Заполните профиль, чтобы начать работу в USTA.KZ.'),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Имя или компания', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'Город', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Телефон для связи', hintText: '+7 7XX XXX XX XX', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Тип профиля', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'customer', child: Text('Заказчик')),
              DropdownMenuItem(value: 'master', child: Text('Мастер')),
              DropdownMenuItem(value: 'company', child: Text('Компания')),
            ],
            onChanged: (value) { if (value != null) setState(() => _role = value); },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Сохраняем…' : 'Сохранить профиль'),
          ),
          TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Выйти')),
        ]),
      );

  Future<void> _save() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (_name.text.trim().length < 2 || _city.text.trim().isEmpty || digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите имя, город и корректный номер телефона.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final privateProfile = {
        'uid': widget.user.uid,
        'displayName': _name.text.trim(),
        'phone': _normalizedPhone(_phone.text),
        'city': _city.text.trim(),
        'role': _role,
        'services': const <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final publicProfile = {
        'uid': widget.user.uid,
        'displayName': _name.text.trim(),
        'city': _city.text.trim(),
        'role': _role,
        'services': const <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(firestore.collection('users').doc(widget.user.uid), privateProfile);
      batch.set(firestore.collection('publicProfiles').doc(widget.user.uid), publicProfile);
      await batch.commit();
      await widget.user.updateDisplayName(_name.text.trim());
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось сохранить профиль. Проверьте правила Firestore.')));
    }
  }

  String _normalizedPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+7$digits';
    if (digits.length == 11 && digits.startsWith('8')) return '+7${digits.substring(1)}';
    if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
    return '+$digits';
  }
}

class _FirebaseFailure extends StatelessWidget {
  const _FirebaseFailure({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Не удалось подключить сервис USTA.KZ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}
