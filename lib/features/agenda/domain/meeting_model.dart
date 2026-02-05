// The blueprint for a single agenda item (e.g., "Project Update")
class AgendaItemData {
  String title;
  String subtitle;
  String duration;
  bool isCompleted;

  AgendaItemData({
    required this.title,
    required this.subtitle,
    required this.duration,
    this.isCompleted = false,
  });
}

// The blueprint for the whole meeting
class MeetingData {
  String title;
  String timeRange;
  List<AgendaItemData> items;

  MeetingData({
    required this.title,
    required this.timeRange,
    required this.items,
  });
}
