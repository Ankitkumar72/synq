import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/models/timeline_event.dart';
import 'draggable_timeline_event.dart';
import 'timeline_layout_engine.dart';
import 'timeline_task_chip.dart';

// ---------------------------------------------------------------------------
// Callbacks for empty-slot tap
// ---------------------------------------------------------------------------

typedef EmptySlotTapCallback = void Function(String tappedTime);

class DailyTimelineView extends StatefulWidget {
  final List<TimelineEvent> events;
  final DateTime date;

  final EventRescheduledCallback? onEventRescheduled;
  final EventResizedCallback? onEventResized;
  final EventTappedCallback? onEventTapped;

  /// Called when the user taps an empty slot on the timeline.
  /// Receives the snapped time string (e.g. "6:15 PM").
  final EmptySlotTapCallback? onEmptySlotTap;

  final double gutterWidth;
  final double gutterPadding;

  const DailyTimelineView({
    super.key,
    required this.events,
    required this.date,
    this.onEventRescheduled,
    this.onEventResized,
    this.onEventTapped,
    this.onEmptySlotTap,
    this.gutterWidth = 46,
    this.gutterPadding = 4,
  });

  @override
  State<DailyTimelineView> createState() => _DailyTimelineViewState();
}

class _DailyTimelineViewState extends State<DailyTimelineView> {
  late final ScrollController _scrollController;

  String? _activeDragEventId;
  double? _liveDragTop;

  String? _activeResizeEventId;
  double? _liveResizeBottom;

  // Task drag state
  String? _activeDragTaskId;
  double? _liveDragTaskTop;

