import '../domain/models/synq_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Creates a new user document if it doesn't already exist.
  /// Defaults plan_tier to "free".
  Future<void> createUserIfNeeded({
    required String uid,
    required String email,
    required String name,
  }) async {
    final docRef = _usersCollection.doc(uid);
    // Explicitly set the core fields required by security rules with merge: true
    // This handles both new users and "phantom" users with missing fields.
    await docRef.set({
      'id': uid,
      'email': email,
      'name': name,
      'plan_tier': 'free',
      'storage_used_bytes': 0,
      'active_device_ids': FieldValue.arrayUnion([]), // Ensure it's an array if missing
      'created_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Adds a device to the user's active devices list if it doesn't exist.
  Future<void> registerDevice(
    String uid,
    String deviceId,
    String deviceName,
  ) async {
    final docRef = _usersCollection.doc(uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final user = SynqUser.fromJson(snapshot.data()!, snapshot.id);
      final exists = user.activeDevices.any((d) => d['id'] == deviceId);

      if (!exists) {
        final updatedDevices = List<Map<String, dynamic>>.from(
          user.activeDevices,
        );
        updatedDevices.add({
          'id': deviceId,
          'name': deviceName,
          'last_seen': DateTime.now().toIso8601String(),
        });

        await docRef.update({
          'active_devices': updatedDevices,
          'active_device_ids': FieldValue.arrayUnion([deviceId]),
        });

      } else {
        // Update last_seen for existing device
        final updatedDevices = user.activeDevices.map((d) {
          if (d['id'] == deviceId) {
            return {...d, 'last_seen': DateTime.now().toIso8601String()};
          }
          return d;
        }).toList();
        await docRef.update({'active_devices': updatedDevices});
      }
    }
  }

  /// Removes a device from the user's active devices list.
  Future<void> unregisterDevice(String uid, String deviceId) async {
    final docRef = _usersCollection.doc(uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final user = SynqUser.fromJson(snapshot.data()!, snapshot.id);
      final updatedDevices = user.activeDevices
          .where((d) => d['id'] != deviceId)
          .toList();
      await docRef.update({
        'active_devices': updatedDevices,
        'active_device_ids': FieldValue.arrayRemove([deviceId]),
      });
    }
  }

  /// Checks if the current device is allowed based on the user's plan and active devices.
  Future<bool> isDeviceAllowed(String uid, String currentDeviceId) async {
    final docRef = _usersCollection.doc(uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final user = SynqUser.fromJson(snapshot.data()!, snapshot.id);

      // If device is already registered, it's allowed
      if (user.activeDevices.any((d) => d['id'] == currentDeviceId)) {
        return true;
      }

      // If not registered, check limit
      final limit = user.planTier == PlanTier.pro ? 999 : 1;
      return user.activeDevices.length < limit;
    }
    return true; // Default to true if user not found (shouldn't happen)
  }

  /// Streams the user document for real-time plan logic.
  Stream<SynqUser?> watchUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return SynqUser.fromJson(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }
}
