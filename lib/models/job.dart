class Job {
  const Job({
    required this.id,
    required this.title,
    required this.category,
    required this.city,
    required this.phone,
    required this.description,
    required this.budget,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String city;
  final String phone;
  final String description;
  final int budget;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'city': city,
        'phone': phone,
        'description': description,
        'budget': budget,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Job.fromJson(Map<String, Object?> json) => Job(
        id: json['id']! as String,
        title: json['title']! as String,
        category: json['category']! as String,
        city: json['city']! as String,
        phone: json['phone']! as String,
        description: json['description']! as String,
        budget: json['budget']! as int,
        createdAt: DateTime.parse(json['createdAt']! as String),
      );
}
