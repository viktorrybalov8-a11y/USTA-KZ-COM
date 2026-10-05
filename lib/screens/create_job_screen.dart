import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../app_data.dart';
import '../firebase_config.dart';
import '../models/job.dart';
import '../services/job_repository.dart';

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
  String _category = jobCategories.first;
  bool _saving = false;
  final List<XFile> _images = [];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

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
                items: jobCategories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_images.isEmpty ? 'Добавить фото (до 4)' : 'Выбрано фото: ${_images.length} из 4'),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => Stack(children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.image_outlined),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          onPressed: () => setState(() => _images.removeAt(index)),
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(JobRepository.instance.isCloudMode
                  ? 'Заказ будет опубликован в общей ленте USTA.KZ.'
                  : 'Демо-режим: заказ сохранится только на этом устройстве.',
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

  Future<void> _pickImages() async {
    if (!JobRepository.instance.isCloudMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Загрузка фото станет доступна после подключения Firebase.')),
      );
      return;
    }
    if (!FirebaseConfig.hasStorage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для фото нужно указать Firebase Storage bucket.')),
      );
      return;
    }
    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _images
          ..clear()
          ..addAll(picked.take(4));
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть галерею.')),
        );
      }
    }
  }

  Future<List<String>> _uploadImages(String jobId) async {
    final userId = JobRepository.instance.currentUserId;
    if (_images.isEmpty || userId == null) return const [];
    final urls = <String>[];
    for (var i = 0; i < _images.length; i++) {
      final image = _images[i];
      final bytes = await image.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw StateError('Каждое фото должно быть меньше 8 МБ.');
      }
      final mimeType = image.mimeType ?? 'image/jpeg';
      if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
        throw StateError('Можно загрузить только изображения.');
      }
      final reference = FirebaseStorage.instance
          .ref('jobs/$userId/$jobId/$i');
      await reference.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );
      urls.add(await reference.getDownloadURL());
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    var jobId = '';
    try {
      final digits = _budget.text.replaceAll(RegExp(r'\D'), '');
      jobId = const Uuid().v4();
      final imageUrls = await _uploadImages(jobId);
      await JobRepository.instance.add(Job(
        id: jobId,
        title: _title.text.trim(),
        category: _category,
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        description: _description.text.trim(),
        budget: digits.isEmpty ? 0 : int.parse(digits),
        createdAt: DateTime.now(),
        ownerId: JobRepository.instance.currentUserId,
        imageUrls: imageUrls,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (jobId.isNotEmpty && JobRepository.instance.isCloudMode) {
        final userId = JobRepository.instance.currentUserId;
        if (userId != null) {
          for (var index = 0; index < _images.length; index++) {
            try {
              await FirebaseStorage.instance.ref('jobs/$userId/$jobId/$index').delete();
            } catch (_) {
              // A failed/partial upload may not have created an object.
            }
          }
        }
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is StateError ? error.message : 'Не удалось сохранить заказ. Попробуйте ещё раз.')),
      );
    }
  }
}
