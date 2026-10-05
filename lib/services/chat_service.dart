import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Войдите, чтобы пользоваться сообщениями.');
    return uid;
  }

  Future<String> openConversation(String otherUserId) async {
    final uid = _uid;
    if (uid == otherUserId) throw ArgumentError('Нельзя открыть чат с собой.');
    final participants = [uid, otherUserId]..sort();
    final id = base64Url.encode(utf8.encode(participants.join(':'))).replaceAll('=', '');
    final reference = _firestore.collection('conversations').doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.set(reference, {
          'participants': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
        });
      }
    });
    return id;
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final value = text.trim();
    if (value.isEmpty || value.length > 2000) {
      throw ArgumentError('Сообщение должно содержать от 1 до 2000 символов.');
    }
    final uid = _uid;
    final conversation = _firestore.collection('conversations').doc(conversationId);
    final batch = _firestore.batch();
    batch.set(conversation.collection('messages').doc(), {
      'senderId': uid,
      'text': value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversation, {
      'lastMessage': value,
      'lastSenderId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
