import 'package:freezed_annotation/freezed_annotation.dart';

part 'recurrence_rule.freezed.dart';
part 'recurrence_rule.g.dart';

enum RecurrenceUnit {
  day,
  week,
  month,
  year,
}

enum RecurrenceEndType {
  never,
  onDate,
  afterCount,
}

@freezed
class RecurrenceRule with _$RecurrenceRule {
  const factory RecurrenceRule({
    required int interval,
    required RecurrenceUnit unit,
    required RecurrenceEndType endType,
    DateTime? endDate,
    int? occurrenceCount,
  }) = _RecurrenceRule;

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => _$RecurrenceRuleFromJson(json);
}
