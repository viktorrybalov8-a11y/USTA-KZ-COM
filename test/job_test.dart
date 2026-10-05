import 'package:flutter_test/flutter_test.dart';
import 'package:usta_kz/models/job.dart';

void main() {
  test('Job survives JSON round trip', () {
    final createdAt = DateTime.utc(2026, 10, 5, 4, 30);
    final job = Job(
      id: 'job-1',
      title: 'Монтаж кровли',
      category: 'Кровля',
      city: 'Петропавловск',
      phone: '+7 700 000 00 00',
      description: 'Нужна бригада для монтажа.',
      budget: 250000,
      createdAt: DateTime.utc(2026, 10, 5, 4, 30),
      ownerId: 'user-1',
      imageUrls: const ['https://example.test/job-1.jpg'],
    );

    final restored = Job.fromJson(job.toJson());

    expect(restored.id, 'job-1');
    expect(restored.title, 'Монтаж кровли');
    expect(restored.city, 'Петропавловск');
    expect(restored.budget, 250000);
    expect(restored.createdAt, createdAt);
    expect(restored.ownerId, 'user-1');
    expect(restored.imageUrls, ['https://example.test/job-1.jpg']);
    expect(restored.status, 'published');
  });

  test('old local orders still load without cloud fields', () {
    final restored = Job.fromJson({
      'id': 'old-job',
      'title': 'Ремонт кухни',
      'category': 'Отделка',
      'city': 'Астана',
      'phone': '+7 700 000 00 00',
      'description': 'Нужен мастер.',
      'budget': 0,
      'createdAt': '2026-10-01T00:00:00.000Z',
    });

    expect(restored.ownerId, isNull);
    expect(restored.imageUrls, isEmpty);
    expect(restored.status, 'published');
  });
}
