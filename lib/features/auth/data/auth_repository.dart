import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp(String email, String password, {String? name}) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    if (name != null && credential.user != null) {
      await credential.user!.updateDisplayName(name);
      await credential.user!.reload();
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Not typically needed for Firebase (as state is handled via stream), but useful for snapshots
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  String? get userName => _firebaseAuth.currentUser?.displayName;
  String? get userEmail => _firebaseAuth.currentUser?.email;
}
