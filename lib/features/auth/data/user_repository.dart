import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/synq_user.dart';

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
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      final newUser = SynqUser(
        id: uid,
        email: email,
        name: name,
        planTier: PlanTier.free,
        createdAt: DateTime.now(),
      );
      
      await docRef.set(newUser.toJson(), SetOptions(merge: true));
    }
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
