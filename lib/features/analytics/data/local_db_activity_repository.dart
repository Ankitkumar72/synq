import '../../../core/database/local_database.dart';
import '../../notes/domain/models/note.dart';
import '../domain/models/activity_event.dart';
import 'activity_repository.dart';

class LocalDbActivityRepository implements ActivityRepository {
  final LocalDatabase _localDb;

  LocalDbActivityRepository(this._localDb);

  @override
  Future<void> logEvent(ActivityEvent event) async {
    await _localDb.insertActivityEvent({
      'id': event.id,
      'taskId': event.taskId,
      'type': event.type.name.toUpperCase(),
      'timestampMs': event.timestamp.millisecondsSinceEpoch,
      'category': event.category.name,
    });
  }

  @override
  Future<List<ActivityEvent>> getActivityHistory({
    DateTime? start,
    DateTime? end,
  }) async {
    final rows = await _localDb.getActivityHistory(
      startMs: start?.millisecondsSinceEpoch,
      endMs: end?.millisecondsSinceEpoch,
    );

    return rows.map((row) {
      return ActivityEvent(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        type: ActivityEventType.values.firstWhere(
          (v) => v.name.toUpperCase() == row['event_type'],
          orElse: () => ActivityEventType.completed,
        ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp_ms'] as int),
        category: NoteCategory.values.firstWhere(
          (v) => v.name == row['category'],
          orElse: () => NoteCategory.personal,
        ),
      );
    }).toList();
  }

  @override
  Future<void> deleteAllActivity() async {
    await _localDb.deleteAllActivity();
  }
}
