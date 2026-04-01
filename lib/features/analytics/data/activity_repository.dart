import '../domain/models/activity_event.dart';

abstract class ActivityRepository {
  Future<void> logEvent(ActivityEvent event);
  Future<List<ActivityEvent>> getActivityHistory({DateTime? start, DateTime? end});
  Future<void> deleteAllActivity();
}
