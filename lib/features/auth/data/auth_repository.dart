import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Future<void> signInWithGoogle() async {
    // 1. Initialize Google Sign-In (required for v7.x)
    await GoogleSignIn.instance.initialize();
    
    // 2. Trigger the authentication flow
    final authResult = await GoogleSignIn.instance.authenticate();

    // 3. Get authorization with required scopes for Firebase
    final authorization = await GoogleSignIn.instance.authorizationClient.authorizeScopes(
      ['email', 'profile'],
    );

    // 4. Create a new credential using the tokens
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: authResult.authentication.idToken,
    );

    // 5. Sign in to Firebase with the new credential
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
      GoogleSignIn.instance.disconnect(),
    ]);
  }

  // Not typically needed for Firebase (as state is handled via stream), but useful for snapshots
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  String? get userName => _firebaseAuth.currentUser?.displayName;
  String? get userEmail => _firebaseAuth.currentUser?.email;
}

