import 'package:intl/intl.dart';

import '../../domain/models/timeline_event.dart';

class PositionedTimelineEvent {
  final TimelineEvent event;
  final double top;
  final double height;
  final double left;
  final double width;
  final int column;
  final int totalColumns;

  const PositionedTimelineEvent({
    required this.event,
    required this.top,
    required this.height,
    required this.left,
    required this.width,
    required this.column,
    required this.totalColumns,
  });

  PositionedTimelineEvent copyWith({
    TimelineEvent? event,
    double? top,
    double? height,
    double? left,
    double? width,
    int? column,
    int? totalColumns,
  }) {
    return PositionedTimelineEvent(
      event: event ?? this.event,
      top: top ?? this.top,
      height: height ?? this.height,
      left: left ?? this.left,
      width: width ?? this.width,
      column: column ?? this.column,
      totalColumns: totalColumns ?? this.totalColumns,
    );
  }
}

class TimelineLayoutEngine {
  static const double pixelsPerHour = 70.0;
  static const double minimumEventHeight = 28.0;
  static const int minimumEventDurationMinutes = 15;
  static const double horizontalGap = 4.0;
  static const double verticalGap = 2.0;
  static const double resizeHandleHeight = 10.0;

  static List<PositionedTimelineEvent> calculatePositions({
    required List<TimelineEvent> events,
    required double containerWidth,
  }) {
    if (events.isEmpty) return [];

    final ranges = <_EventRange>[];
    for (final event in events) {
      final start = _parseMinutes(event.startTime);
      final end = _parseMinutes(event.endTime);
      final safeEnd = end <= start ? start + minimumEventDurationMinutes : end;
      ranges.add(
        _EventRange(event: event, startMinutes: start, endMinutes: safeEnd),
      );
    }

    ranges.sort((a, b) {
      if (a.startMinutes != b.startMinutes) {
        return a.startMinutes.compareTo(b.startMinutes);
      }
      return b.endMinutes.compareTo(a.endMinutes);
    });

    final groups = <List<_EventRange>>[];
    List<_EventRange>? currentGroup;
    var groupEndMinutes = -1;

    for (final range in ranges) {
      if (currentGroup == null || range.startMinutes >= groupEndMinutes) {
        currentGroup = [range];
        groups.add(currentGroup);
        groupEndMinutes = range.endMinutes;
      } else {
        currentGroup.add(range);
        if (range.endMinutes > groupEndMinutes) {
          groupEndMinutes = range.endMinutes;
        }
      }
    }

    final positioned = <PositionedTimelineEvent>[];

    for (final group in groups) {
      final columns = <List<_EventRange>>[];

      for (final range in group) {
        var assignedColumn = -1;
        for (var i = 0; i < columns.length; i++) {
          if (columns[i].last.endMinutes <= range.startMinutes) {
            assignedColumn = i;
            break;
          }
        }

        if (assignedColumn == -1) {
          columns.add([range]);
          assignedColumn = columns.length - 1;
        } else {
          columns[assignedColumn].add(range);
        }

        range.column = assignedColumn;
      }

      final totalColumns = columns.length;

      // Calculate relative weights to allow events to shrink and tasks to expand
      final columnWeights = List.filled(totalColumns, 1.0);
      double totalWeight = 0;
      for (var col = 0; col < totalColumns; col++) {
        final hasTaskGroup = columns[col].any((r) => r.event.kind == EventKind.taskGroup);
        if (hasTaskGroup && totalColumns > 1) {
          columnWeights[col] = 3.0; // Give task groups 3x the space of a normal event!
        }
        totalWeight += columnWeights[col];
      }

      final columnStarts = <double>[];
      final columnWidths = <double>[];
      double currentLeft = 0;
      for (var col = 0; col < totalColumns; col++) {
        final w = (columnWeights[col] / totalWeight) * containerWidth;
        columnStarts.add(currentLeft);
        columnWidths.add(w);
        currentLeft += w;
      }

      for (final range in group) {
        var maxColumn = range.column;

        for (var col = range.column + 1; col < totalColumns; col++) {
          var hasCollision = false;
          for (final other in columns[col]) {
            final overlaps =
                !(range.endMinutes <= other.startMinutes ||
                    range.startMinutes >= other.endMinutes);
            if (overlaps) {
              hasCollision = true;
              break;
            }
          }
          if (hasCollision) break;
          maxColumn = col;
        }

        final columnSpan = maxColumn - range.column + 1;

        var tileWidth = 0.0;
        for (var c = range.column; c < range.column + columnSpan; c++) {
          tileWidth += columnWidths[c];
        }
        tileWidth -= horizontalGap;
        
        final tileLeft = columnStarts[range.column] + horizontalGap / 2;

        final tileTop =
            (range.startMinutes / 60.0) * pixelsPerHour + verticalGap / 2;

        var tileHeight =
            ((range.endMinutes - range.startMinutes) / 60.0) * pixelsPerHour;
        if (tileHeight < minimumEventHeight) tileHeight = minimumEventHeight;
        tileHeight -= verticalGap;

        // tileWidth shrinks naturally based on available columns without artificial overlap!

        positioned.add(
          PositionedTimelineEvent(
            event: range.event,
            top: tileTop,
            height: tileHeight,
            left: tileLeft,
            width: tileWidth,
            column: range.column,
            totalColumns: totalColumns,
          ),
        );
      }
    }

    positioned.sort((a, b) => a.top.compareTo(b.top));
    return positioned;
  }

  static double snapTop({
    required double rawTop,
    required double eventHeight,
    int snapMinutes = 15,
  }) {
    final pixelsPerSnap = pixelsPerHour * snapMinutes / 60.0;
    final snapped = (rawTop / pixelsPerSnap).round() * pixelsPerSnap;
    final maxTop = pixelsPerHour * 24 - eventHeight;
    return snapped.clamp(0.0, maxTop);
  }

  static String topToTime(double top) {
    final totalMinutes = (top / pixelsPerHour * 60).round().clamp(
      0,
      23 * 60 + 59,
    );
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  static double snapHeight({
    required double eventTop,
    required double rawBottom,
    int snapMinutes = 15,
  }) {
    final pixelsPerSnap = pixelsPerHour * snapMinutes / 60.0;
    final minHeight = pixelsPerHour * minimumEventDurationMinutes / 60.0;
    final maxBottom = pixelsPerHour * 24.0;
    final clampedBottom = rawBottom.clamp(eventTop + minHeight, maxBottom);
    final rawHeight = clampedBottom - eventTop;
    return (rawHeight / pixelsPerSnap).round() * pixelsPerSnap;
  }

  static int _parseMinutes(String timeStr) {
    try {
      final date = DateFormat('h:mm a').parse(timeStr.trim().toUpperCase());
      return date.hour * 60 + date.minute;
    } catch (_) {
      return 0;
    }
  }

  /// Snaps to 30-minute intervals for task chip dragging.
  static double snapTopForTask({
    required double rawTop,
    required double chipHeight,
  }) {
    return snapTop(rawTop: rawTop, eventHeight: chipHeight, snapMinutes: 30);
  }
}

class _EventRange {
  final TimelineEvent event;
  final int startMinutes;
  final int endMinutes;
  int column = 0;

  _EventRange({
    required this.event,
    required this.startMinutes,
    required this.endMinutes,
  });
}
