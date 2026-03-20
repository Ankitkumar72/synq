// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecurrenceRuleImpl _$$RecurrenceRuleImplFromJson(Map<String, dynamic> json) =>
    _$RecurrenceRuleImpl(
      interval: (json['interval'] as num).toInt(),
      unit: $enumDecode(_$RecurrenceUnitEnumMap, json['unit']),
      endType: $enumDecode(_$RecurrenceEndTypeEnumMap, json['endType']),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      occurrenceCount: (json['occurrenceCount'] as num?)?.toInt(),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$$RecurrenceRuleImplToJson(
        _$RecurrenceRuleImpl instance) =>
    <String, dynamic>{
      'interval': instance.interval,
      'unit': _$RecurrenceUnitEnumMap[instance.unit]!,
      'endType': _$RecurrenceEndTypeEnumMap[instance.endType]!,
      'endDate': instance.endDate?.toIso8601String(),
      'occurrenceCount': instance.occurrenceCount,
      'daysOfWeek': instance.daysOfWeek,
    };

const _$RecurrenceUnitEnumMap = {
  RecurrenceUnit.day: 'day',
  RecurrenceUnit.week: 'week',
  RecurrenceUnit.month: 'month',
  RecurrenceUnit.year: 'year',
};

const _$RecurrenceEndTypeEnumMap = {
  RecurrenceEndType.never: 'never',
  RecurrenceEndType.onDate: 'onDate',
  RecurrenceEndType.afterCount: 'afterCount',
};
