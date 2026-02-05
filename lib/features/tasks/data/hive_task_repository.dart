import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/task.dart';
import '../domain/models/task_repository.dart';

class HiveTaskRepository implements TaskRepository {
  static const String boxName = 'tasksBox';
  
  @override
  Future<void> initialized() async {
     if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TaskAdapter());
    }
    await Hive.openBox<Task>(boxName);
  }

  Box<Task> get _box => Hive.box<Task>(boxName);

  @override
  Future<List<Task>> getTasks() async {
    return _box.values.toList();
  }

  @override
  Future<void> addTask(Task task) async {
    await _box.put(task.id, task);
  }

  @override
  Future<void> updateTask(Task task) async {
    await _box.put(task.id, task);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return HiveTaskRepository();
});

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return TasksNotifier(repository);
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final TaskRepository _repository;

  TasksNotifier(this._repository) : super([]) {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    state = await _repository.getTasks();
  }

  Future<void> addTask(Task task) async {
    await _repository.addTask(task);
    state = [...state, task];
  }
  
  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
    _loadTasks(); // or local update
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    state = state.where((t) => t.id != id).toList();
  }
}
