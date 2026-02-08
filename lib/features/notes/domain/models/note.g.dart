// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SubTaskImpl _$$SubTaskImplFromJson(Map<String, dynamic> json) =>
    _$SubTaskImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$SubTaskImplToJson(_$SubTaskImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'isCompleted': instance.isCompleted,
    };

_$NoteImpl _$$NoteImplFromJson(Map<String, dynamic> json) => _$NoteImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      category: $enumDecode(_$NoteCategoryEnumMap, json['category']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledTime: json['scheduledTime'] == null
          ? null
          : DateTime.parse(json['scheduledTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      reminderTime: json['reminderTime'] == null
          ? null
          : DateTime.parse(json['reminderTime'] as String),
      recurrenceRule: json['recurrenceRule'] == null
          ? null
          : RecurrenceRule.fromJson(
              json['recurrenceRule'] as Map<String, dynamic>),
      parentRecurringId: json['parentRecurringId'] as String?,
      originalScheduledTime: json['originalScheduledTime'] == null
          ? null
          : DateTime.parse(json['originalScheduledTime'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
          TaskPriority.medium,
      isTask: json['isTask'] as bool? ?? false,
      isAllDay: json['isAllDay'] as bool? ?? false,
      isRecurringInstance: json['isRecurringInstance'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      links:
          (json['links'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((e) => SubTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      folderId: json['folderId'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$NoteImplToJson(_$NoteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'category': _$NoteCategoryEnumMap[instance.category]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'scheduledTime': instance.scheduledTime?.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'reminderTime': instance.reminderTime?.toIso8601String(),
      'recurrenceRule': instance.recurrenceRule,
      'parentRecurringId': instance.parentRecurringId,
      'originalScheduledTime':
          instance.originalScheduledTime?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'isTask': instance.isTask,
      'isAllDay': instance.isAllDay,
      'isRecurringInstance': instance.isRecurringInstance,
      'isCompleted': instance.isCompleted,
      'tags': instance.tags,
      'attachments': instance.attachments,
      'links': instance.links,
      'subtasks': instance.subtasks,
      'folderId': instance.folderId,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$NoteCategoryEnumMap = {
  NoteCategory.work: 'work',
  NoteCategory.personal: 'personal',
  NoteCategory.idea: 'idea',
};

const _$TaskPriorityEnumMap = {
  TaskPriority.low: 'low',
  TaskPriority.medium: 'medium',
  TaskPriority.high: 'high',
};
