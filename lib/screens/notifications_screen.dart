import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('notifications').doc(uid).collection('items').orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Не удалось загрузить уведомления.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!.docs;
          if (items.isEmpty) return const Center(child: Text('Новых уведомлений пока нет.'));
          return ListView.separated(itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) {
            final item = items[index];
            final data = item.data();
            final unread = data['readAt'] == null;
            return ListTile(
              leading: CircleAvatar(backgroundColor: unread ? const Color(0xFFDCF2E9) : Colors.grey.shade200, child: Icon(unread ? Icons.notifications_active_outlined : Icons.notifications_none)),
              title: Text(data['title'] as String? ?? 'USTA.KZ', style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text(data['body'] as String? ?? ''),
              onTap: unread ? () => item.reference.update({'readAt': FieldValue.serverTimestamp()}) : null,
            );
          });
        },
      ),
    );
  }
}
