import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/user_provider.dart';
import '../../auth/domain/models/synq_user.dart';
import 'firebase_sync_coordinator.dart';
import 'folders_repository.dart';
import 'local_database.dart';
import 'local_db_folders_repository.dart';
import 'local_db_notes_repository.dart';
import 'notes_repository.dart';
import 'sync_access_provider.dart';

final _currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (!authState.isAuthenticated || user == null) {
    return '_anonymous';
  }
  return user.uid;
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

final localDbFoldersRepositoryProvider = Provider<LocalDbFoldersRepository>((ref) {
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

final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  return ref.watch(localDbFoldersRepositoryProvider);
});
