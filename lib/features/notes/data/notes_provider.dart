import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/note.dart';
import '../domain/models/recurrence_rule.dart';
import 'firestore_notes_repository.dart';

final notesProvider = StreamNotifierProvider<NotesNotifier, List<Note>>(() {
  return NotesNotifier();
});

class NotesNotifier extends StreamNotifier<List<Note>> {
  late FirestoreNotesRepository _repository;

  @override
  Stream<List<Note>> build() {
    final authState = ref.watch(authProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (!authState.isAuthenticated || user == null) {
      return Stream.value([]);
    }

    _repository = FirestoreNotesRepository(
      firestore: FirebaseFirestore.instance,
      userId: user.uid,
    );

    return _repository.watchNotes();
  }

  Future<void> addNote(Note note) async {
    await _repository.addNote(note);
    if (note.reminderTime != null && note.reminderTime!.isAfter(DateTime.now()) && !note.isCompleted) {
      await NotificationService().scheduleNotification(
        id: note.id.hashCode,
        title: 'Reminder: ${note.title}',
        body: note.body ?? 'Time to focus!',
        scheduledDate: note.reminderTime!,
      );
    }
    
    // Generate recurring instances if applicable
    if (note.recurrenceRule != null && note.scheduledTime != null) {
      await _generateInstances(note);
    }
  }

  Future<void> updateNote(Note note) async {
    // Optimistic update
    final currentList = state.value ?? [];
    final updatedList = currentList.map((n) => n.id == note.id ? note : n).toList();
    state = AsyncValue.data(updatedList);

    try {
      await _repository.updateNote(note);
      if (note.reminderTime != null && note.reminderTime!.isAfter(DateTime.now()) && !note.isCompleted) {
        await NotificationService().scheduleNotification(
          id: note.id.hashCode,
          title: 'Reminder: ${note.title}',
          body: note.body ?? 'Time to focus!',
          scheduledDate: note.reminderTime!,
        );
      } else {
        await NotificationService().cancelNotification(note.id.hashCode);
      }
    } catch (e) {
      // Revert on error if necessary, though the stream will eventually refresh
      // For now, we rely on the repository watch to pull the correct state back
    }
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await NotificationService().cancelNotification(id.hashCode);
  }

  // Alias for deleteNote to match previous interface
  Future<void> removeNote(String id) async {
    await deleteNote(id);
  }

  // Toggle completed status for a note
  Future<void> toggleCompleted(String id) async {
    final currentNotes = state.value ?? [];
    final note = currentNotes.firstWhere((n) => n.id == id, orElse: () => throw Exception('Note not found'));
    
    final bool isNowCompleted = !note.isCompleted;
    final updatedNote = note.copyWith(
      isCompleted: isNowCompleted,
      completedAt: isNowCompleted ? DateTime.now() : null,
    );
    
    await updateNote(updatedNote);
  }

  Future<void> deleteFutureInstances(Note note) async {
    final parentId = note.parentRecurringId ?? note.id;
    final allNotes = state.value ?? [];
    
    // Find all future instances of this series
    final futureIds = allNotes
        .where((n) => 
            (n.parentRecurringId == parentId || n.id == parentId) && // Same series
            (n.scheduledTime != null && note.scheduledTime != null) &&
            (n.scheduledTime!.isAfter(note.scheduledTime!) || n.id == note.id)) // Future or This
        .map((n) => n.id)
        .toList();

    if (futureIds.isNotEmpty) {
      await _repository.deleteNotes(futureIds);
      for (var id in futureIds) {
        await NotificationService().cancelNotification(id.hashCode);
      }
    }
  }

  Future<void> deleteAllInstances(Note note) async {
    final parentId = note.parentRecurringId ?? note.id;
    final allNotes = state.value ?? [];
    
    final allIds = allNotes
        .where((n) => n.parentRecurringId == parentId || n.id == parentId)
        .map((n) => n.id)
        .toList();

    if (allIds.isNotEmpty) {
      await _repository.deleteNotes(allIds);
      for (var id in allIds) {
        await NotificationService().cancelNotification(id.hashCode);
      }
    }
  }

  Future<void> updateFutureInstances(Note note) async {
    final parentId = note.parentRecurringId ?? note.id;
    final allNotes = state.value ?? [];
    
    // 1. Delete all future instances (excluding this one if possible, but easier to include and regenerate)
    // Actually, we want to KEEP this note but update it, and DELETE future ones.
    
    final futureIdsToDelete = allNotes
        .where((n) => 
            (n.parentRecurringId == parentId || n.id == parentId) && 
            n.id != note.id && 
            n.scheduledTime != null && note.scheduledTime != null &&
            n.scheduledTime!.isAfter(note.scheduledTime!))
        .map((n) => n.id)
        .toList();

    if (futureIdsToDelete.isNotEmpty) {
      await _repository.deleteNotes(futureIdsToDelete);
    }

    // 2. Update THIS note
    await updateNote(note);

    // 3. Regenerate future instances based on this new rule
    if (note.recurrenceRule != null && note.scheduledTime != null) {
      await _generateInstances(note);
    }
  }

  Future<void> updateAllInstances(Note note) async {
    final parentId = note.parentRecurringId ?? note.id;
    final allNotes = state.value ?? [];
    
    final allInstances = allNotes
        .where((n) => n.parentRecurringId == parentId || n.id == parentId)
        .toList();
        
    for (var instance in allInstances) {
       final updatedInstance = instance.copyWith(
         title: note.title,
         body: note.body,
         priority: note.priority,
         category: note.category,
         // We do not update time/recurrence here as that shifts everything. 
         // "Update All" is typically for content.
       );
       await _repository.updateNote(updatedInstance);
    }
  }

  Future<void> _generateInstances(Note parentNote) async {
    final rule = parentNote.recurrenceRule!;
    final instances = <Note>[];
    
    DateTime nextDate = _calculateNextDate(parentNote.scheduledTime!, rule);
    int count = 1; // Parent is 1st
    
    // Generate for next 60 days OR until end condition
    final limitDate = DateTime.now().add(const Duration(days: 60));
    
    while (true) {
      // Check end conditions
      if (rule.endType == RecurrenceEndType.onDate && rule.endDate != null) {
        if (nextDate.isAfter(rule.endDate!)) break;
      } else if (rule.endType == RecurrenceEndType.afterCount && rule.occurrenceCount != null) {
        if (count >= rule.occurrenceCount!) break;
      } else {
        // Never ends -> limit strict generation window to 60 days to avoid infinite loop / perf issues
        if (nextDate.isAfter(limitDate)) break;
      }

      // Calculate new times
      final duration = parentNote.endTime?.difference(parentNote.scheduledTime!) ?? const Duration(hours: 1);
      final nextEndTime = parentNote.endTime != null ? nextDate.add(duration) : null;
      
      DateTime? nextReminder;
      if (parentNote.reminderTime != null) {
        final reminderOffset = parentNote.scheduledTime!.difference(parentNote.reminderTime!);
        nextReminder = nextDate.subtract(reminderOffset);
      }

      final instance = parentNote.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString() + count.toString(), // Unique ID
        scheduledTime: nextDate,
        endTime: nextEndTime,
        reminderTime: nextReminder,
        parentRecurringId: parentNote.id,
        isRecurringInstance: true,
        originalScheduledTime: nextDate,
        isCompleted: false,
        completedAt: null,
      );
      
      instances.add(instance);
      await _repository.addNote(instance); // Add immediately (or batch ideally)
      
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
         
         return DateTime(nextYear, nextMonth, nextDay, currentDate.hour, currentDate.minute);
      case RecurrenceUnit.year:
         return DateTime(currentDate.year + interval, currentDate.month, currentDate.day, currentDate.hour, currentDate.minute);
    }
  }
}
