import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../app_data.dart';
import '../firebase_config.dart';
import '../models/job.dart';
import '../services/chat_service.dart';
import '../services/job_repository.dart';
import 'chat_screens.dart';
import 'create_job_screen.dart';
import 'master_directory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.currentUser, this.profile});

  final User? currentUser;
  final Map<String, dynamic>? profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = JobRepository.instance;
  final _search = TextEditingController();
  String _category = 'Все';
  String _city = 'Все города';

  @override
  void initState() {
    super.initState();
    _repository.addListener(_refresh);
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _repository.removeListener(_refresh);
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Job> get _visibleJobs {
    final query = _search.text.trim().toLowerCase();
    return _repository.jobs.where((job) {
      final matchesCategory = _category == 'Все' || job.category == _category;
      final matchesCity = _city == 'Все города' || job.city.toLowerCase() == _city.toLowerCase();
      final matchesText = query.isEmpty ||
          '${job.title} ${job.city} ${job.category} ${job.description}'
              .toLowerCase()
              .contains(query);
      return matchesCategory && matchesCity && matchesText;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _visibleJobs;
    final categories = ['Все', ...jobCategories];
    return Scaffold(
      appBar: AppBar(
        title: const Text('USTA.KZ', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: widget.currentUser == null
            ? [
                IconButton(
                  tooltip: 'Информация о приложении',
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: 'USTA.KZ',
                    applicationVersion: '0.2.0',
                    children: const [Text('Демо-режим: заказы хранятся только на этом устройстве.')],
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Мастера и компании',
                  icon: const Icon(Icons.people_outline),
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MasterDirectoryScreen())),
                ),
                IconButton(
                  tooltip: 'Сообщения',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ChatListScreen())),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Профиль',
                  icon: const Icon(Icons.account_circle_outlined),
                  onSelected: (value) {
                    if (value == 'sign_out') FirebaseAuth.instance.signOut();
                    if (value == 'profile') _showProfile(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'profile', child: Text('Мой профиль')),
                    PopupMenuItem(value: 'sign_out', child: Text('Выйти')),
                  ],
                ),
              ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const CreateJobScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Создать заказ'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (!_repository.isCloudMode)
            Card(
              color: const Color(0xFFFFF4D6),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Демо-режим: публикация общих заказов включится после настройки Firebase.'),
              ),
            ),
          if (_repository.error != null)
            Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_repository.error!))),
          const Text('Найдите работу или мастера',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Заказы в вашем городе', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Поиск по заказам',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      onPressed: _search.clear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _city,
            decoration: const InputDecoration(labelText: 'Город', prefixIcon: Icon(Icons.location_on_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
            items: ['Все города', ...kazakhstanCities]
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
            onChanged: (city) { if (city != null) setState(() => _city = city); },
          ),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            _EmptyState(hasOrders: _repository.jobs.isNotEmpty)
          else
            ...jobs.map((job) => _JobCard(
                  job: job,
                  onDelete: (_repository.isCloudMode && job.ownerId != _repository.currentUserId)
                      ? null
                      : () => _confirmDelete(job),
                  onOpen: () => _showDetails(job),
                )),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заказ?'),
        content: Text(_repository.isCloudMode
            ? '«${job.title}» будет удалён из общей ленты.'
            : '«${job.title}» будет удалён с этого устройства.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) await _repository.remove(job.id);
  }

  void _showDetails(Job job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('${job.city} · ${job.category}'),
              const SizedBox(height: 8),
              Text(job.budget == 0 ? 'Бюджет не указан' : '${job.budget} ₸'),
              const SizedBox(height: 12),
              if (job.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(job.imageUrls[index], width: 180, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 180, child: Icon(Icons.broken_image_outlined))),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(job.description),
              if (widget.currentUser != null && job.ownerId != null && job.ownerId != widget.currentUser!.uid) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        final id = await ChatService.instance.openConversation(job.ownerId!);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversationId: id, otherUserId: job.ownerId!)));
                      } catch (_) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть переписку.')));
                      }
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Написать заказчику'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SelectableText('Телефон: ${job.phone}'),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfile(BuildContext context) {
    final profile = widget.profile ?? const <String, dynamic>{};
    var photoUrl = profile['photoUrl'] as String?;
    var uploading = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(profile['displayName'] as String? ?? 'Мой профиль'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
                child: const Icon(Icons.person_outline, size: 36),
              ),
              TextButton.icon(
                onPressed: uploading ? null : () async {
                  if (!FirebaseConfig.hasStorage) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала настройте Firebase Storage.')));
                    return;
                  }
                  try {
                    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
                    if (image == null || !context.mounted) return;
                    final bytes = await image.readAsBytes();
                    if (bytes.length > 5 * 1024 * 1024) throw StateError('Фото должно быть меньше 5 МБ.');
                    setDialogState(() => uploading = true);
                    final user = widget.currentUser!;
                    final mimeType = image.mimeType ?? 'image/jpeg';
                    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) throw StateError('Выберите фото в формате JPEG, PNG или WebP.');
                    final ref = FirebaseStorage.instance.ref('profiles/${user.uid}/avatar');
                    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
                    final url = await ref.getDownloadURL();
                    final firestore = FirebaseFirestore.instance;
                    final batch = firestore.batch();
                    batch.update(firestore.collection('users').doc(user.uid), {'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
                    batch.update(firestore.collection('publicProfiles').doc(user.uid), {'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
                    await batch.commit();
                    if (context.mounted) setDialogState(() { photoUrl = url; uploading = false; });
                  } catch (error) {
                    if (context.mounted) setDialogState(() => uploading = false);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is StateError ? error.message : 'Не удалось загрузить фото.')));
                  }
                },
                icon: uploading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_outlined),
                label: Text(uploading ? 'Загружаем…' : 'Изменить фото'),
              ),
              const SizedBox(height: 8),
              Text([
                _roleName(profile['role'] as String?),
                profile['city'] as String? ?? '',
                widget.currentUser?.phoneNumber ?? '',
              ].where((value) => value.isNotEmpty).join('\n'), textAlign: TextAlign.center),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Закрыть'))],
        ),
      ),
    );
  }

  String _roleName(String? role) => switch (role) {
        'master' => 'Мастер',
        'company' => 'Компания',
        'customer' => 'Заказчик',
        _ => '',
      };
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onDelete, required this.onOpen});

  final Job job;
  final VoidCallback? onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                job.imageUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(job.imageUrls.first, width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const CircleAvatar(child: Icon(Icons.handyman_outlined))),
                      )
                    : const CircleAvatar(child: Icon(Icons.handyman_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('${job.city} · ${job.category}', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text(job.budget == 0 ? 'Бюджет не указан' : '${job.budget} ₸',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Действия с заказом',
                    onSelected: (_) => onDelete!(),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Удалить'))],
                  ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasOrders});
  final bool hasOrders;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(hasOrders ? Icons.search_off : Icons.work_outline, size: 42, color: Colors.teal),
            const SizedBox(height: 10),
            Text(hasOrders ? 'Ничего не найдено' : 'Пока нет заказов',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(hasOrders ? 'Измените запрос или выберите другую категорию.' : 'Создайте первый заказ на этом устройстве.'),
          ]),
        ),
      );
}
