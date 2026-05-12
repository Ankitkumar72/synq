import 'package:intl/intl.dart';

import 'package:synq/features/timeline/domain/models/timeline_event.dart';

class PositionedTimelineEvent {
  final TimelineEvent event;
  final double top;
  final double height;
  final double left;
  final double width;
  final int column;
  final int totalColumns;
  final int index;

  const PositionedTimelineEvent({
    required this.event,
    required this.top,
    required this.height,
    required this.left,
    required this.width,
    required this.column,
    required this.totalColumns,
    this.index = 0,
  });

  PositionedTimelineEvent copyWith({
    TimelineEvent? event,
    double? top,
    double? height,
    double? left,
    double? width,
    int? column,
    int? totalColumns,
    int? index,
  }) {
    return PositionedTimelineEvent(
      event: event ?? this.event,
      top: top ?? this.top,
      height: height ?? this.height,
      left: left ?? this.left,
      width: width ?? this.width,
      column: column ?? this.column,
      totalColumns: totalColumns ?? this.totalColumns,
      index: index ?? this.index,
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

    // 1. Convert events to ranges, handling midnight crossing
    final ranges = <_EventRange>[];
    for (final event in events) {
      final start = _parseMinutes(event.startTime);
      final end = _parseMinutes(event.endTime);

      if (end < start) {
        // Midnight crossing: Split into two visual blocks
        ranges.add(_EventRange(
          event: event,
          startMinutes: start,
          endMinutes: 1440, // End of day
          isSplit: true,
        ));
        ranges.add(_EventRange(
          event: event,
          startMinutes: 0, // Start of next day
          endMinutes: end,
          isSplit: true,
        ));
      } else {
        final safeEnd = end <= start ? start + minimumEventDurationMinutes : end;
        ranges.add(_EventRange(
          event: event,
          startMinutes: start,
          endMinutes: safeEnd,
        ));
      }
    }

    // 2. Generate slices (unique time points)
    final points = <int>{};
    for (final r in ranges) {
      points.add(r.startMinutes);
      points.add(r.endMinutes);
    }
    final sortedPoints = points.toList()..sort();
    
    final slices = <_TimeSlice>[];
    for (var i = 0; i < sortedPoints.length - 1; i++) {
      final start = sortedPoints[i];
      final end = sortedPoints[i + 1];
      final overlapping = ranges.where((r) => r.startMinutes < end && r.endMinutes > start).toList();
      slices.add(_TimeSlice(start: start, end: end, events: overlapping));
    }

    // 3. Group into Clusters
    // A cluster is a set of events that are connected by overlaps
    final clusters = <List<_EventRange>>[];
    final remainingRanges = List<_EventRange>.from(ranges);
    
    while (remainingRanges.isNotEmpty) {
      final cluster = <_EventRange>[];
      final queue = <_EventRange>[remainingRanges.removeAt(0)];
      
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        cluster.add(current);
        
        final overlaps = remainingRanges.where((other) {
          return !(current.endMinutes <= other.startMinutes || current.startMinutes >= other.endMinutes);
        }).toList();
        
        for (final o in overlaps) {
          remainingRanges.remove(o);
          queue.add(o);
        }
      }
      clusters.add(cluster);
    }

    // 4. Process each cluster
    for (final cluster in clusters) {
      // Find all unique points within this cluster
      final clusterPoints = <int>{};
      for (final r in cluster) {
        clusterPoints.add(r.startMinutes);
        clusterPoints.add(r.endMinutes);
      }
      final sortedClusterPoints = clusterPoints.toList()..sort();
      
      // Calculate max overlap specifically for this cluster
      int clusterMaxOverlap = 0;
      for (var i = 0; i < sortedClusterPoints.length - 1; i++) {
        final sStart = sortedClusterPoints[i];
        final sEnd = sortedClusterPoints[i + 1];
        final count = cluster.where((r) => r.startMinutes < sEnd && r.endMinutes > sStart).length;
        if (count > clusterMaxOverlap) clusterMaxOverlap = count;
      }

      // Assign Columns within the cluster
      cluster.sort((a, b) {
        if (a.startMinutes != b.startMinutes) {
          return a.startMinutes.compareTo(b.startMinutes);
        }
        return (b.endMinutes - b.startMinutes).compareTo(a.endMinutes - a.startMinutes);
      });

      for (final range in cluster) {
        range.maxOverlap = clusterMaxOverlap;
        
        final takenColumns = cluster.where((other) {
          if (other == range || other.column == -1) return false;
          return !(range.endMinutes <= other.startMinutes || range.startMinutes >= other.endMinutes);
        }).map((r) => r.column).toSet();
        
        var col = 0;
        while (takenColumns.contains(col)) {
          col++;
        }
        range.column = col;
      }
    }

    // 5. Dynamic Stretching (Look-ahead)
    for (final range in ranges) {
      var canExpand = true;
      var currentMaxCol = range.column;
      
      while (canExpand) {
        final targetCol = currentMaxCol + 1;
        if (targetCol >= range.maxOverlap) {
          canExpand = false;
          break;
        }

        final hasCollision = ranges.any((other) {
          if (other == range || other.column != targetCol) return false;
          return !(range.endMinutes <= other.startMinutes || range.startMinutes >= other.endMinutes);
        });
        
        if (!hasCollision) {
          currentMaxCol = targetCol;
        } else {
          canExpand = false;
        }
      }
      range.columnSpan = currentMaxCol - range.column + 1;
    }

    // 5. Build Positioned Events
    final positioned = <PositionedTimelineEvent>[];
    final eventPartCounters = <String, int>{};

    for (final range in ranges) {
      final eventId = range.event.id;
      final partIndex = eventPartCounters[eventId] ?? 0;
      eventPartCounters[eventId] = partIndex + 1;

      final columnWidth = containerWidth / range.maxOverlap;
      
      final tileLeft = (range.column * columnWidth) + horizontalGap / 2;
      final tileWidth = (range.columnSpan * columnWidth) - horizontalGap;

      final tileTop = (range.startMinutes / 60.0) * pixelsPerHour + verticalGap / 2;
      var tileHeight = ((range.endMinutes - range.startMinutes) / 60.0) * pixelsPerHour;
      
      // Edge Case: Minimum Visual Height for interaction
      if (tileHeight < minimumEventHeight) {
        tileHeight = minimumEventHeight;
      }
      tileHeight -= verticalGap;

      positioned.add(
        PositionedTimelineEvent(
          event: range.event,
          top: tileTop,
          height: tileHeight,
          left: tileLeft,
          width: tileWidth,
          column: range.column,
          totalColumns: range.maxOverlap,
          index: partIndex,
        ),
      );
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

class _TimeSlice {
  final int start;
  final int end;
  final List<_EventRange> events;

  _TimeSlice({required this.start, required this.end, required this.events});
}

class _EventRange {
  final TimelineEvent event;
  final int startMinutes;
  final int endMinutes;
  int column = -1;
  int columnSpan = 1;
  int maxOverlap = 1;
  bool isSplit = false;

  _EventRange({
    required this.event,
    required this.startMinutes,
    required this.endMinutes,
    this.isSplit = false,
  });
}
