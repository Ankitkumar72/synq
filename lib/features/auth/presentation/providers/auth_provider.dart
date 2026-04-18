import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase_auth_repository.dart';
import '../../../notes/data/note_editor_draft_store.dart';

enum AuthStatus {
  uninitialized,
  anonymous,
  authenticated,
  transitioning,
}

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final AuthStatus status;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.error,
    this.status = AuthStatus.uninitialized,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    AuthStatus? status,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      status: status ?? this.status,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(SupabaseAuthRepository());
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseAuthRepository _repository;
  Timer? _debounceTimer;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen(
      (user) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (user != null) {
            state = state.copyWith(
              isAuthenticated: true,
              isLoading: false,
              error: null,
              status: AuthStatus.authenticated,
            );
            _handlePostLoginSideEffects(user);
          } else {
            state = state.copyWith(
              isAuthenticated: false,
              isLoading: false,
              status: AuthStatus.anonymous,
            );
          }
        });
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }


  void _handlePostLoginSideEffects(dynamic user) {
    _repository.createUserIfNeeded(
      uid: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String? ?? 'User',
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
        error: SupabaseAuthRepository.formatError(e.toString()),
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
        error: SupabaseAuthRepository.formatError(e.toString()),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.signInWithGoogle();

      if (!success) {
        if (!state.isAuthenticated) {
          state = state.copyWith(isLoading: false);
        }
      }
    } catch (e) {
      debugPrint('GOOGLE_SIGN_IN_ERROR: $e');
      state = state.copyWith(
        isLoading: false,
        error: SupabaseAuthRepository.formatError(e.toString()),
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

}