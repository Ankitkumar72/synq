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
  final List<Map<String, dynamic>> activeDevices;
  final List<String> activeDeviceIds;
  final int storageUsedBytes;
  final bool isOverLimit;

  const SynqUser({
    required this.id,
    required this.email,
    required this.name,
    required this.planTier,
    required this.createdAt,
    this.activeDevices = const [],
    this.activeDeviceIds = const [],
    this.storageUsedBytes = 0,
    this.isOverLimit = false,
  });

  SynqUser copyWith({
    String? id,
    String? email,
    String? name,
    PlanTier? planTier,
    DateTime? createdAt,
    List<Map<String, dynamic>>? activeDevices,
    List<String>? activeDeviceIds,
    int? storageUsedBytes,
    bool? isOverLimit,
  }) {
    return SynqUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      planTier: planTier ?? this.planTier,
      createdAt: createdAt ?? this.createdAt,
      activeDevices: activeDevices ?? this.activeDevices,
      activeDeviceIds: activeDeviceIds ?? this.activeDeviceIds,
      storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
      isOverLimit: isOverLimit ?? this.isOverLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'plan_tier': planTier.toJson(),
      'created_at': createdAt.toIso8601String(),
      'active_devices': activeDevices,
      'active_device_ids': activeDeviceIds,
      'storage_used_bytes': storageUsedBytes,
      'is_over_limit': isOverLimit,
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
      activeDevices:
          (json['active_devices'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      activeDeviceIds:
          (json['active_device_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      storageUsedBytes: json['storage_used_bytes'] as int? ?? 0,
      isOverLimit: json['is_over_limit'] as bool? ?? false,
    );
  }
}
