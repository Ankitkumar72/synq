import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notes/domain/models/recurrence_rule.dart';

class RepeatSettingsResult {
  const RepeatSettingsResult({
    required this.rule,
  });

  final RecurrenceRule? rule;
}

class RepeatSettingsScreen extends StatefulWidget {
  const RepeatSettingsScreen({
    super.key,
    required this.initialRule,
    required this.startsAt,
  });

  final RecurrenceRule? initialRule;
  final DateTime startsAt;

  @override
  State<RepeatSettingsScreen> createState() => _RepeatSettingsScreenState();
}

class _RepeatSettingsScreenState extends State<RepeatSettingsScreen> {
  late final TextEditingController _intervalController;
  late final TextEditingController _afterCountController;

  late RecurrenceUnit _selectedUnit;
  late RecurrenceEndType _selectedEndType;
  late DateTime _startsAt;
  late DateTime _endDate;
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(
      text: (widget.initialRule?.interval ?? 1).toString(),
    );
    _afterCountController = TextEditingController(
      text: (widget.initialRule?.occurrenceCount ?? 10).toString(),
    );
    _selectedUnit = widget.initialRule?.unit ?? RecurrenceUnit.week;
    _selectedEndType = widget.initialRule?.endType ?? RecurrenceEndType.never;
    _startsAt = widget.startsAt;
    _endDate = widget.initialRule?.endDate ?? 
               DateTime(widget.startsAt.year, widget.startsAt.month + 1, widget.startsAt.day);
    
    _selectedDays = widget.initialRule?.daysOfWeek?.toSet() ?? {widget.startsAt.weekday};
  }

  @override
  void didUpdateWidget(RepeatSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startsAt != oldWidget.startsAt && widget.initialRule == null) {
      setState(() {
        _startsAt = widget.startsAt;
      });
    }
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _afterCountController.dispose();
    super.dispose();
  }

  Future<void> _pickStartsDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  Future<void> _pickStartsTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
      helpText: 'Set start time',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startsAt) ? _startsAt : _endDate,
      firstDate: _startsAt,
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = picked;
      _selectedEndType = RecurrenceEndType.onDate;
    });
  }

  Future<void> _pickAfterCount() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _AfterCountDialog(initialValue: _afterCountController.text),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _afterCountController.text = '$selected';
      _selectedEndType = RecurrenceEndType.afterCount;
    });
  }


  void _applyAndClose() {
    final interval = int.tryParse(_intervalController.text.trim()) ?? 1;
    final safeInterval = interval < 1 ? 1 : interval;

    DateTime? endDate;
    int? afterCount;
    if (_selectedEndType == RecurrenceEndType.onDate) {
      endDate = _endDate;
    } else if (_selectedEndType == RecurrenceEndType.afterCount) {
      final parsed = int.tryParse(_afterCountController.text.trim()) ?? 1;
      afterCount = parsed < 1 ? 1 : parsed;
    }

    final rule = RecurrenceRule(
      interval: safeInterval,
      unit: _selectedUnit,
      endType: _selectedEndType,
      endDate: endDate,
      occurrenceCount: afterCount,
      daysOfWeek: _selectedUnit == RecurrenceUnit.week ? _selectedDays.toList() : null,
    );

    Navigator.pop(
      context,
      RepeatSettingsResult(rule: rule),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Repeat Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _applyAndClose,
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Frequency Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECURRENCE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: _inputChip(
                          child: TextField(
                            controller: _intervalController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _inputChip(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<RecurrenceUnit>(
                              value: _selectedUnit,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                              items: RecurrenceUnit.values
                                  .map(
                                    (unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(
                                        _unitLabel(unit),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedUnit = value);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedUnit == RecurrenceUnit.week) ...[
                    const SizedBox(height: 20),
                    _weekdayRow(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            
            // Time & Date Summary
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.access_time_filled,
                    label: 'TIME',
                    value: DateFormat.jm().format(_startsAt),
                    onTap: _pickStartsTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.calendar_month,
                    label: 'STARTS',
                    value: DateFormat('d MMM').format(_startsAt),
                    onTap: _pickStartsDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            
            // End Condition Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ENDS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _endRow(
                      title: 'Run indefinitely',
                      isSelected: _selectedEndType == RecurrenceEndType.never,
                      trailing: const SizedBox(),
                      onTap: () => setState(() => _selectedEndType = RecurrenceEndType.never),
                    ),
                    const Divider(color: AppColors.tagAdmin, height: 1),
                    _endRow(
                      title: 'End on date',
                      isSelected: _selectedEndType == RecurrenceEndType.onDate,
                      trailing: _smallValueChip(
                        text: DateFormat('d MMM yyyy').format(_endDate),
                        onTap: _pickEndDate,
                      ),
                      onTap: () => setState(() => _selectedEndType = RecurrenceEndType.onDate),
                    ),
                    const Divider(color: AppColors.tagAdmin, height: 1),
                    _endRow(
                      title: 'End after',
                      isSelected: _selectedEndType == RecurrenceEndType.afterCount,
                      trailing: _smallValueChip(
                        text: '${_afterCountController.text} times',
                        onTap: _pickAfterCount,
                      ),
                      onTap: () => setState(() => _selectedEndType = RecurrenceEndType.afterCount),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayRow() {
    final labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    // Map index 0-6 to DateTime.weekday (1=Mon, 7=Sun)
    // index: 0(S), 1(M), 2(T), 3(W), 4(T), 5(F), 6(S)
    // weekday: 7, 1, 2, 3, 4, 5, 6
    int indexToWeekday(int index) => index == 0 ? 7 : index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(labels.length, (index) {
        final dayValue = indexToWeekday(index);
        final isSelected = _selectedDays.contains(dayValue);
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (_selectedDays.contains(dayValue)) {
                // Don't allow empty selection if unit is week? 
                // Or just let it be empty. Usually at least one day is needed.
                if (_selectedDays.length > 1) {
                  _selectedDays.remove(dayValue);
                }
              } else {
                _selectedDays.add(dayValue);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.primary : AppColors.surface,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ] : null,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.tagAdmin,
                width: 1,
              ),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _endRow({
    required String title,
    required bool isSelected,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _radioCircle(isSelected),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _radioCircle(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _smallValueChip({
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tagAdmin),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _inputChip({required Widget child}) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tagAdmin),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  String _unitLabel(RecurrenceUnit unit) {
    switch (unit) {
      case RecurrenceUnit.day: return 'Days';
      case RecurrenceUnit.week: return 'Weeks';
      case RecurrenceUnit.month: return 'Months';
      case RecurrenceUnit.year: return 'Years';
    }
  }
}

class _AfterCountDialog extends StatefulWidget {
  final String initialValue;

  const _AfterCountDialog({required this.initialValue});

  @override
  State<_AfterCountDialog> createState() => _AfterCountDialogState();
}

class _AfterCountDialogState extends State<_AfterCountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End After'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Number of occurrences',
          suffixText: 'times',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final parsed = int.tryParse(_controller.text.trim()) ?? 1;
            Navigator.pop(context, parsed < 1 ? 1 : parsed);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
