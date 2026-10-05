import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});

  Future<void> _requestBusiness(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'ownerUid': user.uid,
        'phone': user.phoneNumber ?? '',
        'type': 'business',
        'planId': 'usta_business_monthly',
        'price': 9999,
        'currency': 'KZT',
        'interval': 'month',
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка отправлена. Администратор свяжется с вами для подключения и оплаты.')));
      }
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось отправить заявку. Проверьте подключение.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('USTA Business')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.workspace_premium_outlined, size: 58, color: Color(0xFF146B5A)),
          const SizedBox(height: 12),
          const Text('Больше доверия и заявок', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('USTA Business', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('9 999 ₸ / месяц', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF146B5A))),
            const Divider(height: 24),
            for (final feature in const ['Расширенная карточка компании', 'Приоритетное место в каталоге', 'Публикация портфолио и услуг', 'Базовая статистика просмотров'])
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [const Icon(Icons.check_circle_outline, size: 20), const SizedBox(width: 10), Expanded(child: Text(feature))])),
          ]))),
          const SizedBox(height: 12),
          const Text('Сейчас отправляется заявка на подключение. Оплата картой и автоматическое включение тарифа пока не подключены; администратор подтвердит условия до списания средств.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => _requestBusiness(context), icon: const Icon(Icons.send_outlined), label: const Text('Оставить заявку')),
        ]),
      );
}

class AdvertisingRequestScreen extends StatefulWidget {
  const AdvertisingRequestScreen({super.key});

  @override
  State<AdvertisingRequestScreen> createState() => _AdvertisingRequestScreenState();
}

class _AdvertisingRequestScreenState extends State<AdvertisingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _message = TextEditingController();
  String _placement = 'Баннер в приложении';
  bool _sending = false;

  @override
  void dispose() { _company.dispose(); _message.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Заказать рекламу')),
        body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Расскажите, где хотите показать рекламу. Менеджер уточнит охват, стоимость и сроки.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 18),
          TextFormField(controller: _company, maxLength: 100, decoration: const InputDecoration(labelText: 'Компания или бренд', border: OutlineInputBorder()), validator: (v) => (v ?? '').trim().length < 2 ? 'Укажите компанию или бренд' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _placement, decoration: const InputDecoration(labelText: 'Размещение', border: OutlineInputBorder()), items: const [
            DropdownMenuItem(value: 'Баннер в приложении', child: Text('Баннер в приложении')),
            DropdownMenuItem(value: 'Карточка в каталоге', child: Text('Карточка в каталоге')),
            DropdownMenuItem(value: 'Рассылка пользователям', child: Text('Рассылка пользователям')),
          ], onChanged: _sending ? null : (v) { if (v != null) setState(() => _placement = v); }),
          const SizedBox(height: 12),
          TextFormField(controller: _message, minLines: 3, maxLines: 6, maxLength: 1000, decoration: const InputDecoration(labelText: 'Что рекламируем и ваши пожелания', border: OutlineInputBorder()), validator: (v) => (v ?? '').trim().length < 5 ? 'Добавьте краткое описание' : null),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.campaign_outlined), label: Text(_sending ? 'Отправляем…' : 'Отправить заявку')),
        ])),
      );

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'ownerUid': user.uid,
        'phone': user.phoneNumber ?? '',
        'type': 'advertising',
        'company': _company.text.trim(),
        'placement': _placement,
        'message': _message.text.trim(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка отправлена. Мы свяжемся с вами.')));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось отправить заявку. Попробуйте ещё раз.')));
      }
    }
  }
}

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Заявки USTA.KZ')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('serviceRequests').orderBy('createdAt', descending: true).limit(100).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Доступ только для администратора с выданным сервером правом.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!.docs;
            if (items.isEmpty) return const Center(child: Text('Заявок пока нет.'));
            return ListView.separated(padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data();
              final business = data['type'] == 'business';
              return Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(business ? 'USTA Business · 9 999 ₸/мес' : 'Реклама · ${data['placement'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (!business) Text('${data['company'] ?? ''}: ${data['message'] ?? ''}'),
                Text('Телефон: ${data['phone'] ?? '—'}'),
                const SizedBox(height: 8),
                Row(children: [Text('Статус: ${data['status'] ?? 'new'}'), const Spacer(), DropdownButton<String>(value: ['new', 'in_progress', 'done', 'rejected'].contains(data['status']) ? data['status'] as String : 'new', items: const [
                  DropdownMenuItem(value: 'new', child: Text('Новая')),
                  DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                  DropdownMenuItem(value: 'done', child: Text('Готово')),
                  DropdownMenuItem(value: 'rejected', child: Text('Отклонена')),
                ], onChanged: (status) { if (status != null) _setStatus(context, doc.reference, status); })]),
              ])));
            });
          },
        ),
      );

  Future<void> _setStatus(BuildContext context, DocumentReference<Map<String, dynamic>> reference, String status) async {
    try {
      await reference.update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось изменить статус заявки.')));
    }
  }
}
