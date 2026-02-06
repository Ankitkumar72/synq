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
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
          TaskPriority.medium,
      isTask: json['isTask'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$$NoteImplToJson(_$NoteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'category': _$NoteCategoryEnumMap[instance.category]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'dueDate': instance.dueDate?.toIso8601String(),
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'isTask': instance.isTask,
      'isCompleted': instance.isCompleted,
      'tags': instance.tags,
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
