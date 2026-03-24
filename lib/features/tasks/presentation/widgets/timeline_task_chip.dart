import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../timeline/domain/models/timeline_event.dart';
import '../../../timeline/presentation/widgets/timeline_layout_engine.dart';

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------

typedef TaskRescheduledCallback =
    void Function(TimelineEvent task, String newStartTime, String newEndTime);

typedef TaskTappedCallback = void Function(TimelineEvent task);
typedef TaskToggleCallback = void Function(TimelineEvent task);

class TimelineTaskChip extends StatefulWidget {
  final TimelineEvent task;

  /// Vertical offset = hour-top + (indexInHour * chipStepHeight)
  final double top;
  final double left;
  final double width;

  final TaskRescheduledCallback? onRescheduled;
  final TaskTappedCallback? onTapped;
  final TaskToggleCallback? onToggle;

  /// Called while dragging so the parent can show a snap line.
  final ValueChanged<double?>? onDragTopChanged;

  static const double chipHeight = 32.0;
  static const double chipStepHeight = 34.0; // chip + 2px gap

  const TimelineTaskChip({
    super.key,
    required this.task,
    required this.top,
    required this.left,
    required this.width,
    this.onRescheduled,
    this.onTapped,
    this.onToggle,
    this.onDragTopChanged,
  });

  @override
  State<TimelineTaskChip> createState() => _TimelineTaskChipState();
}

class _TimelineTaskChipState extends State<TimelineTaskChip> {
  bool _isDragging = false;
  double _liveTop = 0;
  double _dragStartTop = 0;
  double _dragScrollCompensation = 0;

  @override
  void initState() {
    super.initState();
    _liveTop = widget.top;
  }

  @override
  void didUpdateWidget(TimelineTaskChip old) {
    super.didUpdateWidget(old);
    if (!_isDragging) _liveTop = widget.top;
  }

  // ---------------------------------------------------------------------------
  // Drag handlers (30-min snap)
  // ---------------------------------------------------------------------------

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDragging = true;
      _dragStartTop = widget.top;
      _dragScrollCompensation = 0;
      _liveTop = widget.top;
    });
    widget.onDragTopChanged?.call(_liveTop);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final scrolled = _maybeAutoScroll(details.globalPosition);
    _dragScrollCompensation += scrolled;
    final raw =
        _dragStartTop + details.offsetFromOrigin.dy + _dragScrollCompensation;
    final snapped = TimelineLayoutEngine.snapTopForTask(
      rawTop: raw,
      chipHeight: TimelineTaskChip.chipHeight,
    );
    setState(() => _liveTop = snapped);
    widget.onDragTopChanged?.call(snapped);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    HapticFeedback.lightImpact();
    final newStart = TimelineLayoutEngine.topToTime(_liveTop);
    // Tasks keep their original duration
    final duration = _taskDurationMinutes(widget.task);
    final startMin = _parseMinutes(newStart);
    final endMin = (startMin + duration).clamp(0, 23 * 60 + 59);
    final newEnd = _formatMinutes(endMin);
    setState(() => _isDragging = false);
    widget.onDragTopChanged?.call(null);
    widget.onRescheduled?.call(widget.task, newStart, newEnd);
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final completed = task.isCompleted;
    final displayTop = _isDragging ? _liveTop : widget.top;

    final chipColor = _chipColor(task, completed);
    final textColor = _chipTextColor(task, completed);

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      top: displayTop,
      left: widget.left,
      height: TimelineTaskChip.chipHeight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.width),
        child: GestureDetector(
          onTap: () => widget.onTapped?.call(task),
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _chipBorderColor(task, completed),
                width: 1,
              ),
              boxShadow: _isDragging
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => widget.onToggle?.call(task),
                  child: Icon(
                    completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: completed ? TextDecoration.lineThrough : null,
                      decorationColor: textColor,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Color helpers
  // ---------------------------------------------------------------------------

  static Color _chipColor(TimelineEvent task, bool completed) {
    if (task.color != null) {
      final base = Color(task.color!);
      return completed
          ? base.withValues(alpha: 0.25)
          : base.withValues(alpha: 0.15);
    }
    return completed ? const Color(0xFFE8E8E8) : const Color(0xFFE8EAF6);
  }

  static Color _chipBorderColor(TimelineEvent task, bool completed) {
    if (task.color != null) {
      final base = Color(task.color!);
      return completed
          ? base.withValues(alpha: 0.3)
          : base.withValues(alpha: 0.4);
    }
    return completed ? const Color(0xFFD0D0D0) : const Color(0xFFC5CAE9);
  }

  static Color _chipTextColor(TimelineEvent task, bool completed) {
    if (task.color != null) {
      final base = Color(task.color!);
      final luminance = base.computeLuminance();
      final darkVariant = luminance > 0.5
          ? HSLColor.fromColor(base).withLightness(0.25).toColor()
          : base;
      return completed ? darkVariant.withValues(alpha: 0.5) : darkVariant;
    }
    return completed ? const Color(0xFF9E9E9E) : const Color(0xFF3949AB);
  }

  // ---------------------------------------------------------------------------
  // Time helpers
  // ---------------------------------------------------------------------------

  int _taskDurationMinutes(TimelineEvent task) {
    final start = _parseMinutes(task.startTime);
    final end = _parseMinutes(task.endTime);
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
}
