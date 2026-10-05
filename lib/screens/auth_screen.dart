import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'legal_info_screen.dart';

const _roles = <String, String>{
  'customer': 'Заказчик',
  'master': 'Мастер',
  'company': 'Компания',
};

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController(text: 'Петропавловск');
  final _code = TextEditingController();
  String _role = 'customer';
  bool _accepted = false;
  bool _codeSent = false;
  bool _busy = false;
  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Вход и регистрация')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.handyman_outlined, size: 54, color: Color(0xFF146B5A)),
              const SizedBox(height: 12),
              const Text('Добро пожаловать в USTA.KZ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Войдите по номеру телефона, чтобы размещать заказы и связываться с мастерами.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Имя или название компании', border: OutlineInputBorder()),
                validator: (value) => (value ?? '').trim().length < 2 ? 'Введите имя' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Я', border: OutlineInputBorder()),
                items: _roles.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: _busy ? null : (value) { if (value != null) setState(() => _role = value); },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Город', border: OutlineInputBorder()),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Укажите город' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                enabled: !_codeSent && !_busy,
                decoration: const InputDecoration(labelText: 'Номер телефона', hintText: '+7 7XX XXX XX XX', border: OutlineInputBorder()),
                validator: (value) => (value ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Проверьте номер телефона' : null,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Код из SMS', border: OutlineInputBorder()),
                  validator: (value) => (value ?? '').trim().length < 6 ? 'Введите шестизначный код' : null,
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _accepted,
                contentPadding: EdgeInsets.zero,
                onChanged: _busy ? null : (value) => setState(() => _accepted = value ?? false),
                title: const Text('Согласен с условиями использования и политикой конфиденциальности'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Wrap(spacing: 16, children: [
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LegalInfoScreen(privacy: false))),
                    child: const Text('Условия'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LegalInfoScreen(privacy: true))),
                    child: const Text('Конфиденциальность'),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : (_codeSent ? _confirmCode : _sendCode),
                icon: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_codeSent ? Icons.verified_outlined : Icons.sms_outlined),
                label: Text(_busy ? 'Подождите…' : (_codeSent ? 'Подтвердить код' : 'Получить код по SMS')),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _busy ? null : () => setState(() { _codeSent = false; _verificationId = null; _error = null; }),
                  child: const Text('Изменить номер'),
                ),
              const SizedBox(height: 12),
              Text('Номер используется для входа и связи по заказам. Firebase передаёт его Google для защиты от спама и злоупотреблений.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ),
      );

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Для продолжения нужно принять условия и политику конфиденциальности.');
      return;
    }
    final phone = _normalizedPhone(_phone.text);
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _signIn(credential);
        },
        verificationFailed: (exception) {
          if (!mounted) return;
          setState(() { _busy = false; _error = _authMessage(exception); });
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() { _busy = false; _verificationId = verificationId; _codeSent = true; });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (exception) {
      if (mounted) setState(() { _busy = false; _error = _authMessage(exception); });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'Не удалось отправить SMS. Попробуйте ещё раз.'; });
    }
  }

  Future<void> _confirmCode() async {
    if (!_formKey.currentState!.validate()) return;
    final verificationId = _verificationId;
    if (verificationId == null) {
      setState(() => _error = 'Запросите новый код.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _code.text.trim(),
      );
      await _signIn(credential);
    } on FirebaseAuthException catch (exception) {
      if (mounted) setState(() { _busy = false; _error = _authMessage(exception); });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'Не удалось подтвердить код. Попробуйте ещё раз.'; });
    }
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw StateError('Не удалось создать пользователя.');
      final profile = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final existing = await profile.get();
      if (!existing.exists) {
        final createdAt = FieldValue.serverTimestamp();
        final privateProfile = {
          'uid': user.uid,
          'displayName': _name.text.trim(),
          'phone': user.phoneNumber ?? _normalizedPhone(_phone.text),
          'city': _city.text.trim(),
          'role': _role,
          'services': const <String>[],
          'createdAt': createdAt,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final publicProfile = {
          'uid': user.uid,
          'displayName': _name.text.trim(),
          'city': _city.text.trim(),
          'role': _role,
          'services': const <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final batch = FirebaseFirestore.instance.batch();
        batch.set(profile, privateProfile);
        batch.set(FirebaseFirestore.instance.collection('publicProfiles').doc(user.uid), publicProfile);
        await batch.commit();
      }
    } on FirebaseAuthException catch (exception) {
      if (mounted) setState(() { _busy = false; _error = _authMessage(exception); });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'Не удалось завершить регистрацию. Проверьте настройки Firebase.'; });
    }
  }

  String _normalizedPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+7$digits';
    if (digits.length == 11 && digits.startsWith('8')) return '+7${digits.substring(1)}';
    if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
    return '+$digits';
  }

  String _authMessage(FirebaseAuthException exception) => switch (exception.code) {
        'invalid-phone-number' => 'Номер телефона указан неверно.',
        'invalid-verification-code' => 'Код неверный. Проверьте SMS и введите его снова.',
        'session-expired' => 'Срок действия кода истёк. Запросите новый.',
        'too-many-requests' => 'Слишком много попыток. Попробуйте позже.',
        'operation-not-allowed' => 'В Firebase Console ещё не включён вход по телефону.',
        _ => exception.message ?? 'Ошибка входа. Проверьте подключение и попробуйте снова.',
      };
}
