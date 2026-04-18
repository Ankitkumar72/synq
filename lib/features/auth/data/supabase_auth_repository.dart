import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../../../core/database/local_database.dart';
import '../../../core/services/supabase_service.dart';


/// Supabase-backed auth repository — replaces [AuthRepository] (Firebase).
///
/// Supports:
///   - Email/password sign-up and sign-in
///   - Google OAuth via Supabase (uses native Google Sign-In flow)
///   - Password reset via magic link
///   - Auth state change stream for Riverpod
///
/// Migration notes:
///   - Firebase UID → Supabase UUID: the user ID format changes.
///     If you have a local SQLite DB keyed by Firebase UID, you'll need
///     a one-time migration to re-key it.
///   - Google Sign-In: Supabase handles OAuth natively; no need for
///     the `google_sign_in` package or `GoogleAuthProvider.credential()`.
///
/// TODO(migration):
///   - [ ] Configure Google OAuth in Supabase Dashboard → Authentication → Providers
///   - [ ] Update .env with SUPABASE_URL and SUPABASE_ANON_KEY
///   - [ ] Replace Firebase Auth calls in auth_provider.dart
class SupabaseAuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Auth State
  // ---------------------------------------------------------------------------

  /// Stream of auth state changes (equivalent to Firebase's authStateChanges).
  ///
  /// Emits the current [User] when signed in, or `null` when signed out.
  Stream<User?> get authStateChanges => _client.auth.onAuthStateChange.map(
        (event) => event.session?.user,
      );

  /// The currently signed-in user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// Current session, if any.
  Session? get currentSession => _client.auth.currentSession;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Display name of the current user.
  String? get userName =>
      currentUser?.userMetadata?['full_name'] as String? ??
      currentUser?.userMetadata?['name'] as String?;

  /// Email of the current user.
  String? get userEmail => currentUser?.email;

  // ---------------------------------------------------------------------------
  // Email/Password Auth
  // ---------------------------------------------------------------------------

  /// Signs in with email and password.
  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await _ensureProfileExists(response.user!);
    }

    return response;
  }

  /// Creates a new account with email and password.
  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? name,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: name != null ? {'full_name': name} : null,
    );

    if (response.user != null) {
      await _ensureProfileExists(response.user!, name: name);
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // Google OAuth
  // ---------------------------------------------------------------------------

  /// Signs in with Google using native Google Sign-In and Supabase.
  Future<bool> signInWithGoogle() async {
    try {
      final webClientId = dotenv.get('GOOGLE_WEB_CLIENT_ID');
      
      // On iOS, the Google SDK requires the iOS-specific Client ID
      // On Android, it's generally picked up from google-services.json
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.authenticate();
      
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user != null) {
        await _ensureProfileExists(response.user!);
      }

      return true;
    } on AuthApiException catch (e) {
      if (e.code == 'provider_disabled') {
        debugPrint('SUPABASE_AUTH_ERROR: Google provider is not enabled in Supabase Dashboard.');
      }
      rethrow;
    } catch (e) {
      debugPrint('NATIVE_GOOGLE_SIGN_IN_ERROR: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Password Reset
  // ---------------------------------------------------------------------------

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  /// Signs out the current user and releases the local database.
  Future<void> signOut() async {
    final uid = currentUser?.id;
    await _client.auth.signOut();

    if (uid != null) {
      await LocalDatabase.releaseDatabase(uid);
    }
  }

  // ---------------------------------------------------------------------------
  // Profile Management
  // ---------------------------------------------------------------------------

  /// Creates a user profile row in Supabase if it doesn't exist.
  ///
  /// This replaces the Firestore-based [UserRepository.createUserIfNeeded].
  /// The profile is stored in a `profiles` table in public schema.
  Future<void> _ensureProfileExists(User user, {String? name}) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        // New user — create profile
        await _client.from('profiles').insert({
          'id': user.id,
          'email': user.email ?? '',
          'name': name ??
              user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              'User',
          'plan_tier': 'free',
          'is_admin': false,
          'storage_used_bytes': 0,
          'active_devices': '[]',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Existing user — update non-privileged fields
        await _client.from('profiles').update({
          'email': user.email ?? '',
          'name': name ??
              user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              'User',
        }).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('PROFILE_ENSURE_ERROR: $e');
      // Non-fatal: user can still use the app with auth alone
    }
  }

  /// Exposes profile creation for self-healing flows.
  Future<void> createUserIfNeeded({
    required String uid,
    required String email,
    required String name,
  }) async {
    final user = currentUser;
    if (user != null) {
      await _ensureProfileExists(user, name: name);
    }
  }

  // ---------------------------------------------------------------------------
  // Error Formatting
  // ---------------------------------------------------------------------------

  /// Formats Supabase auth errors into user-friendly messages.
  static String formatError(String error) {
    final lower = error.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'This email is already linked to an account.';
    }
    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('password')) {
      return 'Password is too weak. Try a longer one.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Network error. Check your connection.';
    }
    if (lower.contains('provider') && lower.contains('not enabled')) {
      return 'Google Sign-In is temporarily unavailable (Provider Disabled).';
    }

    return 'Authentication failed. Please try again.';
  }
}
