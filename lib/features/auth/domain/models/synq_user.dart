enum PlanTier {
  free,
  pro;

  static PlanTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pro':
        return PlanTier.pro;
      case 'free':
      default:
        return PlanTier.free;
    }
  }

  String toJson() => name;
}

class SynqUser {
  final String id;
  final String email;
  final String name;
  final PlanTier planTier;
  final DateTime createdAt;

  const SynqUser({
    required this.id,
    required this.email,
    required this.name,
    required this.planTier,
    required this.createdAt,
  });

  SynqUser copyWith({
    String? id,
    String? email,
    String? name,
    PlanTier? planTier,
    DateTime? createdAt,
  }) {
    return SynqUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      planTier: planTier ?? this.planTier,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'plan_tier': planTier.toJson(), // Notice the snake_case for DB
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SynqUser.fromJson(Map<String, dynamic> json, String documentId) {
    return SynqUser(
      id: documentId,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      planTier: PlanTier.fromString(json['plan_tier'] as String? ?? 'free'),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }
}
