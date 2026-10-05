import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/job_repository.dart';
import 'create_job_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = JobRepository.instance;
  final _search = TextEditingController();
  String _category = 'Все';

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
      final matchesText = query.isEmpty ||
          '${job.title} ${job.city} ${job.category} ${job.description}'
              .toLowerCase()
              .contains(query);
      return matchesCategory && matchesText;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _visibleJobs;
    final categories = ['Все', ..._repository.jobs.map((job) => job.category).toSet()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('USTA.KZ', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Информация о приложении',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'USTA.KZ',
              applicationVersion: '0.1.0',
              children: const [
                Text('Демонстрационная сборка. Заказы пока хранятся только на этом устройстве.'),
              ],
            ),
            icon: const Icon(Icons.info_outline),
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
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            _EmptyState(hasOrders: _repository.jobs.isNotEmpty)
          else
            ...jobs.map((job) => _JobCard(
                  job: job,
                  onDelete: () => _confirmDelete(job),
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
        content: Text('«${job.title}» будет удалён с этого устройства.'),
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
              Text(job.description),
              const SizedBox(height: 12),
              SelectableText('Телефон: ${job.phone}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onDelete, required this.onOpen});

  final Job job;
  final VoidCallback onDelete;
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
                const CircleAvatar(child: Icon(Icons.handyman_outlined)),
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
                PopupMenuButton<String>(
                  tooltip: 'Действия с заказом',
                  onSelected: (_) => onDelete(),
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
