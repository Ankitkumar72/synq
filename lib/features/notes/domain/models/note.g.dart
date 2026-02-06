// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
          TaskPriority.medium,
      isTask: json['isTask'] as bool? ?? false,
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
      'completedAt': instance.completedAt?.toIso8601String(),
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'isTask': instance.isTask,
      'isCompleted': instance.isCompleted,
      'tags': instance.tags,
      'attachments': instance.attachments,
      'links': instance.links,
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