  late final ValueNotifier<DateTime> _now;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _now = ValueNotifier(DateTime.now());
    _startClockTicker();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
  }

  @override
  void didUpdateWidget(DailyTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dateChanged =
        oldWidget.date.year != widget.date.year ||
        oldWidget.date.month != widget.date.month ||
        oldWidget.date.day != widget.date.day;
    if (dateChanged && _isToday()) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToCurrentHour(),
      );
    }
  }

  void _startClockTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (!mounted) return false;
      _now.value = DateTime.now();
      return true;
    });
  }

  void _scrollToCurrentHour() {
    if (!_scrollController.hasClients || !_isToday()) return;
    final now = DateTime.now();
    final targetHour = now.hour <= 1 ? 0 : now.hour - 1;
    final offset = targetHour * TimelineLayoutEngine.pixelsPerHour;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _now.dispose();
    super.dispose();
  }

  bool _isToday() {
    final now = DateTime.now();
    return widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
  }

  double _currentTimeTop() {
    final now = _now.value;
    return (now.hour + now.minute / 60.0) * TimelineLayoutEngine.pixelsPerHour;
  }

  // ---------------------------------------------------------------------------
  // Partition events vs tasks
  // ---------------------------------------------------------------------------

  List<TimelineEvent> _eventItems() =>
      widget.events.where((e) => e.kind == EventKind.event).toList();

  List<TimelineEvent> _taskItems() =>
      widget.events.where((e) => e.kind == EventKind.task).toList();

  // ---------------------------------------------------------------------------
  // Empty slot tap handler
  // ---------------------------------------------------------------------------

  void _onEmptySlotTap(TapUpDetails details, BoxConstraints constraints) {
    if (widget.onEmptySlotTap == null) return;

    // The tap Y is relative to the scrollable content (Stack), not viewport.
    final localY = details.localPosition.dy;
    // Snap to nearest 15-min slot
    final pixelsPerSnap = TimelineLayoutEngine.pixelsPerHour * 15 / 60.0;
    final snappedY = (localY / pixelsPerSnap).round() * pixelsPerSnap;
    final timeStr = TimelineLayoutEngine.topToTime(snappedY);
    widget.onEmptySlotTap?.call(timeStr);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalHeight = TimelineLayoutEngine.pixelsPerHour * 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final eventAreaWidth =
            constraints.maxWidth - widget.gutterWidth - widget.gutterPadding;

        // --- Partition ---
        final events = _eventItems();
        final tasks = _taskItems();

        // --- Event layout (only events go through the engine) ---
        final previewEvents = _buildPreviewEvents(events);
        final positioned = TimelineLayoutEngine.calculatePositions(
          events: previewEvents,
          containerWidth: eventAreaWidth,
        );
        final basePositioned = _activeDragEventId == null
            ? const <PositionedTimelineEvent>[]
            : TimelineLayoutEngine.calculatePositions(
                events: events,
                containerWidth: eventAreaWidth,
              );

        // --- Task chip positions (grouped by hour, stacked by index) ---
        final taskChips = _buildTaskChipData(tasks, eventAreaWidth);

        // --- Active drag snap line position ---
        final snapLineTop = _liveDragTop ?? _liveDragTaskTop;

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: totalHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: widget.gutterWidth,
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: _now,
                      builder: (context, now, child) {
                        return _HourGutter(
                          totalHeight: totalHeight,
                          colorScheme: colorScheme,
                          now: now,
                          isToday: _isToday(),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: widget.gutterPadding),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) =>
                          _onEmptySlotTap(details, constraints),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _HourSlots(
                            totalHeight: totalHeight,
                            colorScheme: colorScheme,
                          ),
                          _GridLines(
                            totalHeight: totalHeight,
                            colorScheme: colorScheme,
                          ),

                          // Ghost tile (original slot while event is dragging)
                          if (_activeDragEventId != null)
                            ..._buildGhostTiles(basePositioned),

                          // Event tiles (full blocks)
                          ...positioned.map(
                            (p) => DraggableTimelineEvent(
                              key: ValueKey(p.event.id),
                              positioned: p,
                              onRescheduled: (event, start, end) {
                                setState(() {
                                  _activeDragEventId = null;
                                  _liveDragTop = null;
                                });
                                widget.onEventRescheduled?.call(
                                  event,
                                  start,
                                  end,
                                );
                              },
                              onResized: (event, end) {
                                setState(() {
                                  _activeResizeEventId = null;
                                  _liveResizeBottom = null;
                                });
                                widget.onEventResized?.call(event, end);
                              },
                              onTapped: widget.onEventTapped,
                              onDragTopChanged: (top) {
                                setState(() {
                                  _activeDragEventId = top != null
                                      ? p.event.id
                                      : null;
                                  _liveDragTop = top;
                                });
                              },
                              onResizeBottomChanged: (bottom) {
                                setState(() {
                                  _activeResizeEventId = bottom != null
                                      ? p.event.id
                                      : null;
                                  _liveResizeBottom = bottom;
                                });
                              },
                            ),
                          ),

                          // Task chips (separate pipeline)
                          ...taskChips.map(
                            (tc) => TimelineTaskChip(
                              key: ValueKey('chip_${tc.task.id}'),
                              task: tc.task,
                              top: tc.top,
                              width: eventAreaWidth,
                              onRescheduled: (task, start, end) {
                                setState(() {
                                  _activeDragTaskId = null;
                                  _liveDragTaskTop = null;
                                });
                                widget.onEventRescheduled?.call(
                                  task,
                                  start,
                                  end,
                                );
                              },
                              onTapped: widget.onEventTapped,
                              onDragTopChanged: (top) {
                                setState(() {
                                  _activeDragTaskId = top != null
                                      ? tc.task.id
                                      : null;
                                  _liveDragTaskTop = top;
                                });
                              },
                            ),
                          ),

                          // Horizontal snap line during drag
                          if (snapLineTop != null)
                            _SnapLine(
                              top: snapLineTop,
                              colorScheme: colorScheme,
                            ),

                          // Current-time indicator (today only)
                          if (_isToday())
                            ValueListenableBuilder<DateTime>(
                              valueListenable: _now,
                              builder: (_, __, ___) => _CurrentTimeLine(
                                top: _currentTimeTop(),
                                colorScheme: colorScheme,
                              ),
                            ),

                          // Live drag tooltip (time label above dragged tile)
                          if (_liveDragTop != null)
                            _TimeDragTooltip(
                              top: _liveDragTop!,
                              label: TimelineLayoutEngine.topToTime(
                                _liveDragTop!,
                              ),
                              colorScheme: colorScheme,
                            ),

                          // Live drag tooltip for task chip
                          if (_liveDragTaskTop != null)
                            _TimeDragTooltip(
                              top: _liveDragTaskTop!,
                              label: TimelineLayoutEngine.topToTime(
                                _liveDragTaskTop!,
                              ),
                              colorScheme: colorScheme,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Task chip positioning — group by hour, stack by index within hour
  // ---------------------------------------------------------------------------

  List<_TaskChipData> _buildTaskChipData(
    List<TimelineEvent> tasks,
    double availableWidth,
  ) {
    // Group tasks by their start hour
    final Map<int, List<TimelineEvent>> byHour = {};
    for (final task in tasks) {
      final minutes = _parseMinutes(task.startTime);
      final hour = minutes ~/ 60;
      byHour.putIfAbsent(hour, () => []).add(task);
    }

    final result = <_TaskChipData>[];
    for (final entry in byHour.entries) {
      final hourTasks = entry.value;
      for (int i = 0; i < hourTasks.length; i++) {
        final task = hourTasks[i];

        // If this task is actively being dragged, use the live top
        double top;
        if (_activeDragTaskId == task.id && _liveDragTaskTop != null) {
          top = _liveDragTaskTop!;
        } else {
          // Anchor at start time + stacking offset within the hour
          final minutes = _parseMinutes(task.startTime);
          top =
              (minutes / 60.0) * TimelineLayoutEngine.pixelsPerHour +
              TimelineLayoutEngine.verticalGap / 2 +
              i * TimelineTaskChip.chipStepHeight;
        }

        result.add(_TaskChipData(task: task, top: top));
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Ghost tile builder (for events only)
  // ---------------------------------------------------------------------------

  List<Widget> _buildGhostTiles(List<PositionedTimelineEvent> positioned) {
    return positioned
        .where((p) => p.event.id == _activeDragEventId)
        .map(
          (p) => Positioned(
            top: p.top,
            left: p.left,
            width: p.width,
            height: p.height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Preview events — apply live drag/resize positions for reflow
  // ---------------------------------------------------------------------------

  List<TimelineEvent> _buildPreviewEvents(List<TimelineEvent> original) {
    if ((_activeDragEventId == null || _liveDragTop == null) &&
        (_activeResizeEventId == null || _liveResizeBottom == null)) {
      return original;
    }

    return original.map((event) {
      if (_activeDragEventId == event.id && _liveDragTop != null) {
        final duration = _durationMinutes(event.startTime, event.endTime);
        final newStart = TimelineLayoutEngine.topToTime(_liveDragTop!);
        final startMinutes = _parseMinutes(newStart);
        final endMinutes = (startMinutes + duration).clamp(0, 23 * 60 + 59);
        return event.copyWith(
          startTime: newStart,
          endTime: _formatMinutes(endMinutes),
        );
      }

      if (_activeResizeEventId == event.id && _liveResizeBottom != null) {
        final startMinutes = _parseMinutes(event.startTime);
        var endMinutes = _parseMinutes(
          TimelineLayoutEngine.topToTime(_liveResizeBottom!),
        );
        if (endMinutes <= startMinutes) {
          endMinutes =
              startMinutes + TimelineLayoutEngine.minimumEventDurationMinutes;
        }
        endMinutes = endMinutes.clamp(0, 23 * 60 + 59);
        return event.copyWith(endTime: _formatMinutes(endMinutes));
      }

      return event;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Time helpers
  // ---------------------------------------------------------------------------

  int _durationMinutes(String start, String end) {
    final startMinutes = _parseMinutes(start);
    final endMinutes = _parseMinutes(end);
    final diff = endMinutes - startMinutes;
    if (diff <= 0) return TimelineLayoutEngine.minimumEventDurationMinutes;
    return diff;
  }

  int _parseMinutes(String timeStr) {
    try {
      final dt = DateFormat('h:mm a').parse(timeStr.trim().toUpperCase());
      return dt.hour * 60 + dt.minute;
    } catch (_) {
      return 0;
    }
  }

  String _formatMinutes(int totalMinutes) {
    final safe = totalMinutes.clamp(0, 23 * 60 + 59);
    final h = safe ~/ 60;
    final m = safe % 60;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }
}

// ---------------------------------------------------------------------------
// Helper class for task chip positioning
// ---------------------------------------------------------------------------

class _TaskChipData {
  final TimelineEvent task;
  final double top;

  const _TaskChipData({required this.task, required this.top});
}

// ---------------------------------------------------------------------------
// _HourGutter
// ---------------------------------------------------------------------------

class _HourGutter extends StatelessWidget {
  final double totalHeight;
  final ColorScheme colorScheme;
  final DateTime now;
  final bool isToday;

  const _HourGutter({
    required this.totalHeight,
    required this.colorScheme,
    required this.now,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: List.generate(24, (hour) {
          final top = hour * TimelineLayoutEngine.pixelsPerHour;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final amPm = hour < 12 ? 'am' : 'pm';
          final label = '$displayHour $amPm';

          // Skip 12 am to keep it clean like the design
          if (hour == 0) return const SizedBox.shrink();

          final isCurrentHour = isToday && now.hour == hour;

          return Positioned(
            top: top - 7,
            left: 4,
            right: 0,
            child: Text(
              label,
              textAlign: TextAlign.left,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: isCurrentHour
                    ? const Color(0xFF4B7BFF)
                    : const Color(0xFF94A3B8), // Slate grey
                fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GridLines
// ---------------------------------------------------------------------------

class _GridLines extends StatelessWidget {
  final double totalHeight;
  final ColorScheme colorScheme;

  const _GridLines({required this.totalHeight, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, totalHeight),
      painter: _GridPainter(colorScheme: colorScheme),
    );
  }
}

// ---------------------------------------------------------------------------
// _HourSlots
// ---------------------------------------------------------------------------

class _HourSlots extends StatelessWidget {
  final double totalHeight;
  final ColorScheme colorScheme;

  const _HourSlots({required this.totalHeight, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: List.generate(24, (hour) {
          final top = hour * TimelineLayoutEngine.pixelsPerHour + 1;
          return Positioned(
            top: top,
            left: 0,
            right: 0,
            height: TimelineLayoutEngine.pixelsPerHour - 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GridPainter
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  final ColorScheme colorScheme;

  _GridPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    // Hidden to match the clean card look in design 1
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// _SnapLine — horizontal guide shown during drag
// ---------------------------------------------------------------------------

class _SnapLine extends StatelessWidget {
  final double top;
  final ColorScheme colorScheme;

  const _SnapLine({required this.top, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: 1.5,
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CurrentTimeLine
// ---------------------------------------------------------------------------

class _CurrentTimeLine extends StatelessWidget {
  final double top;
  final ColorScheme colorScheme;

  const _CurrentTimeLine({required this.top, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top - 4, // Center the 8px dot exactly on the current time
      left: -4, // Shift left so the center of the dot hits the card's edge
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4B7BFF), // Deep blue matching the active block
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: const Color(0xFF4B7BFF).withValues(alpha: 0.8), // Faint blue line
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TimeDragTooltip
// ---------------------------------------------------------------------------

class _TimeDragTooltip extends StatelessWidget {
  final double top;
  final String label;
  final ColorScheme colorScheme;

  const _TimeDragTooltip({
    required this.top,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top - 24,
      left: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onInverseSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
