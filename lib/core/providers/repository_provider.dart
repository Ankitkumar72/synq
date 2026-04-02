import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/user_provider.dart';
import '../../features/auth/domain/models/synq_user.dart';
import '../../features/sync/data/firebase_sync_coordinator.dart';
import '../../features/folders/data/folders_repository.dart';
import '../database/local_database.dart';
import '../../features/folders/data/local_db_folders_repository.dart';
import '../../features/notes/data/local_db_notes_repository.dart';
import '../../features/tasks/data/local_db_tasks_repository.dart';
import '../../features/notes/data/notes_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/analytics/data/activity_repository.dart';
import '../../features/notes/data/seed_notes.dart';
import '../../features/analytics/data/local_db_activity_repository.dart';
import '../../features/sync/data/sync_access_provider.dart';

final _currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (!authState.isAuthenticated || user == null) {
    return '_anonymous';
  }
  return user.uid;
});

final appInitializationProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Run initializations without returning a future to avoid blocking
  () async {
    try {
      await LocalDatabase.deleteStaleDbFiles(user.uid);
    } catch (e) {
      debugPrint('STALE_DB_CLEANUP_ERROR: $e');
    }
  }();

  () async {
    try {
      final db = ref.read(localDatabaseProvider);
      await SeedNotesService.seedIfEmpty(db);
    } catch (e) {
      debugPrint('SEED_NOTES_ERROR: $e');
    }
  }();
});

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final userId = ref.watch(_currentUserIdProvider);
  final database = LocalDatabase(userId);
  ref.onDispose(database.dispose);
  return database;
});

final localDbNotesRepositoryProvider = Provider<LocalDbNotesRepository>((ref) {
  final database = ref.watch(localDatabaseProvider);
  return LocalDbNotesRepository(database);
});

final localDbTasksRepositoryProvider = Provider<LocalDbTasksRepository>((ref) {
  final database = ref.watch(localDatabaseProvider);
  return LocalDbTasksRepository(database);
});

final localDbActivityRepositoryProvider = Provider<LocalDbActivityRepository>((ref) {
  final database = ref.watch(localDatabaseProvider);
  return LocalDbActivityRepository(database);
});

final localDbFoldersRepositoryProvider = Provider<LocalDbFoldersRepository>((
  ref,
) {
  final database = ref.watch(localDatabaseProvider);
  return LocalDbFoldersRepository(database);
});

final useCloudSyncProvider = Provider<bool>((ref) {
  final syncAccess = ref.watch(syncAccessProvider);
  final authState = ref.watch(authProvider);
  final userAsync = ref.watch(userProvider);
  final user = FirebaseAuth.instance.currentUser;

  final isPro = userAsync.valueOrNull?.planTier == PlanTier.pro;

  return syncAccess.cloudSyncEnabled &&
      authState.isAuthenticated &&
      user != null &&
      isPro;
});

final syncCoordinatorProvider = Provider<FirebaseSyncCoordinator?>((ref) {
  final useCloudSync = ref.watch(useCloudSyncProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (!useCloudSync || user == null) {
    return null;
  }

  final coordinator = FirebaseSyncCoordinator(
    firestore: FirebaseFirestore.instance,
    userId: user.uid,
    database: ref.watch(localDatabaseProvider),
  );
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return ref.watch(localDbNotesRepositoryProvider);
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return ref.watch(localDbTasksRepositoryProvider);
});

final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  return ref.watch(localDbFoldersRepositoryProvider);
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ref.watch(localDbActivityRepositoryProvider);
});
