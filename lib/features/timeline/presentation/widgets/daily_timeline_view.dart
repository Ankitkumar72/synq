import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'package:synq/features/timeline/domain/models/timeline_event.dart';
import 'draggable_timeline_event.dart';
import 'timeline_layout_engine.dart';
import 'timeline_task_group_widget.dart';


// ---------------------------------------------------------------------------
// Callbacks for empty-slot tap
// ---------------------------------------------------------------------------
typedef EmptySlotTapCallback = void Function(String tappedTime);
typedef EventTappedCallback = void Function(TimelineEvent event);

class DailyTimelineView extends StatefulWidget {
  final List<TimelineEvent> events;
  final DateTime date;

  final EventRescheduledCallback? onEventRescheduled;
  final EventResizedCallback? onEventResized;
  final EventTappedCallback? onEventTapped;
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
  double? _liveResizeTop;
  double? _liveResizeBottom;

  TimelineEvent? _phantomEvent;
  double? _livePhantomBottom;

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

  void _onEmptySlotTap(TapUpDetails details, BoxConstraints constraints) {
    if (widget.onEmptySlotTap == null) return;
    final localY = details.localPosition.dy;
    final pixelsPerSnap = TimelineLayoutEngine.pixelsPerHour * 15 / 60.0;
    final snappedY = (localY / pixelsPerSnap).round() * pixelsPerSnap;
    final timeStr = TimelineLayoutEngine.topToTime(snappedY);
    widget.onEmptySlotTap?.call(timeStr);
  }

  void _onEmptySlotLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    final localY = details.localPosition.dy;
    final pixelsPerSnap = TimelineLayoutEngine.pixelsPerHour * 15 / 60.0;
    final snappedY = (localY / pixelsPerSnap).floorToDouble() * pixelsPerSnap;
    final timeStr = TimelineLayoutEngine.topToTime(snappedY);

