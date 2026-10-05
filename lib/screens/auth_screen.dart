import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'legal_info_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  bool _registering = true;
  bool _accepted = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
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
              Text(
                _registering
                    ? 'Создайте аккаунт по электронной почте. После подтверждения адреса заполните профиль.'
                    : 'Войдите по электронной почте, чтобы размещать заказы и связываться с мастерами.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Электронная почта', border: OutlineInputBorder()),
                validator: (value) {
                  final email = (value ?? '').trim();
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                      ? null
                      : 'Введите корректную электронную почту';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: _registering ? TextInputAction.next : TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  helperText: _registering ? 'Не менее 6 символов' : null,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6 ? 'Пароль должен содержать не менее 6 символов' : null,
              ),
              if (_registering) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordConfirmation,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Повторите пароль', border: OutlineInputBorder()),
                  validator: (value) => value != _password.text ? 'Пароли не совпадают' : null,
                ),
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
              ],
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_registering ? Icons.person_add_alt_1_outlined : Icons.login),
                label: Text(_busy ? 'Подождите…' : (_registering ? 'Создать аккаунт' : 'Войти')),
              ),
              TextButton(
                onPressed: _busy ? null : _resetPassword,
                child: const Text('Забыли пароль?'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _registering = !_registering;
                          _error = null;
                        }),
                child: Text(_registering ? 'Уже есть аккаунт? Войти' : 'Нужен аккаунт? Зарегистрироваться'),
              ),
              const SizedBox(height: 8),
              Text(
                'Для доступа к заказам подтвердите электронную почту. Телефон для связи укажите при заполнении профиля.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registering && !_accepted) {
      setState(() => _error = 'Для продолжения примите условия и политику конфиденциальности.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_registering) {
        final result = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await result.user!.sendEmailVerification();
      } else {
        final result = await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await result.user!.reload();
        if (!FirebaseAuth.instance.currentUser!.emailVerified) {
          await FirebaseAuth.instance.currentUser!.sendEmailVerification();
          throw FirebaseAuthException(code: 'email-not-verified');
        }
      }
    } on FirebaseAuthException catch (exception) {
      if (!mounted) return;
      if (exception.code == 'email-not-verified') {
        setState(() => _error = 'Сначала подтвердите адрес по ссылке в письме. Мы отправили письмо ещё раз.');
        await FirebaseAuth.instance.signOut();
      } else {
        setState(() => _error = _authMessage(exception));
        if (_registering && FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось подключиться. Проверьте интернет и попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Сначала введите электронную почту для сброса пароля.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _error = 'Если аккаунт зарегистрирован, письмо для сброса пароля отправлено.');
    } on FirebaseAuthException catch (exception) {
      if (mounted) setState(() => _error = _authMessage(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(FirebaseAuthException exception) => switch (exception.code) {
        'email-already-in-use' => 'Аккаунт с этой почтой уже существует. Войдите в него.',
        'invalid-email' => 'Проверьте адрес электронной почты.',
        'weak-password' => 'Выберите более надёжный пароль.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Неверная почта или пароль.',
        'too-many-requests' => 'Слишком много попыток. Попробуйте позже.',
        'operation-not-allowed' => 'В Firebase ещё не включён вход по электронной почте.',
        _ => exception.message ?? 'Не удалось войти. Попробуйте ещё раз.',
      };
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.user, required this.onVerified});

  final User user;
  final ValueChanged<User> onVerified;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _checkVerification() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.user.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified == true) {
        widget.onVerified(user!);
      } else if (mounted) {
        setState(() => _message = 'Подтверждение пока не найдено. Откройте письмо и нажмите ссылку.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Не удалось проверить статус. Проверьте подключение.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.user.sendEmailVerification();
      if (mounted) {
        setState(() => _message = 'Письмо отправлено. Проверьте входящие и папку «Спам».');
      }
    } on FirebaseAuthException catch (exception) {
      if (mounted) {
        setState(() => _message = exception.code == 'too-many-requests'
            ? 'Слишком много запросов. Подождите и попробуйте снова.'
            : 'Не удалось отправить письмо. Попробуйте позже.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Подтверждение почты'),
          actions: [TextButton(onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(), child: const Text('Выйти'))],
        ),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.mark_email_unread_outlined, size: 60, color: Color(0xFF146B5A)),
          const SizedBox(height: 16),
          const Text('Проверьте электронную почту', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Мы отправили ссылку на ${widget.user.email ?? 'ваш адрес'}. Подтвердите адрес, затем вернитесь сюда.', textAlign: TextAlign.center),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _checkVerification,
            icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            label: const Text('Я подтвердил почту'),
          ),
          TextButton(onPressed: _busy ? null : _resend, child: const Text('Отправить письмо повторно')),
        ]),
      );
}
