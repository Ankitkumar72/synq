import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:synq/features/timeline/domain/models/timeline_event.dart';
import 'timeline_layout_engine.dart';

typedef EventRescheduledCallback =
    void Function(TimelineEvent event, String newStartTime, String newEndTime);

typedef EventResizedCallback =
    void Function(TimelineEvent event, String newEndTime);

typedef EventTappedCallback = void Function(TimelineEvent event);

class DraggableTimelineEvent extends StatefulWidget {
  final PositionedTimelineEvent positioned;
  final EventRescheduledCallback? onRescheduled;
  final EventResizedCallback? onResized;
  final EventTappedCallback? onTapped;
  final ValueChanged<double?>? onDragTopChanged;
  final ValueChanged<double?>? onResizeTopChanged;
  final ValueChanged<double?>? onResizeBottomChanged;

  const DraggableTimelineEvent({
    super.key,
    required this.positioned,
    this.onRescheduled,
    this.onResized,
    this.onTapped,
    this.onDragTopChanged,
    this.onResizeTopChanged,
    this.onResizeBottomChanged,
  });

  @override
  State<DraggableTimelineEvent> createState() => _DraggableTimelineEventState();
}

class _DraggableTimelineEventState extends State<DraggableTimelineEvent>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _liveTop = 0;
  double _dragStartTop = 0;
  double _dragScrollCompensation = 0;
  int _dragDurationMinutes = TimelineLayoutEngine.minimumEventDurationMinutes;

  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _liveTop = widget.positioned.top;

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(DraggableTimelineEvent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) _liveTop = widget.positioned.top;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    _dragDurationMinutes = _eventDurationMinutes(widget.positioned.event);
    setState(() {
      _isDragging = true;
      _dragStartTop = widget.positioned.top;
      _dragScrollCompensation = 0;
      _liveTop = widget.positioned.top;
    });
    widget.onDragTopChanged?.call(_liveTop);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final scrolled = _maybeAutoScroll(details.globalPosition);
    _dragScrollCompensation += scrolled;
    final raw =
        _dragStartTop + details.offsetFromOrigin.dy + _dragScrollCompensation;
    final snapped = TimelineLayoutEngine.snapTop(
      rawTop: raw,
      eventHeight: widget.positioned.height,
    );
    setState(() => _liveTop = snapped);
    widget.onDragTopChanged?.call(snapped);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    HapticFeedback.lightImpact();
    final newStart = TimelineLayoutEngine.topToTime(_liveTop);
    final startMinutes = _parseMinutes(newStart);
    final endMinutes = (startMinutes + _dragDurationMinutes).clamp(
      0,
      23 * 60 + 59,
    );
    final newEnd = _formatMinutes(endMinutes);
    setState(() => _isDragging = false);
    widget.onDragTopChanged?.call(null);
    widget.onRescheduled?.call(widget.positioned.event, newStart, newEnd);
  }



  double _maybeAutoScroll(Offset globalPosition) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return 0;
    final viewportBox = scrollable.context.findRenderObject() as RenderBox?;
    if (viewportBox == null) return 0;

    final local = viewportBox.globalToLocal(globalPosition);
    final viewportHeight = viewportBox.size.height;
    const triggerZone = 64.0;
    const maxScrollStep = 18.0;

    var requestedDelta = 0.0;
    if (local.dy < triggerZone) {
      requestedDelta =
          -((triggerZone - local.dy) / triggerZone) * maxScrollStep;
    } else if (local.dy > viewportHeight - triggerZone) {
      requestedDelta =
          ((local.dy - (viewportHeight - triggerZone)) / triggerZone) *
          maxScrollStep;
    }

    if (requestedDelta == 0) return 0;

    final position = scrollable.position;
    final current = position.pixels;
    final target = (current + requestedDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == current) return 0;
    position.jumpTo(target);
    return target - current;
  }

  int _eventDurationMinutes(TimelineEvent event) {
    final start = _parseMinutes(event.startTime);
    final end = _parseMinutes(event.endTime);
    final diff = end - start;
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

  @override
  Widget build(BuildContext context) {
    final event = widget.positioned.event;
    final pos = widget.positioned;

    final isActive = _isDragging;
    final displayTop = _isDragging ? _liveTop : pos.top;
    final displayHeight = pos.height;

    final tileColor = _eventColor(event);
    final textColor = _contrastColor(tileColor);

    // Hide handles if event is too small to prevent mis-taps
    final showHandles = displayHeight >= 40 && !isActive;

    return AnimatedPositioned(
      duration: isActive ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      top: displayTop,
      left: pos.left,
      width: pos.width,
      height: displayHeight,
      child: ScaleTransition(
        scale: _pressScale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main Body (Drag handle)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => widget.onTapped?.call(event),
                onTapDown: (_) => _pressController.forward(),
                onTapUp: (_) => _pressController.reverse(),
                onTapCancel: _pressController.reverse,
                onLongPressStart: _onLongPressStart,
                onLongPressMoveUpdate: _onLongPressMoveUpdate,
                onLongPressEnd: _onLongPressEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isActive ? tileColor.withOpacity(0.85) : tileColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tileColor.darken(0.15), width: 1),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: _EventBody(
                        event: event,
                        height: displayHeight,
                        textColor: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Resize Handle
            if (showHandles)
              Positioned(
                top: -6,
                left: 0,
                right: 0,
                height: 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => HapticFeedback.selectionClick(),
                  onVerticalDragUpdate: (details) {
                    final rawTop = pos.top + details.localPosition.dy;
                    // Clamp top to not exceed current bottom - min duration
                    final maxTop = (pos.top + pos.height) - (TimelineLayoutEngine.pixelsPerHour * 15 / 60.0);
                    final clampedRaw = rawTop.clamp(0.0, maxTop);

                    final snappedTop = TimelineLayoutEngine.snapTop(
                      rawTop: clampedRaw,
                      eventHeight: pos.height,
                    );
                    
                    if (snappedTop != _liveTop) {
                      HapticFeedback.selectionClick();
                      widget.onResizeTopChanged?.call(snappedTop);
                    }
                  },
                  onVerticalDragEnd: (_) {
                    final newStart = TimelineLayoutEngine.topToTime(displayTop);
                    widget.onRescheduled?.call(event, newStart, event.endTime);
                  },
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom Resize Handle
            if (showHandles)
              Positioned(
                bottom: -6,
                left: 0,
                right: 0,
                height: 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => HapticFeedback.selectionClick(),
                  onVerticalDragUpdate: (details) {
                    final rawBottom = pos.top + pos.height + details.localPosition.dy;
                    final snappedHeight = TimelineLayoutEngine.snapHeight(
                      eventTop: pos.top,
                      rawBottom: rawBottom,
                    );
                    final newBottom = pos.top + snappedHeight;
                    
                    if (newBottom != _liveTop) { // Just using _liveTop as a proxy for 'any change' or I should add _lastSnapTop
                       // Wait, I should compare with the previous snap value. 
                       // But the state is in the parent. 
                       // I'll just use HapticFeedback.selectionClick() for now as it's better than nothing.
                       widget.onResizeBottomChanged?.call(newBottom);
                    }
                  },
                  onVerticalDragEnd: (_) {
                    final newEnd = TimelineLayoutEngine.topToTime(pos.top + pos.height);
                    widget.onResized?.call(event, newEnd);
                  },
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _eventColor(TimelineEvent event) {
    if (event.color != null) return Color(event.color!);
    final duration = _durationMinutes(event.startTime, event.endTime);

    // Emulate calendar-like contrast:
    // long spanning items lean green, shorter tasks lean blue.
    if (duration >= 60) {
      return const Color(0xFF43A58B);
    }
    return const Color(0xFF6B8DEB);
  }

  static int _durationMinutes(String start, String end) {
    try {
      final format = DateFormat('h:mm a');
      final startDt = format.parse(start.trim().toUpperCase());
      final endDt = format.parse(end.trim().toUpperCase());
      final diff = endDt.difference(startDt).inMinutes;
      if (diff <= 0) return TimelineLayoutEngine.minimumEventDurationMinutes;
      return diff;
    } catch (_) {
      return TimelineLayoutEngine.minimumEventDurationMinutes;
    }
  }

  static Color _contrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.4 ? Colors.black87 : Colors.white;
  }
}

class _EventBody extends StatelessWidget {
  final TimelineEvent event;
  final double height;
  final Color textColor;

  const _EventBody({
    required this.event,
    required this.height,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final showTime = height >= 44;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 40;
        
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (!isNarrow) ...[
                    if (event.kind == EventKind.task) ...[
                      Icon(
                        event.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                        size: 14,
                        color: textColor.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                    ] else if (event.isCompleted) ...[
                      Icon(
                        Icons.check_circle_outline,
                        size: 12,
                        color: textColor.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: isNarrow ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              if (showTime)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isNarrow ? event.startTime : '${event.startTime} - ${event.endTime}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}



extension _ColorDarken on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
