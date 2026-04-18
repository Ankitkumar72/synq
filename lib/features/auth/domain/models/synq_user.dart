import 'dart:convert';
import 'package:collection/collection.dart';

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

extension PlanTierX on PlanTier {
  bool get isPro => this == PlanTier.pro;
  bool get isFree => this == PlanTier.free;
}

class SynqUser {
  final String id;
  final String email;
  final String name;
  final PlanTier planTier;
  final bool isAdmin;
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
    this.isAdmin = false,
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
    bool? isAdmin,
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
      isAdmin: isAdmin ?? this.isAdmin,
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
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'active_devices': activeDevices,
      'storage_used_bytes': storageUsedBytes,
      'is_over_limit': isOverLimit,
    };
  }

  factory SynqUser.fromJson(Map<String, dynamic> json, String documentId) {
    List<dynamic> parseList(dynamic value) {
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
      if (value is List) return value;
      return [];
    }

    final activeDevicesList = parseList(json['active_devices']);

    // Derive device IDs from the JSONB active_devices array
    final derivedDeviceIds = activeDevicesList
        .where((e) => e is Map && e['id'] != null)
        .map((e) => (e as Map)['id'].toString())
        .toList();

    return SynqUser(
      id: documentId,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      planTier: PlanTier.fromString(json['plan_tier'] as String? ?? 'free'),
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      activeDevices: activeDevicesList
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList(),
      activeDeviceIds: derivedDeviceIds,
      storageUsedBytes: json['storage_used_bytes'] as int? ?? 0,
      isOverLimit: json['is_over_limit'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SynqUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          planTier == other.planTier &&
          isAdmin == other.isAdmin &&
          createdAt == other.createdAt &&
          const ListEquality().equals(activeDevices, other.activeDevices) &&
          const ListEquality().equals(activeDeviceIds, other.activeDeviceIds) &&
          storageUsedBytes == other.storageUsedBytes &&
          isOverLimit == other.isOverLimit;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      name.hashCode ^
      planTier.hashCode ^
      isAdmin.hashCode ^
      createdAt.hashCode ^
      const ListEquality().hash(activeDevices) ^
      const ListEquality().hash(activeDeviceIds) ^
      storageUsedBytes.hashCode ^
      isOverLimit.hashCode;
}

