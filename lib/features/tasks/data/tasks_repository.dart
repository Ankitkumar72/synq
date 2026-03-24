import '../domain/models/task.dart';

abstract class TasksRepository {
  Stream<List<Task>> watchTasks();
  Stream<List<Task>> watchFilteredTasks({
    bool? isCompleted,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  });
  Stream<Task?> watchTask(String id);
  Future<void> addTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<void> deleteTasks(List<String> ids);
}
