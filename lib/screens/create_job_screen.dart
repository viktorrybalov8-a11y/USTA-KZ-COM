import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/job.dart';
import '../services/job_repository.dart';

const _categories = [
  'Отделка',
  'Металлоконструкции',
  'Бетонные работы',
  'Кровля',
  'Электрика',
  'Сантехника',
  'Другое',
];

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _city = TextEditingController(text: 'Петропавловск');
  final _phone = TextEditingController();
  final _budget = TextEditingController();
  final _description = TextEditingController();
  String _category = _categories.first;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _phone.dispose();
    _budget.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Новый заказ')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Опишите, какая помощь нужна',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 70,
                decoration: const InputDecoration(labelText: 'Название заказа *', border: OutlineInputBorder()),
                validator: _required,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
                items: _categories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: _saving ? null : (value) { if (value != null) setState(() => _category = value); },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Город *', border: OutlineInputBorder()),
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон для связи *',
                  hintText: '+7 7XX XXX XX XX',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                    ? 'Введите корректный номер телефона'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Бюджет, ₸',
                  hintText: 'Можно оставить пустым',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return null;
                  final amount = int.tryParse(value!.replaceAll(RegExp(r'\D'), ''));
                  return amount == null || amount < 0 ? 'Укажите сумму цифрами' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Подробности *', border: OutlineInputBorder()),
                validator: _required,
              ),
              const SizedBox(height: 8),
              Text('Сейчас заказ сохранится только на этом устройстве.',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish),
                label: Text(_saving ? 'Сохранение…' : 'Сохранить заказ'),
              ),
            ],
          ),
        ),
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Обязательное поле' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final digits = _budget.text.replaceAll(RegExp(r'\D'), '');
      await JobRepository.instance.add(Job(
        id: const Uuid().v4(),
        title: _title.text.trim(),
        category: _category,
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        description: _description.text.trim(),
        budget: digits.isEmpty ? 0 : int.parse(digits),
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить заказ. Попробуйте ещё раз.')),
      );
    }
  }
}
