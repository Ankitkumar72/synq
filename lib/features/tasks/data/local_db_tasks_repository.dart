import '../../../core/database/local_database.dart';
import '../../notes/domain/models/note.dart';
import '../domain/models/task.dart';
import 'tasks_repository.dart';

class LocalDbTasksRepository implements TasksRepository {
  final LocalDatabase _localDb;

  LocalDbTasksRepository(this._localDb);

  @override
  Stream<List<Task>> watchTasks() {
    return _localDb.watchFilteredNotes(isTask: true).map(
      (notes) => notes.map((n) => Task.fromJson(n.toJson())).toList(),
    );
  }

  @override
  Stream<List<Task>> watchFilteredTasks({
    bool? isCompleted,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) {
    return _localDb
        .watchFilteredNotes(
          isTask: true,
          isCompleted: isCompleted,
          scheduledBeforeMs: scheduledBeforeMs,
          scheduledAfterMs: scheduledAfterMs,
          folderId: folderId,
        )
        .map((notes) => notes.map((n) => Task.fromJson(n.toJson())).toList());
  }

  @override
  Stream<Task?> watchTask(String id) {
    return _localDb.watchNote(id).map(
      (n) => n != null && n.isTask ? Task.fromJson(n.toJson()) : null,
    );
  }

  @override
  Future<void> addTask(Task task) async {
    final note = Note.fromJson(task.toJson());
    await _localDb.upsertNote(note, source: SyncWriteSource.local);
  }

  @override
  Future<void> updateTask(Task task) async {
    final note = Note.fromJson(task.toJson());
    await _localDb.upsertNote(note, source: SyncWriteSource.local);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _localDb.markNoteDeleted(id, source: SyncWriteSource.local);
  }

  @override
  Future<void> deleteTasks(List<String> ids) async {
    await _localDb.markNotesDeleted(ids, source: SyncWriteSource.local);
  }
}
