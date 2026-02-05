import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart' as google;

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final google.GoogleSignIn _googleSignIn = google.GoogleSignIn();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    // 1. Trigger the authentication flow
    final google.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      // User canceled the sign-in
      return;
    }

    // 2. Obtain the auth details from the request
    final google.GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // 3. Create a new credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase with the new credential
    await _firebaseAuth.signInWithCredential(credential);
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
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Not typically needed for Firebase (as state is handled via stream), but useful for snapshots
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  String? get userName => _firebaseAuth.currentUser?.displayName;
  String? get userEmail => _firebaseAuth.currentUser?.email;
}
