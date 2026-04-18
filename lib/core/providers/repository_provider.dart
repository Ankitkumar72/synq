import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/user_provider.dart';
import '../../features/auth/domain/models/synq_user.dart';
import '../../features/sync/data/supabase_sync_engine.dart';
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
import '../../core/services/device_service.dart';
import '../../features/notes/data/trash_provider.dart';

final deviceIdProvider = FutureProvider<String>((ref) async {
  final deviceService = DeviceService();
  final info = await deviceService.getDeviceInfo();
  return info['id'] ?? 'device_unknown';
});

final databaseTransitionProvider = StateProvider<bool>((ref) => false);

final _currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  final user = Supabase.instance.client.auth.currentUser;
  
  if (authState.status == AuthStatus.uninitialized) return '_anonymous';
  if (authState.status == AuthStatus.anonymous || user == null) return '_anonymous';
  
  return user.id;
});

final appInitializationProvider = Provider<void>((ref) {
  // Watch syncCoordinatorProvider here to keep it alive and active
  // without rebuilding view providers when sync status changes.
  ref.watch(syncCoordinatorProvider);
  
  // Trigger cleanup of expired deleted items
  Future.microtask(() => ref.read(trashProvider.notifier).cleanExpiredNotes());
  
  // We use a listen to orchestrate the transition when the userId changes

  ref.listen<String>(_currentUserIdProvider, (previous, next) async {
    if (previous == next) return;
    
    // Step 1: Set transitioning flag
    ref.read(databaseTransitionProvider.notifier).state = true;
    
    try {
      debugPrint('DB_TRANSITION_START: $previous -> $next');
      
      // Step 2 & 3: Cancel streams & Await in-flight ops
      // Handled by ref.dispose() of the repositories and LocalDatabase.dispose()
      
      // Step 4 & 5: Await database.close() and clear cache
      await LocalDatabase.waitForAllToClose();
      
      // Step 6 & 7: Delete stale files / anonymous DB
      if (next != '_anonymous') {
        await LocalDatabase.deleteStaleDbFiles(next);
      }
      
      debugPrint('DB_TRANSITION_CLEANUP_COMPLETE');
    } catch (e) {
      debugPrint('DB_TRANSITION_ERROR: $e');
    } finally {
      // Step 9: Set transitioning flag to false
      ref.read(databaseTransitionProvider.notifier).state = false;
      debugPrint('DB_TRANSITION_READY');
    }

    // Step 10: Seed the new database AFTER the transition is fully complete.
    // The localDatabaseProvider already rebuilt when _currentUserIdProvider
    // changed, so ref.read gives us the fresh DB for the new user.
    // The old seed listener was being skipped because the transition flag
    // was still true when localDatabaseProvider's listener fired.
    try {
      final db = ref.read(localDatabaseProvider);
      await SeedNotesService.seedIfEmpty(db);
      debugPrint('SEED_POST_TRANSITION: completed for $next');
    } catch (e) {
      debugPrint('SEED_POST_TRANSITION_ERROR: $e');
    }
  });

  // Handle initial seeding on first app launch (before any transition occurs).
  // previous == null means this is the very first time the listener fires,
  // which is the anonymous DB being created at startup.
  ref.listen<LocalDatabase>(localDatabaseProvider, (previous, next) async {
    if (previous != null) return; // Only seed on first creation
    if (ref.read(databaseTransitionProvider)) return;
    
    try {
      await SeedNotesService.seedIfEmpty(next);
      debugPrint('SEED_INITIAL: completed');
    } catch (e) {
      debugPrint('SEED_NOTES_ERROR: $e');
    }
  });
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
  final isTransitioning = ref.watch(databaseTransitionProvider);
  final user = Supabase.instance.client.auth.currentUser;

  if (isTransitioning) {
    debugPrint('SYNC_GUARD: Disabled due to DB transition');
    return false;
  }

  // If we're authenticated but the profile is still loading, 
  // we allow sync to INITIALIZE if we have a user object.
  // This solves the chicken-and-egg problem where sync depends on a profile
  // that can only be fetched reliably if sync/connectivity is healthy.
  // Strict enforcement: Only Pro users or Admins can use Cloud Sync.
  // We wait for the profile to load (userAsync.hasValue) to ensure we don't 
  // accidentally start syncing for a Free user before knowing their tier.
  final isPro = userAsync.valueOrNull?.planTier == PlanTier.pro;
  final isAdmin = userAsync.valueOrNull?.isAdmin ?? false;
  final hasLoadedTier = userAsync.hasValue;

  final shouldEnable = syncAccess.cloudSyncEnabled &&
      authState.status == AuthStatus.authenticated &&
      user != null &&
      hasLoadedTier &&
      (isPro || isAdmin);

  if (!shouldEnable) {
    debugPrint('SYNC_GUARD: Disabled. Reason: '
        'enabled=${syncAccess.cloudSyncEnabled}, '
        'auth=${authState.status}, '
        'user=${user?.id != null}, '
        'hasLoadedTier=$hasLoadedTier, '
        'isPro=$isPro, '
        'isAdmin=$isAdmin');
  } else {
    debugPrint('SYNC_GUARD: Enabled (isPro=$isPro, isAdmin=$isAdmin, loading=${!hasLoadedTier})');
  }

  return shouldEnable;
});


final syncCoordinatorProvider = Provider<SupabaseSyncEngine?>((ref) {
  final useCloudSync = ref.watch(useCloudSyncProvider);
  final user = Supabase.instance.client.auth.currentUser;
  final isTransitioning = ref.watch(databaseTransitionProvider);
  
  // Get stable device ID
  final deviceIdAsync = ref.watch(deviceIdProvider);

  if (!useCloudSync || user == null || isTransitioning || !deviceIdAsync.hasValue) {
    return null;
  }

  final engine = SupabaseSyncEngine(
    client: Supabase.instance.client,
    userId: user.id,
    database: ref.watch(localDatabaseProvider),
    deviceId: deviceIdAsync.value!,
  );
  
  // We start the engine. It will internally handle the initial sync.
  engine.start();
  
  ref.onDispose(engine.dispose);
  return engine;
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
