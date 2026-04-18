import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/synq_user.dart';

/// Supabase-backed user repository — replaces [UserRepository] (Firestore).
///
/// Reads from and writes to the `profiles` table in Supabase Postgres.
/// Row Level Security (RLS) ensures users can only access their own profile.
///
/// Table schema (see supabase/migrations/001_core_tables.sql):
/// ```sql
/// CREATE TABLE public.profiles (
///   id          UUID    PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
///   email       TEXT    NOT NULL DEFAULT '',
///   name        TEXT    NOT NULL DEFAULT 'User',
///   plan_tier   TEXT    NOT NULL DEFAULT 'free',
///   is_admin    BOOLEAN NOT NULL DEFAULT false,
///   storage_used_bytes  INTEGER NOT NULL DEFAULT 0,
///   active_devices      JSONB   NOT NULL DEFAULT '[]',
///   created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
/// );
/// ```
class SupabaseUserRepository {
  SupabaseUserRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const String _table = 'profiles';

  List<dynamic> _parseList(dynamic value) {
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    if (value is List) return value;
    return [];
  }

  // ---------------------------------------------------------------------------
  // Profile Creation
  // ---------------------------------------------------------------------------

  /// Creates or updates the user profile.
  ///
  /// Equivalent to the old Firestore `createUserIfNeeded`.
  Future<void> createUserIfNeeded({
    required String uid,
    required String email,
    required String name,
  }) async {
    try {
      final existing = await _client
          .from(_table)
          .select('id')
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        await _client.from(_table).insert({
          'id': uid,
          'email': email,
          'name': name,
          'plan_tier': 'free',
          'is_admin': false,
          'storage_used_bytes': 0,
          'active_devices': <Map<String, dynamic>>[],
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _client.from(_table).update({
          'email': email,
          'name': name,
        }).eq('id', uid);
      }
    } catch (e) {
      debugPrint('SUPABASE_USER_CREATE_ERROR: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Device Management
  // ---------------------------------------------------------------------------

  /// Registers a device in the user's active devices list.
  Future<void> registerDevice(
    String uid,
    String deviceId,
    String deviceName,
  ) async {
    try {
      final row = await _client
          .from(_table)
          .select('active_devices')
          .eq('id', uid)
          .single();

      final devicesList = _parseList(row['active_devices']);

      final devices = List<Map<String, dynamic>>.from(
        devicesList.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      );

      final exists = devices.any((d) => d['id'] == deviceId);

      if (!exists) {
        devices.add({
          'id': deviceId,
          'name': deviceName,
          'last_seen': DateTime.now().toIso8601String(),
        });
      } else {
        // Update last_seen for existing device
        for (int i = 0; i < devices.length; i++) {
          if (devices[i]['id'] == deviceId) {
            devices[i] = {
              ...devices[i],
              'last_seen': DateTime.now().toIso8601String(),
            };
          }
        }
      }

      await _client.from(_table).update({
        'active_devices': devices,
      }).eq('id', uid);
    } catch (e) {
      debugPrint('DEVICE_REGISTER_ERROR: $e');
    }
  }

  /// Removes a device from the user's active devices list.
  Future<void> unregisterDevice(String uid, String deviceId) async {
    try {
      final row = await _client
          .from(_table)
          .select('active_devices')
          .eq('id', uid)
          .single();

      final devicesList = _parseList(row['active_devices']);

      final devices = List<Map<String, dynamic>>.from(
        devicesList.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      );

      devices.removeWhere((d) => d['id'] == deviceId);

      await _client.from(_table).update({
        'active_devices': devices,
      }).eq('id', uid);
    } catch (e) {
      debugPrint('DEVICE_UNREGISTER_ERROR: $e');
    }
  }

  /// Checks if the current device is allowed based on plan limits.
  Future<bool> isDeviceAllowed(String uid, String currentDeviceId) async {
    try {
      final row = await _client
          .from(_table)
          .select('active_devices, plan_tier')
          .eq('id', uid)
          .single();

      final devicesList = _parseList(row['active_devices']);

      final devices = List<Map<String, dynamic>>.from(
        devicesList.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      );
      final planTier = PlanTier.fromString(row['plan_tier'] as String? ?? 'free');

      // If device is already registered, it's allowed
      if (devices.any((d) => d['id'] == currentDeviceId)) return true;

      // Check limit
      final limit = planTier == PlanTier.pro ? 999 : 1;
      return devices.length < limit;
    } catch (e) {
      debugPrint('DEVICE_CHECK_ERROR: $e');
      return true; // Default to allowing
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime Profile Streaming
  // ---------------------------------------------------------------------------

  /// Streams the user profile for realtime plan/device logic.
  ///
  /// Uses Supabase Realtime to listen for changes to the profiles table.
  Stream<SynqUser?> watchUser(String uid) {
    // Initial fetch + realtime subscription
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) {
      if (rows.isEmpty) return null;
      return SynqUser.fromJson(rows.first, uid);
    });
  }
}
