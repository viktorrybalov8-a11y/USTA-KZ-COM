import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screens.dart';
import '../services/chat_service.dart';

class MasterDirectoryScreen extends StatelessWidget {
  const MasterDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Мастера и компании')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('publicProfiles')
              .where('role', whereIn: const ['master', 'company'])
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Не удалось загрузить каталог. Проверьте правила Firestore.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final profiles = snapshot.data!.docs.toList()
              ..sort((a, b) => (a.data()['displayName'] as String? ?? '').compareTo(b.data()['displayName'] as String? ?? ''));
            if (profiles.isEmpty) return const Center(child: Text('Пока нет профилей мастеров и компаний.'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = profiles[index].data();
                final uid = profiles[index].id;
                final self = uid == FirebaseAuth.instance.currentUser?.uid;
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      foregroundImage: (profile['photoUrl'] as String?) == null ? null : NetworkImage(profile['photoUrl'] as String),
                      child: Icon(profile['role'] == 'company' ? Icons.business_outlined : Icons.handyman_outlined),
                    ),
                    title: Text(profile['displayName'] as String? ?? 'Профиль USTA.KZ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${profile['role'] == 'company' ? 'Компания' : 'Мастер'} · ${profile['city'] as String? ?? ''}'),
                    trailing: self ? const Chip(label: Text('Вы')) : IconButton(
                      tooltip: 'Написать',
                      icon: const Icon(Icons.chat_outlined),
                      onPressed: () async {
                        try {
                          final id = await ChatService.instance.openConversation(uid);
                          if (!context.mounted) return;
                          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversationId: id, otherUserId: uid)));
                        } catch (_) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть диалог.')));
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
