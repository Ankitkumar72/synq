import 'dart:async';
import 'dart:math';


import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crdt/hlc.dart';
import '../../../core/database/local_database.dart';
import '../../../core/services/supabase_service.dart';
import 'supabase_note_syncer.dart';
import 'supabase_folder_syncer.dart';

/// Sync engine states for UI feedback.
enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

/// The main Supabase sync coordinator — replaces [FirebaseSyncCoordinator].
///
/// Architecture:
///   1. **Outbox Push** → Drains the local `sync_queue` table and pushes
///      pending operations to Supabase via REST API (upsert with field-level
///      HLC versions for CRDT merging).
///
///   2. **Realtime Pull** → Subscribes to Supabase Realtime `postgres_changes`
///      on the `notes` and `folders` tables. When a remote change arrives,
///      the engine performs a field-level CRDT merge with the local SQLite
///      state and writes the winner to SQLite.
///
///   3. **Bootstrap Pull** → On first sync (empty local DB), fetches all
///      remote data via paginated REST queries.
///
/// Lifecycle:
///   - Call [start()] after authentication to begin syncing.
///   - Call [dispose()] on sign-out or when the provider is torn down.
///   - The engine is designed to be re-created per user session (not reused).
///
/// Thread safety:
///   - All SQLite writes go through [LocalDatabase]'s `synchronized` lock.
///   - Outbox push is serialized to avoid duplicate pushes.
///
/// TODO(impl):
///   - [ ] Wire to repository_provider.dart (replace syncCoordinatorProvider)
///   - [ ] Handle connectivity changes (connectivity_plus)
///   - [ ] Add exponential backoff for push retries
///   - [ ] Add SyncStatus stream for UI sync indicator
class SupabaseSyncEngine {
  SupabaseSyncEngine({
    required this.userId,
    required LocalDatabase database,
    required String deviceId,
    SupabaseClient? client,
  })  : _client = client ?? SupabaseService.client,
        _database = database,
        _deviceId = deviceId {
    _clock = HLC.now(_deviceId);
    _noteSyncer = SupabaseNoteSyncer(
      client: _client,
      database: _database,
      userId: userId,
      clock: _clock,
    );
    _folderSyncer = SupabaseFolderSyncer(
      client: _client,
      database: _database,
      userId: userId,
      clock: _clock,
    );
    debugPrint('SUPABASE_SYNC_ENGINE_CREATED: User $userId, Device $_deviceId');
  }

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final SupabaseClient _client;
  final LocalDatabase _database;
  final String userId;
  final String _deviceId;

  late HLC _clock;
  late SupabaseNoteSyncer _noteSyncer;
  late SupabaseFolderSyncer _folderSyncer;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  RealtimeChannel? _notesChannel;
  RealtimeChannel? _foldersChannel;
  Timer? _pollTimer;
  Timer? _healthCheckTimer;
  StreamSubscription<void>? _syncQueueSubscription;

  bool _isSyncing = false;
  bool _syncRequested = false;
  bool _isDisposed = false;
  bool _realtimeConnected = false;
  RealtimeSubscribeStatus _notesStatus = RealtimeSubscribeStatus.closed;
  RealtimeSubscribeStatus _foldersStatus = RealtimeSubscribeStatus.closed;

  /// Max retry attempts before falling back to poll-only mode.
  static const _maxRealtimeRetries = 5;

  final _statusController = StreamController<SyncStatus>.broadcast();

