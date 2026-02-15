class NoteEditorDraft {
  const NoteEditorDraft({
    required this.title,
    required this.body,
    required this.selectedFolderId,
    required this.tags,
    required this.links,
    required this.attachments,
    required this.isTask,
    required this.scheduledTime,
    required this.lastEdited,
    this.noteId,
  });

  final String? noteId;
  final String title;
  final String body;
  final String? selectedFolderId;
  final List<String> tags;
  final List<String> links;
  final List<String> attachments;
  final bool isTask;
  final DateTime? scheduledTime;
  final DateTime lastEdited;
}

class NoteEditorDraftStore {
  static final Map<String, NoteEditorDraft> _drafts = <String, NoteEditorDraft>{};

  static NoteEditorDraft? read(String key) => _drafts[key];

  static void write(String key, NoteEditorDraft draft) {
    _drafts[key] = draft;
  }

  static void remove(String key) {
    _drafts.remove(key);
  }
}
