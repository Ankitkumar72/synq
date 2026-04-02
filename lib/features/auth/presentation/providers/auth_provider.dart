import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../../notes/data/note_editor_draft_store.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.error,
  });

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRepository());
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen(
      (user) {
        if (user != null) {
          state = state.copyWith(
            isAuthenticated: true, 
            isLoading: false, 
            error: null,
          );
          _handlePostLoginSideEffects(user);
        } else {
          state = state.copyWith(isAuthenticated: false, isLoading: false);
        }
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }

  void _handlePostLoginSideEffects(dynamic user) {
    _repository.createUserIfNeeded(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'User',
    ).catchError((e) {
      debugPrint('USER_INITIALIZATION_ERROR: $e');
    });
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signIn(email, password);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e.toString()),
      );
    }
  }

  Future<void> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signUp(email, password, name: name);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e.toString()),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userCredential = await _repository.signInWithGoogle();

      if (userCredential == null || userCredential.user == null) {
        if (!state.isAuthenticated) {
          state = state.copyWith(isLoading: false);
        }
      }
    } catch (e) {
      debugPrint('GOOGLE_SIGN_IN_ERROR: $e');
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e.toString()),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      NoteEditorDraftStore.clearAll();
      await _repository.signOut();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

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
    if (error.contains('user-not-found')) {
      return 'Account not found. Please sign up first.';
    }
    if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
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
    if (error.contains('dev.flutter.pigeon') ||
        error.contains('channel-error')) {
      return 'Please enter the details correctly.';
    }

    final parts = error.split(']');
    return parts.length > 1
        ? parts[1].trim()
        : 'Authentication failed. Please try again.';
  }
}