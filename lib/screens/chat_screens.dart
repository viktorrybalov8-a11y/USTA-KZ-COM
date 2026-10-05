import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final stream = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Не удалось загрузить сообщения.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final conversations = snapshot.data!.docs;
          if (conversations.isEmpty) return const Center(child: Text('Пока нет диалогов. Откройте заказ или найдите мастера.'));
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = conversations[index].data();
              final members = (data['participants'] as List<dynamic>? ?? const []).cast<String>();
              final other = members.firstWhere((member) => member != uid, orElse: () => '');
              final preview = data['lastMessage'] as String? ?? '';
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                title: Text('Диалог · ${other.isEmpty ? 'USTA.KZ' : other.substring(0, other.length > 8 ? 8 : other.length)}'),
                subtitle: Text(preview.isEmpty ? 'Начните переписку' : preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(
                  conversationId: conversations[index].id,
                  otherUserId: other,
                ))),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId, required this.otherUserId});
  final String conversationId;
  final String otherUserId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final messages = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Переписка')),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Не удалось загрузить переписку.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!.docs;
              if (items.isEmpty) return const Center(child: Text('Напишите первое сообщение.'));
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final message = items[index].data();
                  final own = message['senderId'] == uid;
                  return Align(
                    alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: own ? const Color(0xFFDCF2E9) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(message['text'] as String? ?? ''),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(hintText: 'Сообщение', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Отправить',
                onPressed: _sending ? null : _send,
                icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendMessage(widget.conversationId, text);
      _controller.clear();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось отправить сообщение.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
