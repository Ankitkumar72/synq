import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/task.dart';
import 'tasks_repository.dart';

class FirestoreTasksRepository implements TasksRepository {
  final FirebaseFirestore _firestore;
  final String userId;

  FirestoreTasksRepository({
    required FirebaseFirestore firestore,
    required this.userId,
  }) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('users').doc(userId).collection('notes');

  @override
  Stream<List<Task>> watchTasks() {
    return _tasksCollection
        .where('is_deleted', isEqualTo: false)
        .orderBy('created_at_ms', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((data) => data['isTask'] == true)
          .map((data) => Task.fromJson(data))
          .toList();
    });
  }

  @override
  Stream<List<Task>> watchFilteredTasks({
    bool? isCompleted,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) {
    return watchTasks().map((tasks) {
      return tasks.where((task) {
        if (isCompleted != null && task.isCompleted != isCompleted) return false;
        if (folderId != null && task.folderId != folderId) return false;
        
        final schedMs = task.scheduledTime?.millisecondsSinceEpoch;
        if (scheduledBeforeMs != null && (schedMs == null || schedMs >= scheduledBeforeMs)) return false;
        if (scheduledAfterMs != null && (schedMs == null || schedMs < scheduledAfterMs)) return false;
        
        return true;
      }).toList();
    });
  }

  @override
  Stream<Task?> watchTask(String id) {
    return _tasksCollection.doc(id).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data['isTask'] == true) {
          return Task.fromJson(data);
        }
      }
      return null;
    });
  }

  @override
  Future<void> addTask(Task task) async {
    await _tasksCollection.doc(task.id).set(task.toJson());
  }

  @override
  Future<void> updateTask(Task task) async {
    await _tasksCollection.doc(task.id).update(task.toJson());
  }

  @override
  Future<void> deleteTask(String id) async {
    await _tasksCollection.doc(id).delete();
  }

  @override
  Future<void> deleteTasks(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_tasksCollection.doc(id));
    }
    await batch.commit();
  }
}
