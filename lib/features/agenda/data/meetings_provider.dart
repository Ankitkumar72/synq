import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/meeting_model.dart';

// Provider for managing meetings
final meetingsProvider = NotifierProvider<MeetingsNotifier, List<MeetingData>>(() {
  return MeetingsNotifier();
});

class MeetingsNotifier extends Notifier<List<MeetingData>> {
  @override
  List<MeetingData> build() {
    // Start with sample data
    return [
      MeetingData(
        title: "Client Sync: Alpha Corp",
        timeRange: "10:30 AM - 11:30 AM",
        items: [
          AgendaItemData(title: "Project Update", subtitle: "Reviewing Q3 milestones and blockers.", duration: "Now"),
          AgendaItemData(title: "Design Review", subtitle: "Walkthrough of new mobile flows.", duration: "15m"),
          AgendaItemData(title: "Next Steps", subtitle: "Assigning action items for the week.", duration: "5m"),
        ],
      ),
    ];
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
