import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notes/domain/models/recurrence_rule.dart';

class RepeatConfigurationScreen extends StatefulWidget {
  final RecurrenceRule? initialRule;
  final DateTime? initialDate;

  const RepeatConfigurationScreen({
    super.key,
    this.initialRule,
    this.initialDate,
  });

  @override
  State<RepeatConfigurationScreen> createState() => _RepeatConfigurationScreenState();
}

class _RepeatConfigurationScreenState extends State<RepeatConfigurationScreen> {
  late int _interval;
  late RecurrenceUnit _unit;
  late RecurrenceEndType _endType;
  DateTime? _endDate;
  late int _occurrenceCount;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    if (rule != null) {
      _interval = rule.interval;
      _unit = rule.unit;
      _endType = rule.endType;
      _endDate = rule.endDate;
      _occurrenceCount = rule.occurrenceCount ?? 30;
    } else {
      _interval = 1;
      _unit = RecurrenceUnit.week;
      _endType = RecurrenceEndType.never;
      _endDate = null;
      _occurrenceCount = 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Repeats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                RecurrenceRule(
                  interval: _interval,
                  unit: _unit,
                  endType: _endType,
                  endDate: _endDate,
                  occurrenceCount: _occurrenceCount,
                ),
              );
            },
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Every...
            Text('Every', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: containerColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    controller: TextEditingController(text: _interval.toString())
                      ..selection = TextSelection.fromPosition(TextPosition(offset: _interval.toString().length)),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setState(() => _interval = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<RecurrenceUnit>(
                        value: _unit,
                        icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).iconTheme.color),
                        dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        isExpanded: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                        items: RecurrenceUnit.values.map((unit) {
                          String label = unit.name;
                          // Simple pluralization check
                          if (_interval > 1) label += 's';
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _unit = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Ends...
            Text('Ends', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Never
            _buildRadioOption(
              title: 'Never',
              value: RecurrenceEndType.never,
              groupValue: _endType,
              onChanged: (val) => setState(() => _endType = val!),
            ),

            // On Date
            _buildRadioOption(
              title: 'On',
              value: RecurrenceEndType.onDate,
              groupValue: _endType,
              onChanged: (val) {
                 setState(() => _endType = val!);
                 if (_endDate == null) {
                   _pickEndDate();
                 }
              },
              trailing: _endType == RecurrenceEndType.onDate 
                ? GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _endDate != null 
                          ? "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}" 
                          : "Select Date",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ) 
                : null,
            ),

            // After Count
            _buildRadioOption(
              title: 'After',
              value: RecurrenceEndType.afterCount,
              groupValue: _endType,
              onChanged: (val) => setState(() => _endType = val!),
              trailing: _endType == RecurrenceEndType.afterCount 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            filled: true,
                            fillColor: containerColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          controller: TextEditingController(text: _occurrenceCount.toString()),
                          onChanged: (val) {
                             final parsed = int.tryParse(val);
                             if (parsed != null && parsed > 0) {
                               setState(() => _occurrenceCount = parsed);
                             }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('occurrences', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    ],
                  )
                : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required RecurrenceEndType value,
    required RecurrenceEndType groupValue,
    required ValueChanged<RecurrenceEndType?> onChanged,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Radio<RecurrenceEndType>(
            value: value,
            // ignore: deprecated_member_use
            groupValue: groupValue,
            activeColor: AppColors.primary,
            // ignore: deprecated_member_use
            onChanged: onChanged,
          ),
          Text(title, style: const TextStyle(fontSize: 16)),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endType = RecurrenceEndType.onDate;
      });
    }
  }
}
