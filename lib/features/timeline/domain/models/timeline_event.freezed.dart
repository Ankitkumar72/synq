// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timeline_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TimelineEvent {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get startTime => throw _privateConstructorUsedError;
  String get endTime => throw _privateConstructorUsedError;
  TimelineEventType get type => throw _privateConstructorUsedError;
  String? get subtitle => throw _privateConstructorUsedError;
  String? get tag => throw _privateConstructorUsedError;
  String? get category =>
      throw _privateConstructorUsedError; // E.g., "Personal", "Work"
  bool get isCompleted => throw _privateConstructorUsedError;
  bool get isCurrent => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TimelineEventCopyWith<TimelineEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimelineEventCopyWith<$Res> {
  factory $TimelineEventCopyWith(
          TimelineEvent value, $Res Function(TimelineEvent) then) =
      _$TimelineEventCopyWithImpl<$Res, TimelineEvent>;
  @useResult
  $Res call(
      {String id,
      String title,
      String startTime,
      String endTime,
      TimelineEventType type,
      String? subtitle,
      String? tag,
      String? category,
      bool isCompleted,
      bool isCurrent});
}

/// @nodoc
class _$TimelineEventCopyWithImpl<$Res, $Val extends TimelineEvent>
    implements $TimelineEventCopyWith<$Res> {
  _$TimelineEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? type = null,
    Object? subtitle = freezed,
    Object? tag = freezed,
    Object? category = freezed,
    Object? isCompleted = null,
    Object? isCurrent = null,
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
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TimelineEventType,
      subtitle: freezed == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String?,
      tag: freezed == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      isCurrent: null == isCurrent
          ? _value.isCurrent
          : isCurrent // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TimelineEventImplCopyWith<$Res>
    implements $TimelineEventCopyWith<$Res> {
  factory _$$TimelineEventImplCopyWith(
          _$TimelineEventImpl value, $Res Function(_$TimelineEventImpl) then) =
      __$$TimelineEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String startTime,
      String endTime,
      TimelineEventType type,
      String? subtitle,
      String? tag,
      String? category,
      bool isCompleted,
      bool isCurrent});
}

/// @nodoc
class __$$TimelineEventImplCopyWithImpl<$Res>
    extends _$TimelineEventCopyWithImpl<$Res, _$TimelineEventImpl>
    implements _$$TimelineEventImplCopyWith<$Res> {
  __$$TimelineEventImplCopyWithImpl(
      _$TimelineEventImpl _value, $Res Function(_$TimelineEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? type = null,
    Object? subtitle = freezed,
    Object? tag = freezed,
    Object? category = freezed,
    Object? isCompleted = null,
    Object? isCurrent = null,
  }) {
    return _then(_$TimelineEventImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TimelineEventType,
      subtitle: freezed == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String?,
      tag: freezed == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      isCurrent: null == isCurrent
          ? _value.isCurrent
          : isCurrent // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TimelineEventImpl implements _TimelineEvent {
  const _$TimelineEventImpl(
      {required this.id,
      required this.title,
      required this.startTime,
      required this.endTime,
      required this.type,
      this.subtitle,
      this.tag,
      this.category,
      this.isCompleted = false,
      this.isCurrent = false});

  @override
  final String id;
  @override
  final String title;
  @override
  final String startTime;
  @override
  final String endTime;
  @override
  final TimelineEventType type;
  @override
  final String? subtitle;
  @override
  final String? tag;
  @override
  final String? category;
// E.g., "Personal", "Work"
  @override
  @JsonKey()
  final bool isCompleted;
  @override
  @JsonKey()
  final bool isCurrent;

  @override
  String toString() {
    return 'TimelineEvent(id: $id, title: $title, startTime: $startTime, endTime: $endTime, type: $type, subtitle: $subtitle, tag: $tag, category: $category, isCompleted: $isCompleted, isCurrent: $isCurrent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimelineEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.tag, tag) || other.tag == tag) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.isCurrent, isCurrent) ||
                other.isCurrent == isCurrent));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title, startTime, endTime,
      type, subtitle, tag, category, isCompleted, isCurrent);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TimelineEventImplCopyWith<_$TimelineEventImpl> get copyWith =>
      __$$TimelineEventImplCopyWithImpl<_$TimelineEventImpl>(this, _$identity);
}

abstract class _TimelineEvent implements TimelineEvent {
  const factory _TimelineEvent(
      {required final String id,
      required final String title,
      required final String startTime,
      required final String endTime,
      required final TimelineEventType type,
      final String? subtitle,
      final String? tag,
      final String? category,
      final bool isCompleted,
      final bool isCurrent}) = _$TimelineEventImpl;

  @override
  String get id;
  @override
  String get title;
  @override
  String get startTime;
  @override
  String get endTime;
  @override
  TimelineEventType get type;
  @override
  String? get subtitle;
  @override
  String? get tag;
  @override
  String? get category;
  @override // E.g., "Personal", "Work"
  bool get isCompleted;
  @override
  bool get isCurrent;
  @override
  @JsonKey(ignore: true)
  _$$TimelineEventImplCopyWith<_$TimelineEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
