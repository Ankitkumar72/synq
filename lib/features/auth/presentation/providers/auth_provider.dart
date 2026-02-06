import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../../notes/data/seed_notes.dart';

// State to hold preventing duplicate loading
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRepository());
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen((user) {
      if (user != null) {
        state = state.copyWith(isAuthenticated: true, isLoading: false);
      } else {
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    }, onError: (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    });
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signIn(email, password);
      // Success is handled by stream listener
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e.toString()));
    }
  }

  Future<void> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signUp(email, password, name: name);
      // Success is handled by stream listener (authStateChanges will fire)
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userCredential = await _repository.signInWithGoogle();
      
      if (userCredential != null && userCredential.user != null) {
        // Seed sample data for new users
        await SeedNotesService.seedIfEmpty(userCredential.user!.uid);
      }

      // user cancelation returns null but doesn't throw, 
      // success will trigger stream.
      // If we are still here and loading is true, we might want to unset it
      // but stream updates happen fast.
      // If user cancels, we need to reset loading.
      // However, repository method returns void.
      // Implementing a small delay/check or just resetting loading if not authed?
      // Actually, if repository returns without throwing, and stream fires, we are good.
      // If repository returns without throwing because of cancel, stream won't fire.
      // So we should reset loading state here.
      if (!state.isAuthenticated) {
         state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('GOOGLE_SIGN_IN_ERROR: $e'); // Added logging
      state = state.copyWith(isLoading: false, error: _formatError(e.toString()));
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
       await _repository.signOut();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sends a password reset email. Returns true on success, false on failure.
  Future<bool> resetPassword(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      debugPrint('PASSWORD_RESET_ERROR: $e');
      return false;
    }
  }

  String _formatError(String error) {
    // Better error messages
    if (error.contains('user-not-found')) {
      return 'Account not found. Please sign up first.';
    }
    if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (error.contains('email-already-in-use')) {
      return 'This email is already linked to an account.';
    }
    if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (error.contains('weak-password')) {
      return 'Password is too weak. Try a longer one.';
    }
    if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    }
    if (error.contains('dev.flutter.pigeon') || error.contains('channel-error')) {
      return 'Please enter the details correctly.';
    }
    
    // Fallback: clean up the detailed technical message
    // e.g. "[firebase_auth/unknown] An unknown error occurred."
    final parts = error.split(']');
    return parts.length > 1 ? parts[1].trim() : 'Authentication failed. Please try again.'; // Generic fallback
  }
}
