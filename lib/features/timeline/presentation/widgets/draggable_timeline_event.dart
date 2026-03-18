import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/models/timeline_event.dart';
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
  final ValueChanged<double?>? onResizeBottomChanged;

  const DraggableTimelineEvent({
    super.key,
    required this.positioned,
    this.onRescheduled,
    this.onResized,
    this.onTapped,
    this.onDragTopChanged,
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

  bool _isResizing = false;
  double _liveHeight = 0;

  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _liveTop = widget.positioned.top;
    _liveHeight = widget.positioned.height;

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
    if (!_isResizing) _liveHeight = widget.positioned.height;
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
      eventHeight: _liveHeight,
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

  void _onResizePanStart(DragStartDetails details) {
    HapticFeedback.selectionClick();
    setState(() {
      _isResizing = true;
      _liveHeight = widget.positioned.height;
    });
    widget.onResizeBottomChanged?.call(_liveTop + _liveHeight);
  }

  void _onResizePanUpdate(DragUpdateDetails details) {
    final scrolled = _maybeAutoScroll(details.globalPosition);
    final rawBottom = _liveTop + _liveHeight + details.delta.dy + scrolled;
    final snapped = TimelineLayoutEngine.snapHeight(
      eventTop: _liveTop,
      rawBottom: rawBottom,
    );
    setState(() => _liveHeight = snapped);
    widget.onResizeBottomChanged?.call(_liveTop + _liveHeight);
  }

  void _onResizePanEnd(DragEndDetails details) {
    HapticFeedback.lightImpact();
    final newEnd = TimelineLayoutEngine.topToTime(_liveTop + _liveHeight);
    setState(() => _isResizing = false);
    widget.onResizeBottomChanged?.call(null);
    widget.onResized?.call(widget.positioned.event, newEnd);
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

    final isActive = _isDragging || _isResizing;
    final displayTop = _isDragging ? _liveTop : pos.top;
    final displayHeight = _isResizing ? _liveHeight : pos.height;

    final tileColor = _eventColor(event);
    final textColor = _contrastColor(tileColor);

    return AnimatedPositioned(
      duration: isActive ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      top: displayTop,
      left: pos.left,
      width: pos.width,
      height: displayHeight,
      child: ScaleTransition(
        scale: _pressScale,
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
              color: isActive ? tileColor.withValues(alpha: 0.85) : tileColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tileColor.darken(0.15), width: 1),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                      child: _EventBody(
                        event: event,
                        height: displayHeight,
                        textColor: textColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _onResizePanStart,
                    onVerticalDragUpdate: _onResizePanUpdate,
                    onVerticalDragEnd: _onResizePanEnd,
                    child: _ResizeHandle(
                      color: textColor.withValues(alpha: 0.5),
                      isActive: _isResizing,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
          children: [
            if (event.isCompleted) ...[
              Icon(
                Icons.check_circle_outline,
                size: 12,
                color: textColor.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                event.title,
                maxLines: height < 44 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        if (showTime)
          Text(
            '${event.startTime} - ${event.endTime}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final Color color;
  final bool isActive;

  const _ResizeHandle({required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineLayoutEngine.resizeHandleHeight,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 32 : 24,
          height: 3,
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.9)
                : color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
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
