import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job.dart';

class JobRepository extends ChangeNotifier {
  JobRepository._();
  static final instance = JobRepository._();

  static const _storageKey = 'usta.jobs.v1';
  final List<Job> _jobs = [];
  bool _ready = false;

  List<Job> get jobs => List.unmodifiable(_jobs);

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

  Future<void> add(Job job) async {
    _jobs.insert(0, job);
    await _persist();
  }

  Future<void> remove(String id) async {
    _jobs.removeWhere((job) => job.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_jobs.map((job) => job.toJson()).toList()),
    );
    notifyListeners();
  }
}
