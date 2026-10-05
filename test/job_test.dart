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
    );

    final restored = Job.fromJson(job.toJson());

    expect(restored.id, 'job-1');
    expect(restored.title, 'Монтаж кровли');
    expect(restored.city, 'Петропавловск');
    expect(restored.budget, 250000);
    expect(restored.createdAt, createdAt);
  });
}
