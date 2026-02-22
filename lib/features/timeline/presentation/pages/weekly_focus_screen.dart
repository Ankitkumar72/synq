import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/weekly_focus_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';
import '../../../notes/domain/models/note.dart';

class WeeklyFocusScreen extends ConsumerStatefulWidget {
  const WeeklyFocusScreen({super.key});

  @override
  ConsumerState<WeeklyFocusScreen> createState() => _WeeklyFocusScreenState();
}

class _WeeklyFocusScreenState extends ConsumerState<WeeklyFocusScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Weekly Focus',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100), // padding for bottom button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildSuccessCriteriaSection(),
                const SizedBox(height: 16),
                _buildTopTasksSection(),
                const SizedBox(height: 16),
                _buildDailyIntentionsSection(),
              ],
            ),
          ),
          
          // Sticky Bottom Button
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showUpdateGoalDialog,
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                label: Text(
                  'Update Goal',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5473F7), // Blue color from design
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final focusState = ref.watch(weeklyFocusProvider);
    final now = DateTime.now();
    final dayOfYear = int.parse(DateFormat("D").format(now));
    final weekNumber = ((dayOfYear - now.weekday + 10) / 7).floor();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFEEEBFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Color(0xFF6B58F5),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'CURRENT OBJECTIVE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8A93A4),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            focusState.objective.isEmpty ? "Tap 'Update Goal' to set your focus" : focusState.objective,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: focusState.objective.isEmpty ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: focusState.objective.isEmpty ? const Color(0xFFC4B5FD) : const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withAlpha(25)),
                ),
                child: Text(
                  'Week $weekNumber',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A93A4),
                  ),
                ),
              ),
              if (focusState.priority.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEEEBFF)),
                  ),
                  child: Text(
                    focusState.priority,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B58F5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCriteriaSection() {
    final focusState = ref.watch(weeklyFocusProvider);
    final completedCount = focusState.criteriaStatus.where((c) => c).length;
    final totalCount = focusState.criteriaStatus.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // Green
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Success Criteria',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$completedCount/$totalCount Done',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A93A4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totalCount == 0)
            Text(
              'No criteria added yet.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8A93A4),
              ),
            )
          else
            ...List.generate(totalCount, (index) {
              return _buildCriteriaItem(
                index,
                focusState.criteria[index],
                focusState.criteriaStatus[index],
                isLast: index == totalCount - 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(int index, String text, bool isChecked, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: GestureDetector(
        onTap: () {
          ref.read(weeklyFocusProvider.notifier).toggleCriterion(index);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFF6B58F5) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isChecked ? const Color(0xFF6B58F5) : Colors.grey.shade300,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isChecked ? const Color(0xFF8A93A4) : const Color(0xFF1E1E1E),
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopTasksSection() {
    final notesAsync = ref.watch(notesProvider);
    final allNotes = notesAsync.value ?? [];
    
    // Filter active tasks
    final activeTasks = allNotes.where((n) => n.isTask && !n.isCompleted).toList();
    
    // Sort logic to bring highest priority and soonest scheduled tasks to the top
    activeTasks.sort((a, b) {
      final pA = a.priority.index;
      final pB = b.priority.index;
      if (pA != pB) return pB.compareTo(pA); // Descending priority (High is 2, Low is 0)
      
      final tA = a.scheduledTime ?? DateTime.now().add(const Duration(days: 365));
      final tB = b.scheduledTime ?? DateTime.now().add(const Duration(days: 365));
      return tA.compareTo(tB);
    });
    
    final topTasks = activeTasks.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF97316), // Orange
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Top Tasks',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              if (topTasks.isNotEmpty)
                Text(
                  '${topTasks.length} left',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A93A4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (topTasks.isEmpty)
            Text(
              'No active tasks found. Enjoy your day!',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8A93A4),
              ),
            )
          else
            ...topTasks.map((task) {
              final isHigh = task.priority == TaskPriority.high;
              final priorityLabel = isHigh ? 'P1' : (task.priority == TaskPriority.medium ? 'P2' : 'P3');
              final priorityColor = isHigh ? const Color(0xFFFDE8E1) : (task.priority == TaskPriority.medium ? const Color(0xFFE8EFFF) : Colors.grey.shade200);
              final priorityTextColor = isHigh ? const Color(0xFFF97316) : (task.priority == TaskPriority.medium ? const Color(0xFF3B82F6) : Colors.grey.shade600);
              
              String subtitle = 'No time set';
              if (task.scheduledTime != null) {
                final dateFmt = DateFormat('MMM d');
                final timeFmt = DateFormat('h:mm a');
                subtitle = '${dateFmt.format(task.scheduledTime!)} • ${timeFmt.format(task.scheduledTime!)}';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTaskCard(
                  priority: priorityLabel,
                  priorityColor: priorityColor,
                  priorityTextColor: priorityTextColor,
                  title: task.title,
                  subtitle: subtitle,
                ),
              );
            }),
          
          if (topTasks.isNotEmpty) const SizedBox(height: 4),
          // Add Task Button
          GestureDetector(
            onTap: () {
              showCreateTaskSheet(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withAlpha(50), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Color(0xFF8A93A4), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Add Task',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A93A4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required String priority,
    required Color priorityColor,
    required Color priorityTextColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: priorityColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                priority,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: priorityTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8A93A4),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF8A93A4)),
        ],
      ),
    );
  }

  Widget _buildDailyIntentionsSection() {
    final focusState = ref.watch(weeklyFocusProvider);
    
    // Get dates for Mon - Fri of the current week
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    // We now show 7 days (MON - SUN)
    final days = List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      final isFinished = focusState.dailyIntentions.length > index ? focusState.dailyIntentions[index] : false;
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      
      return {
        'index': index,
        'day': DateFormat('E').format(date).toUpperCase().substring(0, 3),
        'date': date.day.toString(),
        'icon': isFinished,
        'isToday': isToday,
      };
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFFC4B5FD), size: 20),
              const SizedBox(width: 12),
              Text(
                'Daily Intentions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 105, // accommodate container height + cross-axis padding for shadow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: days.length,
              padding: const EdgeInsets.only(bottom: 12), // provides cross-axis padding for the shadow
              itemBuilder: (context, index) {
                final dayData = days[index];
                final isSelected = dayData['icon'] as bool;
                final isToday = dayData['isToday'] as bool;

                return GestureDetector(
                  onTap: () {
                    ref.read(weeklyFocusProvider.notifier).toggleDailyIntention(index);
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12), // removed bottom margin, handled by ListView padding
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF5473F7) : (isToday ? const Color(0xFFF0EFFF) : const Color(0xFFF5F7FF)),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF5473F7).withAlpha(76),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayData['day'] as String,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white.withAlpha(200) : (isToday ? const Color(0xFF6B58F5) : Colors.grey.shade500),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isSelected)
                          const Icon(Icons.check, color: Colors.white, size: 20)
                        else
                          Text(
                            dayData['date'] as String,
                            style: GoogleFonts.inter(
                              color: isToday ? const Color(0xFF6B58F5) : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Log your daily progress towards the weekly goal.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8A93A4),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateGoalDialog() {
    final focusState = ref.read(weeklyFocusProvider);
    final objectiveController = TextEditingController(text: focusState.objective);
    final priorityController = TextEditingController(text: focusState.priority);
    
    // We'll manage criteria locally in the dialog state
    final criteriaControllers = focusState.criteria.map((c) => TextEditingController(text: c)).toList();
    final criteriaStatus = List<bool>.from(focusState.criteriaStatus);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Goal'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: objectiveController,
                        decoration: const InputDecoration(labelText: 'Objective'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priorityController,
                        decoration: const InputDecoration(labelText: 'Priority Tag'),
                      ),
                      const SizedBox(height: 24),
                      const Text('Success Criteria', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...List.generate(criteriaControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: criteriaControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Criteria ${index + 1}',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    criteriaControllers.removeAt(index);
                                    criteriaStatus.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            criteriaControllers.add(TextEditingController());
                            criteriaStatus.add(false);
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Criteria'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final notifier = ref.read(weeklyFocusProvider.notifier);
                    notifier.updateObjective(objectiveController.text);
                    notifier.updatePriority(priorityController.text);
                    
                    final newCriteria = criteriaControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
                    final newStatus = criteriaStatus.take(newCriteria.length).toList();
                    // If we removed empty strings, ensure status matches
                    notifier.updateCriteria(newCriteria, newStatus);
                    
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
