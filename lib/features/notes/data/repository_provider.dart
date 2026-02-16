import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import 'firebase_sync_coordinator.dart';
import 'folders_repository.dart';
import 'local_database.dart';
import 'local_db_folders_repository.dart';
import 'local_db_notes_repository.dart';
import 'notes_repository.dart';
import 'sync_access_provider.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.dispose);
  return database;
});

final localDbNotesRepositoryProvider = Provider<LocalDbNotesRepository>((ref) {
  final database = ref.watch(localDatabaseProvider);
  return LocalDbNotesRepository(database);
});

final localDbFoldersRepositoryProvider = Provider<LocalDbFoldersRepository>((ref) {
  final database = ref.watch(localDatabaseProvider);
  return LocalDbFoldersRepository(database);
});

final useCloudSyncProvider = Provider<bool>((ref) {
  final syncAccess = ref.watch(syncAccessProvider);
  final authState = ref.watch(authProvider);
  final user = FirebaseAuth.instance.currentUser;

  return syncAccess.cloudSyncEnabled &&
      authState.isAuthenticated &&
      user != null;
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

final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  return ref.watch(localDbFoldersRepositoryProvider);
});
