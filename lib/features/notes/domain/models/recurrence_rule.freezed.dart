// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurrence_rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RecurrenceRule _$RecurrenceRuleFromJson(Map<String, dynamic> json) {
  return _RecurrenceRule.fromJson(json);
}

/// @nodoc
mixin _$RecurrenceRule {
  int get interval => throw _privateConstructorUsedError;
  RecurrenceUnit get unit => throw _privateConstructorUsedError;
  RecurrenceEndType get endType => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  int? get occurrenceCount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RecurrenceRuleCopyWith<RecurrenceRule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurrenceRuleCopyWith<$Res> {
  factory $RecurrenceRuleCopyWith(
          RecurrenceRule value, $Res Function(RecurrenceRule) then) =
      _$RecurrenceRuleCopyWithImpl<$Res, RecurrenceRule>;
  @useResult
  $Res call(
      {int interval,
      RecurrenceUnit unit,
      RecurrenceEndType endType,
      DateTime? endDate,
      int? occurrenceCount});
}

/// @nodoc
class _$RecurrenceRuleCopyWithImpl<$Res, $Val extends RecurrenceRule>
    implements $RecurrenceRuleCopyWith<$Res> {
  _$RecurrenceRuleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? interval = null,
    Object? unit = null,
    Object? endType = null,
    Object? endDate = freezed,
    Object? occurrenceCount = freezed,
  }) {
    return _then(_value.copyWith(
      interval: null == interval
          ? _value.interval
          : interval // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as RecurrenceUnit,
      endType: null == endType
          ? _value.endType
          : endType // ignore: cast_nullable_to_non_nullable
              as RecurrenceEndType,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      occurrenceCount: freezed == occurrenceCount
          ? _value.occurrenceCount
          : occurrenceCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecurrenceRuleImplCopyWith<$Res>
    implements $RecurrenceRuleCopyWith<$Res> {
  factory _$$RecurrenceRuleImplCopyWith(_$RecurrenceRuleImpl value,
          $Res Function(_$RecurrenceRuleImpl) then) =
      __$$RecurrenceRuleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int interval,
      RecurrenceUnit unit,
      RecurrenceEndType endType,
      DateTime? endDate,
      int? occurrenceCount});
}

/// @nodoc
class __$$RecurrenceRuleImplCopyWithImpl<$Res>
    extends _$RecurrenceRuleCopyWithImpl<$Res, _$RecurrenceRuleImpl>
    implements _$$RecurrenceRuleImplCopyWith<$Res> {
  __$$RecurrenceRuleImplCopyWithImpl(
      _$RecurrenceRuleImpl _value, $Res Function(_$RecurrenceRuleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? interval = null,
    Object? unit = null,
    Object? endType = null,
    Object? endDate = freezed,
    Object? occurrenceCount = freezed,
  }) {
    return _then(_$RecurrenceRuleImpl(
      interval: null == interval
          ? _value.interval
          : interval // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as RecurrenceUnit,
      endType: null == endType
          ? _value.endType
          : endType // ignore: cast_nullable_to_non_nullable
              as RecurrenceEndType,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      occurrenceCount: freezed == occurrenceCount
          ? _value.occurrenceCount
          : occurrenceCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RecurrenceRuleImpl implements _RecurrenceRule {
  const _$RecurrenceRuleImpl(
      {required this.interval,
      required this.unit,
      required this.endType,
      this.endDate,
      this.occurrenceCount});

  factory _$RecurrenceRuleImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecurrenceRuleImplFromJson(json);

  @override
  final int interval;
  @override
  final RecurrenceUnit unit;
  @override
  final RecurrenceEndType endType;
  @override
  final DateTime? endDate;
  @override
  final int? occurrenceCount;

  @override
  String toString() {
    return 'RecurrenceRule(interval: $interval, unit: $unit, endType: $endType, endDate: $endDate, occurrenceCount: $occurrenceCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurrenceRuleImpl &&
            (identical(other.interval, interval) ||
                other.interval == interval) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.endType, endType) || other.endType == endType) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.occurrenceCount, occurrenceCount) ||
                other.occurrenceCount == occurrenceCount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, interval, unit, endType, endDate, occurrenceCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurrenceRuleImplCopyWith<_$RecurrenceRuleImpl> get copyWith =>
      __$$RecurrenceRuleImplCopyWithImpl<_$RecurrenceRuleImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecurrenceRuleImplToJson(
      this,
    );
  }
}

abstract class _RecurrenceRule implements RecurrenceRule {
  const factory _RecurrenceRule(
      {required final int interval,
      required final RecurrenceUnit unit,
      required final RecurrenceEndType endType,
      final DateTime? endDate,
      final int? occurrenceCount}) = _$RecurrenceRuleImpl;

  factory _RecurrenceRule.fromJson(Map<String, dynamic> json) =
      _$RecurrenceRuleImpl.fromJson;

  @override
  int get interval;
  @override
  RecurrenceUnit get unit;
  @override
  RecurrenceEndType get endType;
  @override
  DateTime? get endDate;
  @override
  int? get occurrenceCount;
  @override
  @JsonKey(ignore: true)
  _$$RecurrenceRuleImplCopyWith<_$RecurrenceRuleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
