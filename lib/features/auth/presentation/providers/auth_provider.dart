import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';

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
      // Success is handled by stream listener
    } catch (e) {
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

  String _formatError(String error) {
    // Simple formatter to clean up Firebase exceptions
    if (error.contains('user-not-found')) return 'No user found for that email.';
    if (error.contains('wrong-password')) return 'Wrong password provided.';
    if (error.contains('email-already-in-use')) return 'Email is already in use.';
    if (error.contains('invalid-email')) return 'Invalid email address.';
    final parts = error.split(']');
    return parts.length > 1 ? parts[1].trim() : error;
  }
}
