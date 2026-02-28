import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:synq/main.dart';
import 'package:synq/features/auth/presentation/providers/auth_provider.dart';
import 'package:synq/core/providers/firebase_provider.dart';

import 'package:synq/features/auth/data/auth_repository.dart';
import 'package:synq/features/notes/data/sync_access_provider.dart';
import 'package:synq/features/notes/data/notes_provider.dart';
import 'package:synq/features/notes/domain/models/note.dart';
import 'package:synq/features/timeline/data/timeline_provider.dart';
import 'package:synq/features/home/presentation/providers/current_focus_provider.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier() : super(MockAuthRepository()) {
    state = const AuthState(isLoading: false, isAuthenticated: true);
  }
}

class MockSyncAccessNotifier extends SyncAccessNotifier {
  MockSyncAccessNotifier() : super() {
    state = const SyncAccessState(cloudSyncEnabled: false, isLoading: false);
  }
}

class MockNotesNotifier extends NotesNotifier {
  @override
  Stream<List<Note>> build() {
    return Stream.value([]);
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame using ProviderScope overrides.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier()),
          syncAccessProvider.overrideWith((ref) => MockSyncAccessNotifier()),
          firebaseErrorProvider.overrideWith((ref) => null), // Mock successful initialization
          notesProvider.overrideWith(() => MockNotesNotifier()), // Mock empty notes
          // Override periodic-stream providers to prevent never-ending timers
          minuteProvider.overrideWith((ref) => Stream.value(0)),
          currentFocusProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const SynqApp(),
      ),
    );

    // Wait for animations
    await tester.pumpAndSettle();

    // Verify that our app header shows "Synq."
    expect(find.text('Synq.'), findsOneWidget);
  });
}
