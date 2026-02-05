import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/meeting_model.dart';

// Provider for managing meetings
final meetingsProvider = NotifierProvider<MeetingsNotifier, List<MeetingData>>(() {
  return MeetingsNotifier();
});

class MeetingsNotifier extends Notifier<List<MeetingData>> {
  @override
  List<MeetingData> build() {
    // Start with empty list
    return [];
  }

  void addMeeting(MeetingData meeting) {
    state = [...state, meeting];
  }

  void removeMeeting(MeetingData meeting) {
    state = state.where((m) => m != meeting).toList();
  }

  void updateMeeting(int index, MeetingData meeting) {
    final newState = [...state];
    newState[index] = meeting;
    state = newState;
  }
}
