import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../attachments/data/image_storage_service.dart';
import '../../../core/providers/repository_provider.dart'; // contains tasksRepositoryProvider and syncCoordinatorProvider
import '../domain/models/task.dart';
import '../../../core/domain/models/recurrence_rule.dart';
import '../../analytics/domain/models/activity_event.dart';
import 'tasks_repository.dart';
import 'package:uuid/uuid.dart';

final tasksProvider = StreamNotifierProvider<TasksNotifier, List<Task>>(() {
  return TasksNotifier();
});

/// Leverages native SQLite indexes to fetch only incomplete overdue tasks in O(log n) time.
final overdueTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final repository = ref.watch(tasksRepositoryProvider);
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  return repository.watchFilteredTasks(
    isCompleted: false,
    scheduledBeforeMs: nowMs,
  );
});

/// Leverages native SQLite indexes to fetch only tasks scheduled for a specific day in O(log n) time.
final timelineTasksProvider = StreamProvider.autoDispose.family<List<Task>, DateTime>((ref, day) {
  final repository = ref.watch(tasksRepositoryProvider);
  final startOfDay = DateTime(day.year, day.month, day.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  
  return repository.watchFilteredTasks(
    scheduledAfterMs: startOfDay.millisecondsSinceEpoch,
    scheduledBeforeMs: endOfDay.millisecondsSinceEpoch,
  );
});

class TasksNotifier extends StreamNotifier<List<Task>> {
  late TasksRepository _repository;

  @override
  Stream<List<Task>> build() {
    NotificationService().onAction ??= _handleNotificationAction;
    _repository = ref.watch(tasksRepositoryProvider);
    
    return _repository.watchTasks();
  }

  Future<void> addTask(Task task) async {
    await _repository.addTask(task);
    await NotificationService().scheduleTask(task);

    if (task.recurrenceRule != null && task.scheduledTime != null) {
      await _generateInstances(task);
    }
  }

  Future<void> updateTask(Task task) async {
    final currentList = state.value ?? [];
    final updatedList = currentList
        .map((t) => t.id == task.id ? task : t)
        .toList();
    state = AsyncValue.data(updatedList);

    try {
      await _repository.updateTask(task);
      await NotificationService().scheduleTask(task);
    } catch (_) {}
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await NotificationService().cancelNotification(id.hashCode);
  }

  Future<void> removeTask(String id) async => await deleteTask(id);

  Future<void> toggleCompleted(String id) async {
    final currentTasks = state.value ?? [];
    final task = currentTasks.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Task not found'),
    );

    final bool isNowCompleted = !task.isCompleted;
    final updatedTask = task.copyWith(
      isCompleted: isNowCompleted,
      completedAt: isNowCompleted ? DateTime.now() : null,
    );

    await updateTask(updatedTask);

    // Activity Logging
    final activityRepo = ref.read(activityRepositoryProvider);
    await activityRepo.logEvent(ActivityEvent(
      id: const Uuid().v4(),
      taskId: id,
      type: isNowCompleted ? ActivityEventType.completed : ActivityEventType.uncompleted,
      timestamp: DateTime.now(),
      category: task.category,
    ));
  }

  Future<void> deleteFutureInstances(Task task) async {
    final parentId = task.parentRecurringId ?? task.id;
    final allTasks = state.value ?? [];

    final futureTasks = allTasks
        .where((t) =>
            (t.parentRecurringId == parentId || t.id == parentId) &&
            (t.scheduledTime != null && task.scheduledTime != null) &&
            (t.scheduledTime!.isAfter(task.scheduledTime!) || t.id == task.id))
        .toList();

    if (futureTasks.isNotEmpty) {
      for (final t in futureTasks) {
        if (t.attachments.isNotEmpty) {
          await ImageStorageService.deleteFiles(t.attachments);
        }
      }
      final futureIds = futureTasks.map((t) => t.id).toList();
      await _repository.deleteTasks(futureIds);
      for (var id in futureIds) {
        await NotificationService().cancelNotification(id.hashCode);
      }
    }
  }

  Future<void> deleteAllInstances(Task task) async {
    final parentId = task.parentRecurringId ?? task.id;
    final allTasks = state.value ?? [];

    final allInstances = allTasks
        .where((t) => t.parentRecurringId == parentId || t.id == parentId)
        .toList();

    if (allInstances.isNotEmpty) {
      for (final t in allInstances) {
        if (t.attachments.isNotEmpty) {
          await ImageStorageService.deleteFiles(t.attachments);
        }
      }
      final allIds = allInstances.map((t) => t.id).toList();
      await _repository.deleteTasks(allIds);
      for (var id in allIds) {
        await NotificationService().cancelNotification(id.hashCode);
      }
    }
  }

  Future<void> updateFutureInstances(Task task) async {
    final parentId = task.parentRecurringId ?? task.id;
    final allTasks = state.value ?? [];

    final futureTasksToDelete = allTasks
        .where((t) =>
            (t.parentRecurringId == parentId || t.id == parentId) &&
            t.id != task.id &&
            t.scheduledTime != null &&
            task.scheduledTime != null &&
            t.scheduledTime!.isAfter(task.scheduledTime!))
        .toList();

    if (futureTasksToDelete.isNotEmpty) {
      for (final t in futureTasksToDelete) {
        if (t.attachments.isNotEmpty) {
          await ImageStorageService.deleteFiles(t.attachments);
        }
      }
      final futureIdsToDelete = futureTasksToDelete.map((t) => t.id).toList();
      await _repository.deleteTasks(futureIdsToDelete);
      for (var id in futureIdsToDelete) {
        await NotificationService().cancelNotification(id.hashCode);
      }
    }

    await updateTask(task);

    if (task.recurrenceRule != null && task.scheduledTime != null) {
      await _generateInstances(task);
    }
  }

  Future<void> updateAllInstances(Task task) async {
    final parentId = task.parentRecurringId ?? task.id;
    final allTasks = state.value ?? [];

    final allInstances = allTasks
        .where((t) => t.parentRecurringId == parentId || t.id == parentId)
        .toList();

    for (var instance in allInstances) {
      final updatedInstance = instance.copyWith(
        title: task.title,
        body: task.body,
        priority: task.priority,
        category: task.category,
      );
      await _repository.updateTask(updatedInstance);
      await NotificationService().scheduleTask(updatedInstance);
    }
  }

  Future<void> _generateInstances(Task parentTask) async {
    final rule = parentTask.recurrenceRule!;
    final instances = <Task>[];

    DateTime nextDate = _calculateNextDate(parentTask.scheduledTime!, rule);
    int count = 1;

    final limitDate = DateTime.now().add(const Duration(days: 60));

    while (true) {
      if (rule.endType == RecurrenceEndType.onDate && rule.endDate != null) {
        if (nextDate.isAfter(rule.endDate!)) break;
      } else if (rule.endType == RecurrenceEndType.afterCount &&
          rule.occurrenceCount != null) {
        if (count >= rule.occurrenceCount!) break;
      } else {
        if (nextDate.isAfter(limitDate)) break;
      }

      final duration =
          parentTask.endTime?.difference(parentTask.scheduledTime!) ??
          const Duration(hours: 1);
      final nextEndTime = parentTask.endTime != null
          ? nextDate.add(duration)
          : null;

      DateTime? nextReminder;
      if (parentTask.reminderTime != null) {
        final reminderOffset = parentTask.scheduledTime!.difference(
          parentTask.reminderTime!,
        );
        nextReminder = nextDate.subtract(reminderOffset);
      }

      final instance = parentTask.copyWith(
        id: const Uuid().v4(),
        scheduledTime: nextDate,
        endTime: nextEndTime,
        reminderTime: nextReminder,
        parentRecurringId: parentTask.id,
        isRecurringInstance: true,
        originalScheduledTime: nextDate,
        isCompleted: false,
        completedAt: null,
      );

      instances.add(instance);
      await _repository.addTask(instance);
      await NotificationService().scheduleTask(instance);

      nextDate = _calculateNextDate(nextDate, rule);
      count++;
    }
  }

  DateTime _calculateNextDate(DateTime currentDate, RecurrenceRule rule) {
    final interval = rule.interval;
    switch (rule.unit) {
      case RecurrenceUnit.day:
        return currentDate.add(Duration(days: interval));
      case RecurrenceUnit.week:
        return currentDate.add(Duration(days: 7 * interval));
      case RecurrenceUnit.month:
        var nextMonth = currentDate.month + interval;
        var nextYear = currentDate.year;
        while (nextMonth > 12) {
          nextMonth -= 12;
          nextYear++;
        }
        var nextDay = currentDate.day;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (nextDay > daysInNextMonth) nextDay = daysInNextMonth;

        return DateTime(
          nextYear,
          nextMonth,
          nextDay,
          currentDate.hour,
          currentDate.minute,
        );
      case RecurrenceUnit.year:
        return DateTime(
          currentDate.year + interval,
          currentDate.month,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
    }
  }

  Future<void> reorderTasks(List<String> orderedIds) async {
    final currentTasks = state.value ?? [];
    for (var i = 0; i < orderedIds.length; i++) {
      final task = currentTasks.firstWhere(
        (t) => t.id == orderedIds[i],
        orElse: () => throw Exception('Task not found: ${orderedIds[i]}'),
      );
      if (task.order != i) {
        final updated = task.copyWith(order: i);
        await _repository.updateTask(updated);
      }
    }
  }

  Future<void> _handleNotificationAction(String actionId, String taskId) async {
    final repo = ref.read(tasksRepositoryProvider);
    final notifService = NotificationService();

    if (actionId == 'check_off') {
      final tasks = state.value;
      if (tasks == null) return;
      final task = tasks.cast<Task?>().firstWhere(
        (t) => t!.id == taskId,
        orElse: () => null,
      );
      if (task == null || task.isCompleted) return;

      final updated = task.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      await repo.updateTask(updated);

      // Activity Logging for Notification Action
      final activityRepo = ref.read(activityRepositoryProvider);
      await activityRepo.logEvent(ActivityEvent(
        id: const Uuid().v4(),
        taskId: taskId,
        type: ActivityEventType.completed,
        timestamp: DateTime.now(),
        category: task.category,
      ));

      state = AsyncValue.data([
        for (final t in tasks) if (t.id == taskId) updated else t,
      ]);
    } else if (actionId == 'snooze') {
      final notifId = taskId.hashCode;
      final snoozedTime = DateTime.now().add(const Duration(minutes: 10));

      final tasks = state.value;
      final task = tasks?.cast<Task?>().firstWhere(
        (t) => t!.id == taskId,
        orElse: () => null,
      );

      // NotificationService expects dynamic or Note.
      // We will adjust it later if we need strict typings.
      await notifService.scheduleNotification(
        id: notifId,
        title: task?.title ?? 'Task',
        body: task?.body ?? 'Snoozed task',
        scheduledDate: snoozedTime,
        subText: 'Synq Task • Snoozed',
        noteId: taskId,
      );
    }
  }
}
