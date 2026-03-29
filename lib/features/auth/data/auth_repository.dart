import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_repository.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Ensure user document exists (fixes "phantom user" problem)
    if (credential.user != null) {
      await _userRepository.createUserIfNeeded(
        uid: credential.user!.uid,
        email: email,
        name: credential.user!.displayName ?? 'User',
      );
    }
  }

  /// Exposes user creation to the auth provider for self-healing
  Future<void> createUserIfNeeded({
    required String uid,
    required String email,
    required String name,
  }) async {
    await _userRepository.createUserIfNeeded(
      uid: uid,
      email: email,
      name: name,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    // 1. Initialize GoogleSignIn (required once per app lifecycle in v7.x)
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '474773003470-ip0dv62bdn1iiqfhsrfhjkp3s7oqf1vu.apps.googleusercontent.com',
      );
      _googleSignInInitialized = true;
    }

    // 2. Trigger the authentication flow (replaces signIn() in v7.x)
    final googleUser = await GoogleSignIn.instance.authenticate();

    // 4. Obtain the auth details (synchronous in v7.x)
    final GoogleSignInAuthentication auth = googleUser.authentication;

    // 5. Create a new credential using the tokens
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );

    // 6. Sign in to Firebase with the new credential
    final credentialResult = await _firebaseAuth.signInWithCredential(
      credential,
    );

    if (credentialResult.user != null) {
      await _userRepository.createUserIfNeeded(
        uid: credentialResult.user!.uid,
        email: googleUser.email,
        name: googleUser.displayName ?? 'User',
      );
    }

    return credentialResult;
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

    if (credential.user != null) {
      await _userRepository.createUserIfNeeded(
        uid: credential.user!.uid,
        email: email,
        name: name ?? 'User',
      );
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      GoogleSignIn.instance.disconnect(),
    ]);
  }

  /// Sends a password reset email to the specified email address
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // Not typically needed for Firebase (as state is handled via stream), but useful for snapshots
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  String? get userName => _firebaseAuth.currentUser?.displayName;
  String? get userEmail => _firebaseAuth.currentUser?.email;
}