    setState(() {
      _phantomEvent = TimelineEvent(
        id: 'phantom_${DateTime.now().millisecondsSinceEpoch}',
        title: 'New Event',
        startTime: timeStr,
        endTime: TimelineLayoutEngine.topToTime(
          snappedY + TimelineLayoutEngine.pixelsPerHour / 2,
        ),
        type: TimelineEventType.standard,
        kind: EventKind.event,
      );
      _livePhantomBottom = snappedY + TimelineLayoutEngine.pixelsPerHour / 2;
    });
  }

  void _onEmptySlotLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final localY = details.localPosition.dy;
    final pixelsPerSnap = TimelineLayoutEngine.pixelsPerHour * 15 / 60.0;
    final snappedY = (localY / pixelsPerSnap).roundToDouble() * pixelsPerSnap;

    final startMinutes = _parseMinutes(_phantomEvent!.startTime);
    final currentBottomMinutes = (snappedY / TimelineLayoutEngine.pixelsPerHour * 60).round();
    
    if (currentBottomMinutes > startMinutes) {
      setState(() {
        _livePhantomBottom = snappedY;
      });
    }
  }

  void _onEmptySlotLongPressEnd(LongPressEndDetails details) {
    if (_phantomEvent == null || _livePhantomBottom == null) return;
    HapticFeedback.lightImpact();
    
    final finalEnd = TimelineLayoutEngine.topToTime(_livePhantomBottom!);
    // Trigger creation sheet or directly add
    widget.onEmptySlotTap?.call(_phantomEvent!.startTime); 
    
    // Note: finalEnd is currently logged or could be passed if API allowed multiple params
    debugPrint('Created phantom event ending at: $finalEnd');
    
    setState(() {
      _phantomEvent = null;
      _livePhantomBottom = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalHeight = TimelineLayoutEngine.pixelsPerHour * 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final eventAreaWidth =
            constraints.maxWidth - widget.gutterWidth - widget.gutterPadding;

        // --- Separate tasks from events BEFORE layout ---
        final rawEvents =
            widget.events.where((e) => e.kind == EventKind.event).toList();
        final rawTasks =
            widget.events.where((e) => e.kind == EventKind.task).toList();

        // Group tasks by hour into taskGroup pseudo-events
        final taskGroups = _groupTasksByHour(rawTasks);

        // Preview events for live drag/resize reflow (events only)
        final previewEvents = _buildPreviewEvents(rawEvents);

        // Combine taskGroups and previewEvents to layout together so they share columns
        final combinedEvents = [...previewEvents, ...taskGroups];

        if (_phantomEvent != null && _livePhantomBottom != null) {
          final startMinutes = _parseMinutes(_phantomEvent!.startTime);
          var endMinutes = (_livePhantomBottom! / TimelineLayoutEngine.pixelsPerHour * 60).round();
          if (endMinutes <= startMinutes) {
            endMinutes = startMinutes + 15;
          }
          combinedEvents.add(_phantomEvent!.copyWith(
            endTime: _formatMinutes(endMinutes),
          ));
        }

        final positionedItems = TimelineLayoutEngine.calculatePositions(
          events: combinedEvents,
          containerWidth: eventAreaWidth,
        );

        final basePositioned = _activeDragEventId == null
            ? const <PositionedTimelineEvent>[]
            : TimelineLayoutEngine.calculatePositions(
                events: widget.events,
                containerWidth: eventAreaWidth,
              );

        final snapLineTop = _liveDragTop ?? _liveResizeTop ?? _liveResizeBottom;

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
                    onTapUp: (details) => _onEmptySlotTap(details, constraints),
                    onLongPressStart: _onEmptySlotLongPressStart,
                    onLongPressMoveUpdate: _onEmptySlotLongPressMoveUpdate,
                    onLongPressEnd: _onEmptySlotLongPressEnd,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        RepaintBoundary(child: _HourSlots(totalHeight: totalHeight, colorScheme: colorScheme)),
                        RepaintBoundary(child: _GridLines(totalHeight: totalHeight, colorScheme: colorScheme)),

                        RepaintBoundary(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_activeDragEventId != null)
                                ..._buildGhostTiles(basePositioned),

                              // Render Unified Items
                              ...positionedItems.map((p) {
                                if (p.event.kind == EventKind.taskGroup) {
                                  return TimelineTaskGroupWidget(
                                    key: ValueKey(p.event.id),
                                    taskGroup: p.event,
                                    top: p.top,
                                    left: p.left,
                                    width: p.width,
                                    height: TimelineLayoutEngine.pixelsPerHour.toDouble(),
                                    onTapped: widget.onEventTapped,
                                    onToggle: widget.onEventRescheduled != null 
                                      ? (task, isCompleted) => widget.onEventRescheduled!(task, task.startTime, task.endTime) // Emulating toggle
                                      : null,
                                  );
                                } else {
                                  return DraggableTimelineEvent(
                                    key: ValueKey('${p.event.id}_${p.index}'),
                                    positioned: p,
                                    onRescheduled: (event, start, end) {
                                      setState(() {
                                        _activeDragEventId = null;
                                        _liveDragTop = null;
                                        _activeResizeEventId = null;
                                        _liveResizeTop = null;
                                        _liveResizeBottom = null;
                                      });
                                      widget.onEventRescheduled?.call(event, start, end);
                                    },
                                    onResized: (event, end) {
                                      setState(() {
                                        _activeResizeEventId = null;
                                        _liveResizeTop = null;
                                        _liveResizeBottom = null;
                                        _activeDragEventId = null;
                                        _liveDragTop = null;
                                      });
                                      widget.onEventResized?.call(event, end);
                                    },
                                    onTapped: widget.onEventTapped,
                                    onDragTopChanged: (top) {
                                      setState(() {
                                        _activeDragEventId = top != null ? p.event.id : null;
                                        _liveDragTop = top;
                                      });
                                    },
                                    onResizeTopChanged: (top) {
                                      setState(() {
                                        _activeResizeEventId = top != null ? p.event.id : null;
                                        _liveResizeTop = top;
                                      });
                                    },
                                    onResizeBottomChanged: (bottom) {
                                      setState(() {
                                        _activeResizeEventId = bottom != null ? p.event.id : null;
                                        _liveResizeBottom = bottom;
                                      });
                                    },
                                  );
                                }
                              }),
                            ],
                          ),
                        ),

                        if (snapLineTop != null)
                          _SnapLine(top: snapLineTop, colorScheme: colorScheme),

                        if (_isToday())
                          ValueListenableBuilder<DateTime>(
                            valueListenable: _now,
                            builder: (_, __, ___) => _CurrentTimeLine(
                              top: _currentTimeTop(),
                              colorScheme: colorScheme,
                            ),
                          ),

                        if (_liveDragTop != null)
                          _TimeDragTooltip(
                            top: _liveDragTop!,
                            label: TimelineLayoutEngine.topToTime(_liveDragTop!),
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

  List<TimelineEvent> _buildPreviewEvents(List<TimelineEvent> original) {
    if ((_activeDragEventId == null || _liveDragTop == null) &&
        (_activeResizeEventId == null ||
            (_liveResizeTop == null && _liveResizeBottom == null))) {
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

      if (_activeResizeEventId == event.id) {
        if (_liveResizeTop != null) {
          final newStart = TimelineLayoutEngine.topToTime(_liveResizeTop!);
          final startMinutes = _parseMinutes(newStart);
          var endMinutes = _parseMinutes(event.endTime);
          if (startMinutes >= endMinutes) {
            endMinutes = startMinutes + TimelineLayoutEngine.minimumEventDurationMinutes;
          }
          return event.copyWith(
            startTime: newStart,
            endTime: _formatMinutes(endMinutes),
          );
        }

        if (_liveResizeBottom != null) {
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
      }

      return event;
    }).toList();
  }

  int _durationMinutes(String start, String end) {
    final diff = TimelineEvent.parseMinutes(end) - TimelineEvent.parseMinutes(start);
    return diff <= 0 ? TimelineLayoutEngine.minimumEventDurationMinutes : diff;
  }

  int _parseMinutes(String timeStr) => TimelineEvent.parseMinutes(timeStr);

  String _formatMinutes(int totalMinutes) {
    final safe = totalMinutes.clamp(0, 23 * 60 + 59);
    final h = safe ~/ 60;
    final m = safe % 60;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  /// Groups task events by their start-hour into taskGroup pseudo-events.
  List<TimelineEvent> _groupTasksByHour(List<TimelineEvent> tasks) {
    final Map<int, List<TimelineEvent>> hourlyTasks = {};
    for (final t in tasks) {
      final hour = _parseMinutes(t.startTime) ~/ 60;
      hourlyTasks.putIfAbsent(hour, () => []).add(t);
    }

    return [
      for (final entry in hourlyTasks.entries)
        TimelineEvent(
          id: 'task_group_${entry.key}',
          title: 'Task Group',
          startTime: _formatMinutes(entry.key * 60),
          endTime: _formatMinutes((entry.key + 1) * 60),
          type: TimelineEventType.standard,
          kind: EventKind.taskGroup,
          groupedTasks: entry.value,
        ),
    ];
  }
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
                    : const Color(0xFF94A3B8),
                fontWeight:
                    isCurrentHour ? FontWeight.bold : FontWeight.w600,
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
    final paint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    for (var hour = 0; hour <= 24; hour++) {
      final y = hour * TimelineLayoutEngine.pixelsPerHour;
      
      // Hour Line (Solid)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

      // Half-hour line (Subtle)
      if (hour < 24) {
        final midY = y + TimelineLayoutEngine.pixelsPerHour / 2;
        canvas.drawLine(Offset(0, midY), Offset(size.width, midY), dashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// _SnapLine
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
      top: top - 4,
      left: -4,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4B7BFF),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: const Color(0xFF4B7BFF).withValues(alpha: 0.8),
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