  /// Stream of sync status changes for UI indicators.
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// The CRDT clock for this engine. Exposed for testing.
  HLC get clock => _clock;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the sync engine:
  ///   1. Subscribes to Realtime postgres_changes for notes & folders
  ///   2. Starts listening to the local sync_queue for outbox changes
  ///   3. Triggers an initial bootstrap if the local DB is empty
  void start() {
    if (_isDisposed) return;
    debugPrint('SUPABASE_SYNC_ENGINE_STARTING: User $userId');

    // A small delay provides time for Supabase Auth JWT to natively propagate
    // down to the Realtime socket manager on fresh app launches.
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isDisposed) _subscribeToRealtime();
    });

    _listenToSyncQueue();
    _checkInitialSync();
    _startPollFallback();
    _startHealthCheck();
  }

  /// Stops all subscriptions and releases resources.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _pollTimer?.cancel();
    _healthCheckTimer?.cancel();
    _syncQueueSubscription?.cancel();
    _notesChannel?.unsubscribe();
    _foldersChannel?.unsubscribe();
    _statusController.close();

    debugPrint('SUPABASE_SYNC_ENGINE_DISPOSED: User $userId');
  }

  // ---------------------------------------------------------------------------
  // Realtime Subscriptions
  // ---------------------------------------------------------------------------

  void _subscribeToRealtime({int attempt = 0}) {
    // Clean up previous channels before retry
    _notesChannel?.unsubscribe();
    _foldersChannel?.unsubscribe();

    // Use unique channel names per attempt to avoid channel reuse issues
    final suffix = attempt > 0 ? '_r$attempt' : '';

    debugPrint('REALTIME_SUBSCRIBING: attempt=$attempt');

    // Subscribe to notes changes for this user
    _notesChannel = _client
        .channel('notes_$userId$suffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onRemoteChange('note', payload),
        )
        .subscribe((status, error) {
      debugPrint('REALTIME_NOTES_STATUS: $status ${error ?? ""}');
      _notesStatus = status;
      _handleRealtimeStatus('notes', status, attempt);
    });

    // Subscribe to folders changes for this user
    _foldersChannel = _client
        .channel('folders_$userId$suffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'folders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onRemoteChange('folder', payload),
        )
        .subscribe((status, error) {
      debugPrint('REALTIME_FOLDERS_STATUS: $status ${error ?? ""}');
      _foldersStatus = status;
      _handleRealtimeStatus('folders', status, attempt);
    });
  }

  /// Handles realtime subscription status — retries with exponential backoff
  /// on timeout or errors, up to [_maxRealtimeRetries] attempts.
  void _handleRealtimeStatus(
    String table,
    RealtimeSubscribeStatus status,
    int attempt,
  ) {
    if (status == RealtimeSubscribeStatus.subscribed) {
      _realtimeConnected = true;
      debugPrint('REALTIME_CONNECTED: $table ✓');
      return;
    }

    bool isErrorStatus = status == RealtimeSubscribeStatus.timedOut ||
                         status == RealtimeSubscribeStatus.channelError ||
                         status == RealtimeSubscribeStatus.closed;

    if (isErrorStatus) {
      _realtimeConnected = false;

      if (attempt < _maxRealtimeRetries) {
        final delaySec = min(pow(2, attempt + 1).toInt(), 16); // 2s, 4s, 8s, 16s
        debugPrint(
          'REALTIME_RETRY: $table $status — retrying in ${delaySec}s (attempt ${attempt + 1})',
        );
        Future.delayed(Duration(seconds: delaySec), () {
          if (!_isDisposed) _subscribeToRealtime(attempt: attempt + 1);
        });
      } else {
        debugPrint(
          'REALTIME_GAVE_UP: $table $status — falling back to poll-only mode',
        );
      }
    }
  }

  /// Periodic REST poll as a safety net. If realtime never connects, the app
  /// still stays in sync via polling using cursor-based bootstrap.
  /// Polls every 10s when realtime is disconnected, every 60s when connected.
  void _startPollFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isDisposed && !_isSyncing) {
        // Poll more aggressively when realtime is down
        final interval = _realtimeConnected ? 60 : 10;
        // Use a modulo check so we don't need to recreate the timer
        if (!_realtimeConnected || DateTime.now().second % interval < 10) {
          debugPrint('POLL_FALLBACK: running periodic sync (realtime=${_realtimeConnected ? "up" : "down"})');
          _bootstrapFromRemote();
        }
      }
    });
  }

  /// Periodic health check: verifies realtime channels are still alive.
  /// If they've silently disconnected, forces a resubscribe.
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isDisposed) return;

      final notesOk = _notesStatus == RealtimeSubscribeStatus.subscribed;
      final foldersOk = _foldersStatus == RealtimeSubscribeStatus.subscribed;

      if (!notesOk || !foldersOk) {
        debugPrint('REALTIME_HEALTH_CHECK: notes=$notesOk, folders=$foldersOk — resubscribing');
        _realtimeConnected = false;
        _subscribeToRealtime();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Realtime Event Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onRemoteChange(
    String entityType,
    PostgresChangePayload payload,
  ) async {
    if (_isDisposed) return;

    try {
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) {
        debugPrint('REALTIME_EMPTY_PAYLOAD: $entityType ${payload.eventType}');
        return;
      }

      // Skip changes we originated (prevent echo)
      if (newRecord['device_last_edited'] == _deviceId) {
        debugPrint('REALTIME_SKIP_OWN: $entityType ${newRecord['id']}');
        return;
      }

      debugPrint('REALTIME_INCOMING: $entityType ${payload.eventType} '
          'id=${newRecord['id']}');

      switch (entityType) {
        case 'note':
          await _noteSyncer.mergeRemoteNote(newRecord);
          break;
        case 'folder':
          await _folderSyncer.mergeRemoteFolder(newRecord);
          break;
      }
    } catch (e) {
      debugPrint('REALTIME_HANDLER_ERROR: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Outbox Push
  // ---------------------------------------------------------------------------

  void _listenToSyncQueue() {
    _syncQueueSubscription?.cancel();
    _syncQueueSubscription = _database.syncQueueChanged.listen((_) {
      unawaited(syncNow());
    });
  }

  /// Triggers a sync cycle: push pending outbox ops, pull any missed changes.
  ///
  /// This is idempotent and coalescing — if a sync is already in progress,
  /// the request is queued and will run after the current cycle completes.
  Future<void> syncNow() async {
    if (_isDisposed) return;

    if (_isSyncing) {
      _syncRequested = true;
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      await _pushOutbox();
    } catch (e) {
      debugPrint('SYNC_PUSH_ERROR: $e');
      _statusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      _statusController.add(SyncStatus.idle);

      // If another sync was requested while we were busy, run again
      if (_syncRequested && !_isDisposed) {
        _syncRequested = false;
        unawaited(syncNow());
      }
    }
  }

  /// Drains the outbox (sync_queue) and pushes each operation to Supabase.
  Future<void> _pushOutbox() async {
    const batchSize = 50;

    while (!_isDisposed) {
      final ops = await _database.getPendingSyncOps(limit: batchSize);
      if (ops.isEmpty) break;

      for (final op in ops) {
        if (_isDisposed) return;

        try {
          switch (op.entityType) {
            case LocalDatabase.entityTypeNote:
              await _noteSyncer.pushNote(op);
              break;
            case LocalDatabase.entityTypeFolder:
              await _folderSyncer.pushFolder(op);
              break;
          }

          // Mark as succeeded
          await _database.deleteSyncQueueOp(op.opId);
        } catch (e) {
          debugPrint('PUSH_OP_ERROR: ${op.entityType}/${op.entityId}: $e');
          await _database.incrementRetryCount(op.opId);
          // Don't rethrow — continue with next op
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Bootstrap (Initial Sync)
  // ---------------------------------------------------------------------------

  /// Checks if the local DB is fresh or partially synced and pulls missing data.
  Future<void> _checkInitialSync() async {
    try {
      // Purge invalid ops that will never succeed (e.g. integer IDs, exceeded retries)
      await _purgeInvalidSyncOps();

      // With high-water mark cursors, we can always attempt a bootstrap on startup.
      // It will only fetch what's new since the last successful batch.
      await _bootstrapFromRemote();

      // Always push any pending ops after bootstrap
      unawaited(syncNow());
    } catch (e) {
      debugPrint('INITIAL_SYNC_CHECK_ERROR: $e');
    }
  }

  /// UUID v4 pattern — matches standard 8-4-4-4-12 hex format.
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Maximum retries before an op is considered permanently failed.
  static const _maxRetries = 5;

  /// Removes sync queue entries that will never succeed:
  ///   - entity_id is not a valid UUID (legacy integer timestamp IDs)
  ///   - retry_count has exceeded _maxRetries
  Future<void> _purgeInvalidSyncOps() async {
    try {
      final ops = await _database.getPendingSyncOps(limit: 200);
      int purged = 0;
      for (final op in ops) {
        final isInvalidId = !_uuidRegex.hasMatch(op.entityId);
        final isExhausted = op.retryCount >= _maxRetries;
        if (isInvalidId || isExhausted) {
          await _database.deleteSyncQueueOp(op.opId);
          purged++;
          debugPrint('SYNC_PURGE: ${op.entityType}/${op.entityId} '
              '(invalidId=$isInvalidId, retries=${op.retryCount})');
        }
      }
      if (purged > 0) {
        debugPrint('SYNC_PURGE_COMPLETE: Removed $purged invalid ops');
      }
    } catch (e) {
      debugPrint('SYNC_PURGE_ERROR: $e');
    }
  }

  /// Pulls all remote data for this user and inserts it into SQLite.
  /// Uses a sequenced approach (Folders -> Notes) to maintain referential integrity.
  Future<void> _bootstrapFromRemote() async {
    _statusController.add(SyncStatus.syncing);

    try {
      debugPrint('SUPABASE_SYNC: Pulling folders...');
      await _folderSyncer.bootstrapFolders();

      debugPrint('SUPABASE_SYNC: Pulling notes...');
      await _noteSyncer.bootstrapNotes();

      debugPrint('SUPABASE_SYNC_COMPLETE');
    } catch (e) {
      debugPrint('SUPABASE_SYNC_ERROR: $e');
      _statusController.add(SyncStatus.error);
    }
  }
}
