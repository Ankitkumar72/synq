// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'note.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SubTask _$SubTaskFromJson(Map<String, dynamic> json) {
  return _SubTask.fromJson(json);
}

/// @nodoc
mixin _$SubTask {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SubTaskCopyWith<SubTask> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubTaskCopyWith<$Res> {
  factory $SubTaskCopyWith(SubTask value, $Res Function(SubTask) then) =
      _$SubTaskCopyWithImpl<$Res, SubTask>;
  @useResult
  $Res call({String id, String title, bool isCompleted});
}

/// @nodoc
class _$SubTaskCopyWithImpl<$Res, $Val extends SubTask>
    implements $SubTaskCopyWith<$Res> {
  _$SubTaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isCompleted = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubTaskImplCopyWith<$Res> implements $SubTaskCopyWith<$Res> {
  factory _$$SubTaskImplCopyWith(
          _$SubTaskImpl value, $Res Function(_$SubTaskImpl) then) =
      __$$SubTaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, bool isCompleted});
}

/// @nodoc
class __$$SubTaskImplCopyWithImpl<$Res>
    extends _$SubTaskCopyWithImpl<$Res, _$SubTaskImpl>
    implements _$$SubTaskImplCopyWith<$Res> {
  __$$SubTaskImplCopyWithImpl(
      _$SubTaskImpl _value, $Res Function(_$SubTaskImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? isCompleted = null,
  }) {
    return _then(_$SubTaskImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SubTaskImpl implements _SubTask {
  const _$SubTaskImpl(
      {required this.id, required this.title, this.isCompleted = false});

  factory _$SubTaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubTaskImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final bool isCompleted;

  @override
  String toString() {
    return 'SubTask(id: $id, title: $title, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubTaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, isCompleted);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SubTaskImplCopyWith<_$SubTaskImpl> get copyWith =>
      __$$SubTaskImplCopyWithImpl<_$SubTaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubTaskImplToJson(
      this,
    );
  }
}

abstract class _SubTask implements SubTask {
  const factory _SubTask(
      {required final String id,
      required final String title,
      final bool isCompleted}) = _$SubTaskImpl;

  factory _SubTask.fromJson(Map<String, dynamic> json) = _$SubTaskImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  bool get isCompleted;
  @override
  @JsonKey(ignore: true)
  _$$SubTaskImplCopyWith<_$SubTaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Note _$NoteFromJson(Map<String, dynamic> json) {
  return _Note.fromJson(json);
}

/// @nodoc
mixin _$Note {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get body => throw _privateConstructorUsedError;
  NoteCategory get category => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get scheduledTime => throw _privateConstructorUsedError;
  DateTime? get endTime => throw _privateConstructorUsedError;
  DateTime? get reminderTime => throw _privateConstructorUsedError;
  RecurrenceRule? get recurrenceRule =>
      throw _privateConstructorUsedError; // For defining recurrence
  String? get parentRecurringId =>
      throw _privateConstructorUsedError; // ID of the parent/original task
  DateTime? get originalScheduledTime =>
      throw _privateConstructorUsedError; // The original date this instance was generated for
  DateTime? get completedAt => throw _privateConstructorUsedError;
  TaskPriority get priority => throw _privateConstructorUsedError;
  bool get isTask =>
      throw _privateConstructorUsedError; // true = task, false = note
  bool get isAllDay =>
      throw _privateConstructorUsedError; // true = all day event (no specific time)
  bool get isRecurringInstance =>
      throw _privateConstructorUsedError; // true if generated from recurrence
  bool get isCompleted => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  List<String> get attachments =>
      throw _privateConstructorUsedError; // URLs of uploaded images/media
  List<String> get links => throw _privateConstructorUsedError; // Embedded URLs
  List<SubTask> get subtasks =>
      throw _privateConstructorUsedError; // Sub-tasks for this note
  String? get folderId =>
      throw _privateConstructorUsedError; // ID of the folder this note belongs to
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $NoteCopyWith<Note> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoteCopyWith<$Res> {
  factory $NoteCopyWith(Note value, $Res Function(Note) then) =
      _$NoteCopyWithImpl<$Res, Note>;
  @useResult
  $Res call(
      {String id,
      String title,
      String? body,
      NoteCategory category,
      DateTime createdAt,
      DateTime? scheduledTime,
      DateTime? endTime,
      DateTime? reminderTime,
      RecurrenceRule? recurrenceRule,
      String? parentRecurringId,
      DateTime? originalScheduledTime,
      DateTime? completedAt,
      TaskPriority priority,
      bool isTask,
      bool isAllDay,
      bool isRecurringInstance,
      bool isCompleted,
      List<String> tags,
      List<String> attachments,
      List<String> links,
      List<SubTask> subtasks,
      String? folderId,
      DateTime? updatedAt});

  $RecurrenceRuleCopyWith<$Res>? get recurrenceRule;
}

/// @nodoc
class _$NoteCopyWithImpl<$Res, $Val extends Note>
    implements $NoteCopyWith<$Res> {
  _$NoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? body = freezed,
    Object? category = null,
    Object? createdAt = null,
    Object? scheduledTime = freezed,
    Object? endTime = freezed,
    Object? reminderTime = freezed,
    Object? recurrenceRule = freezed,
    Object? parentRecurringId = freezed,
    Object? originalScheduledTime = freezed,
    Object? completedAt = freezed,
    Object? priority = null,
    Object? isTask = null,
    Object? isAllDay = null,
    Object? isRecurringInstance = null,
    Object? isCompleted = null,
    Object? tags = null,
    Object? attachments = null,
    Object? links = null,
    Object? subtasks = null,
    Object? folderId = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      body: freezed == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String?,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as NoteCategory,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      scheduledTime: freezed == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      reminderTime: freezed == reminderTime
          ? _value.reminderTime
          : reminderTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      recurrenceRule: freezed == recurrenceRule
          ? _value.recurrenceRule
          : recurrenceRule // ignore: cast_nullable_to_non_nullable
              as RecurrenceRule?,
      parentRecurringId: freezed == parentRecurringId
          ? _value.parentRecurringId
          : parentRecurringId // ignore: cast_nullable_to_non_nullable
              as String?,
      originalScheduledTime: freezed == originalScheduledTime
          ? _value.originalScheduledTime
          : originalScheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as TaskPriority,
      isTask: null == isTask
          ? _value.isTask
          : isTask // ignore: cast_nullable_to_non_nullable
              as bool,
      isAllDay: null == isAllDay
          ? _value.isAllDay
          : isAllDay // ignore: cast_nullable_to_non_nullable
              as bool,
      isRecurringInstance: null == isRecurringInstance
          ? _value.isRecurringInstance
          : isRecurringInstance // ignore: cast_nullable_to_non_nullable
              as bool,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      attachments: null == attachments
          ? _value.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<String>,
      links: null == links
          ? _value.links
          : links // ignore: cast_nullable_to_non_nullable
              as List<String>,
      subtasks: null == subtasks
          ? _value.subtasks
          : subtasks // ignore: cast_nullable_to_non_nullable
              as List<SubTask>,
      folderId: freezed == folderId
          ? _value.folderId
          : folderId // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $RecurrenceRuleCopyWith<$Res>? get recurrenceRule {
    if (_value.recurrenceRule == null) {
      return null;
    }

    return $RecurrenceRuleCopyWith<$Res>(_value.recurrenceRule!, (value) {
      return _then(_value.copyWith(recurrenceRule: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$NoteImplCopyWith<$Res> implements $NoteCopyWith<$Res> {
  factory _$$NoteImplCopyWith(
          _$NoteImpl value, $Res Function(_$NoteImpl) then) =
      __$$NoteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String? body,
      NoteCategory category,
      DateTime createdAt,
      DateTime? scheduledTime,
      DateTime? endTime,
      DateTime? reminderTime,
      RecurrenceRule? recurrenceRule,
      String? parentRecurringId,
      DateTime? originalScheduledTime,
      DateTime? completedAt,
      TaskPriority priority,
      bool isTask,
      bool isAllDay,
      bool isRecurringInstance,
      bool isCompleted,
      List<String> tags,
      List<String> attachments,
      List<String> links,
      List<SubTask> subtasks,
      String? folderId,
      DateTime? updatedAt});

  @override
  $RecurrenceRuleCopyWith<$Res>? get recurrenceRule;
}

/// @nodoc
class __$$NoteImplCopyWithImpl<$Res>
    extends _$NoteCopyWithImpl<$Res, _$NoteImpl>
    implements _$$NoteImplCopyWith<$Res> {
  __$$NoteImplCopyWithImpl(_$NoteImpl _value, $Res Function(_$NoteImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? body = freezed,
    Object? category = null,
    Object? createdAt = null,
    Object? scheduledTime = freezed,
    Object? endTime = freezed,
    Object? reminderTime = freezed,
    Object? recurrenceRule = freezed,
    Object? parentRecurringId = freezed,
    Object? originalScheduledTime = freezed,
    Object? completedAt = freezed,
    Object? priority = null,
    Object? isTask = null,
    Object? isAllDay = null,
    Object? isRecurringInstance = null,
    Object? isCompleted = null,
    Object? tags = null,
    Object? attachments = null,
    Object? links = null,
    Object? subtasks = null,
    Object? folderId = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$NoteImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      body: freezed == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String?,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as NoteCategory,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      scheduledTime: freezed == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      reminderTime: freezed == reminderTime
          ? _value.reminderTime
          : reminderTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      recurrenceRule: freezed == recurrenceRule
          ? _value.recurrenceRule
          : recurrenceRule // ignore: cast_nullable_to_non_nullable
              as RecurrenceRule?,
      parentRecurringId: freezed == parentRecurringId
          ? _value.parentRecurringId
          : parentRecurringId // ignore: cast_nullable_to_non_nullable
              as String?,
      originalScheduledTime: freezed == originalScheduledTime
          ? _value.originalScheduledTime
          : originalScheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as TaskPriority,
      isTask: null == isTask
          ? _value.isTask
          : isTask // ignore: cast_nullable_to_non_nullable
              as bool,
      isAllDay: null == isAllDay
          ? _value.isAllDay
          : isAllDay // ignore: cast_nullable_to_non_nullable
              as bool,
      isRecurringInstance: null == isRecurringInstance
          ? _value.isRecurringInstance
          : isRecurringInstance // ignore: cast_nullable_to_non_nullable
              as bool,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      attachments: null == attachments
          ? _value._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<String>,
      links: null == links
          ? _value._links
          : links // ignore: cast_nullable_to_non_nullable
              as List<String>,
      subtasks: null == subtasks
          ? _value._subtasks
          : subtasks // ignore: cast_nullable_to_non_nullable
              as List<SubTask>,
      folderId: freezed == folderId
          ? _value.folderId
          : folderId // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NoteImpl extends _Note {
  const _$NoteImpl(
      {required this.id,
      required this.title,
      this.body,
      required this.category,
      required this.createdAt,
      this.scheduledTime,
      this.endTime,
      this.reminderTime,
      this.recurrenceRule,
      this.parentRecurringId,
      this.originalScheduledTime,
      this.completedAt,
      this.priority = TaskPriority.medium,
      this.isTask = false,
      this.isAllDay = false,
      this.isRecurringInstance = false,
      this.isCompleted = false,
      final List<String> tags = const [],
      final List<String> attachments = const [],
      final List<String> links = const [],
      final List<SubTask> subtasks = const [],
      this.folderId,
      this.updatedAt})
      : _tags = tags,
        _attachments = attachments,
        _links = links,
        _subtasks = subtasks,
        super._();

  factory _$NoteImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoteImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? body;
  @override
  final NoteCategory category;
  @override
  final DateTime createdAt;
  @override
  final DateTime? scheduledTime;
  @override
  final DateTime? endTime;
  @override
  final DateTime? reminderTime;
  @override
  final RecurrenceRule? recurrenceRule;
// For defining recurrence
  @override
  final String? parentRecurringId;
// ID of the parent/original task
  @override
  final DateTime? originalScheduledTime;
// The original date this instance was generated for
  @override
  final DateTime? completedAt;
  @override
  @JsonKey()
  final TaskPriority priority;
  @override
  @JsonKey()
  final bool isTask;
// true = task, false = note
  @override
  @JsonKey()
  final bool isAllDay;
// true = all day event (no specific time)
  @override
  @JsonKey()
  final bool isRecurringInstance;
// true if generated from recurrence
  @override
  @JsonKey()
  final bool isCompleted;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  final List<String> _attachments;
  @override
  @JsonKey()
  List<String> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

// URLs of uploaded images/media
  final List<String> _links;
// URLs of uploaded images/media
  @override
  @JsonKey()
  List<String> get links {
    if (_links is EqualUnmodifiableListView) return _links;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_links);
  }

// Embedded URLs
  final List<SubTask> _subtasks;
// Embedded URLs
  @override
  @JsonKey()
  List<SubTask> get subtasks {
    if (_subtasks is EqualUnmodifiableListView) return _subtasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subtasks);
  }

// Sub-tasks for this note
  @override
  final String? folderId;
// ID of the folder this note belongs to
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Note(id: $id, title: $title, body: $body, category: $category, createdAt: $createdAt, scheduledTime: $scheduledTime, endTime: $endTime, reminderTime: $reminderTime, recurrenceRule: $recurrenceRule, parentRecurringId: $parentRecurringId, originalScheduledTime: $originalScheduledTime, completedAt: $completedAt, priority: $priority, isTask: $isTask, isAllDay: $isAllDay, isRecurringInstance: $isRecurringInstance, isCompleted: $isCompleted, tags: $tags, attachments: $attachments, links: $links, subtasks: $subtasks, folderId: $folderId, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.scheduledTime, scheduledTime) ||
                other.scheduledTime == scheduledTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.reminderTime, reminderTime) ||
                other.reminderTime == reminderTime) &&
            (identical(other.recurrenceRule, recurrenceRule) ||
                other.recurrenceRule == recurrenceRule) &&
            (identical(other.parentRecurringId, parentRecurringId) ||
                other.parentRecurringId == parentRecurringId) &&
            (identical(other.originalScheduledTime, originalScheduledTime) ||
                other.originalScheduledTime == originalScheduledTime) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.isTask, isTask) || other.isTask == isTask) &&
            (identical(other.isAllDay, isAllDay) ||
                other.isAllDay == isAllDay) &&
            (identical(other.isRecurringInstance, isRecurringInstance) ||
                other.isRecurringInstance == isRecurringInstance) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments) &&
            const DeepCollectionEquality().equals(other._links, _links) &&
            const DeepCollectionEquality().equals(other._subtasks, _subtasks) &&
            (identical(other.folderId, folderId) ||
                other.folderId == folderId) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        title,
        body,
        category,
        createdAt,
        scheduledTime,
        endTime,
        reminderTime,
        recurrenceRule,
        parentRecurringId,
        originalScheduledTime,
        completedAt,
        priority,
        isTask,
        isAllDay,
        isRecurringInstance,
        isCompleted,
        const DeepCollectionEquality().hash(_tags),
        const DeepCollectionEquality().hash(_attachments),
        const DeepCollectionEquality().hash(_links),
        const DeepCollectionEquality().hash(_subtasks),
        folderId,
        updatedAt
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$NoteImplCopyWith<_$NoteImpl> get copyWith =>
      __$$NoteImplCopyWithImpl<_$NoteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoteImplToJson(
      this,
    );
  }
}

abstract class _Note extends Note {
  const factory _Note(
      {required final String id,
      required final String title,
      final String? body,
      required final NoteCategory category,
      required final DateTime createdAt,
      final DateTime? scheduledTime,
      final DateTime? endTime,
      final DateTime? reminderTime,
      final RecurrenceRule? recurrenceRule,
      final String? parentRecurringId,
      final DateTime? originalScheduledTime,
      final DateTime? completedAt,
      final TaskPriority priority,
      final bool isTask,
      final bool isAllDay,
      final bool isRecurringInstance,
      final bool isCompleted,
      final List<String> tags,
      final List<String> attachments,
      final List<String> links,
      final List<SubTask> subtasks,
      final String? folderId,
      final DateTime? updatedAt}) = _$NoteImpl;
  const _Note._() : super._();

  factory _Note.fromJson(Map<String, dynamic> json) = _$NoteImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get body;
  @override
  NoteCategory get category;
  @override
  DateTime get createdAt;
  @override
  DateTime? get scheduledTime;
  @override
  DateTime? get endTime;
  @override
  DateTime? get reminderTime;
  @override
  RecurrenceRule? get recurrenceRule;
  @override // For defining recurrence
  String? get parentRecurringId;
  @override // ID of the parent/original task
  DateTime? get originalScheduledTime;
  @override // The original date this instance was generated for
  DateTime? get completedAt;
  @override
  TaskPriority get priority;
  @override
  bool get isTask;
  @override // true = task, false = note
  bool get isAllDay;
  @override // true = all day event (no specific time)
  bool get isRecurringInstance;
  @override // true if generated from recurrence
  bool get isCompleted;
  @override
  List<String> get tags;
  @override
  List<String> get attachments;
  @override // URLs of uploaded images/media
  List<String> get links;
  @override // Embedded URLs
  List<SubTask> get subtasks;
  @override // Sub-tasks for this note
  String? get folderId;
  @override // ID of the folder this note belongs to
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$NoteImplCopyWith<_$NoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
