import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
enum TaskStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  active,
  @HiveField(2)
  completed,
}

@HiveType(typeId: 1)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  bool isDeepWork;

  @HiveField(4)
  TaskStatus status;

  @HiveField(5)
  int priority; 

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? dueDate;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.isDeepWork = false,
    this.status = TaskStatus.pending,
    this.priority = 0,
    required this.createdAt,
    this.dueDate,
  });

  factory Task.create({
    required String title,
    String? description,
    bool isDeepWork = false,
    int priority = 0,
    DateTime? dueDate,
  }) {
    return Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      isDeepWork: isDeepWork,
      priority: priority,
      createdAt: DateTime.now(),
      dueDate: dueDate,
    );
  }
}
