import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job.dart';

class JobRepository extends ChangeNotifier {
  JobRepository._();
  static final instance = JobRepository._();

  static const _storageKey = 'usta.jobs.v1';
  final List<Job> _jobs = [];
  bool _ready = false;
  FirebaseFirestore? _firestore;
  String? _cloudUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _error;

  List<Job> get jobs => List.unmodifiable(_jobs);
  bool get isCloudMode => _firestore != null;
  bool get isSignedIn => _cloudUserId != null;
  String? get currentUserId => _cloudUserId;
  String? get error => _error;

  Future<void> initialize() async {
    if (_ready) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _jobs
          ..clear()
          ..addAll(decoded.map((item) =>
              Job.fromJson(Map<String, Object?>.from(item as Map))));
      } on FormatException {
        await preferences.remove(_storageKey);
      } on TypeError {
        await preferences.remove(_storageKey);
      }
    }
    _ready = true;
  }

  Future<void> connectCloud({
    required FirebaseFirestore firestore,
    required String? userId,
  }) async {
    if (identical(_firestore, firestore) && _cloudUserId == userId) return;
    await _subscription?.cancel();
    _firestore = firestore;
    _cloudUserId = userId;
    _error = null;
    _jobs.clear();
    if (userId != null) {
      _subscription = firestore
          .collection('jobs')
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .listen((snapshot) {
        _jobs
          ..clear()
          ..addAll(snapshot.docs.map(_jobFromDocument));
        _error = null;
        notifyListeners();
      }, onError: (Object error) {
        _error = 'Не удалось загрузить общие заказы. Проверьте настройки базы.';
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> disconnectCloud() async {
    await _subscription?.cancel();
    _subscription = null;
    _firestore = null;
    _cloudUserId = null;
    _error = null;
    await initialize();
    notifyListeners();
  }

  Future<void> add(Job job) async {
    final firestore = _firestore;
    final userId = _cloudUserId;
    if (firestore != null) {
      if (userId == null) throw StateError('Войдите в аккаунт, чтобы создать заказ.');
      await firestore.collection('jobs').doc(job.id).set({
        ...job.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'ownerId': userId,
        'status': 'published',
      });
      return;
    }
    _jobs.insert(0, job);
    await _persist();
  }

  Future<void> remove(String id) async {
    final firestore = _firestore;
    final userId = _cloudUserId;
    if (firestore != null) {
      if (userId == null) throw StateError('Войдите в аккаунт.');
      await firestore.collection('jobs').doc(id).delete();
      return;
    }
    _jobs.removeWhere((job) => job.id == id);
    await _persist();
  }

  Job _jobFromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final createdAt = data['createdAt'];
    final date = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();
    return Job(
      id: document.id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'Другое',
      city: data['city'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      description: data['description'] as String? ?? '',
      budget: data['budget'] as int? ?? 0,
      createdAt: date,
      ownerId: data['ownerId'] as String?,
      imageUrls: (data['imageUrls'] as List<dynamic>? ?? const []).cast<String>(),
      status: data['status'] as String? ?? 'published',
    );
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_jobs.map((job) => job.toJson()).toList()),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
