import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/weekly_focus_provider.dart';

class UpdateGoalSheet extends ConsumerStatefulWidget {
  const UpdateGoalSheet({super.key});

  @override
  ConsumerState<UpdateGoalSheet> createState() => _UpdateGoalSheetState();
}

class _UpdateGoalSheetState extends ConsumerState<UpdateGoalSheet> {
  late TextEditingController _objectiveController;
  late String _priority;
  late List<TextEditingController> _criteriaControllers;
  late List<bool> _criteriaStatus;

  @override
  void initState() {
    super.initState();
    final focusState = ref.read(weeklyFocusProvider);
    _objectiveController = TextEditingController(text: focusState.objective);
    _priority = focusState.priority.isEmpty ? 'High Priority' : focusState.priority;
    
    // Copy existing criteria
    if (focusState.criteria.isEmpty) {
      _criteriaControllers = [TextEditingController()];
      _criteriaStatus = [false];
    } else {
      _criteriaControllers = focusState.criteria.map((c) => TextEditingController(text: c)).toList();
      _criteriaStatus = List<bool>.from(focusState.criteriaStatus);
    }
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    for (var c in _criteriaControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveGoal() {
    final notifier = ref.read(weeklyFocusProvider.notifier);
    notifier.updateObjective(_objectiveController.text.trim());
    notifier.updatePriority(_priority);
    
    final validCriteria = <String>[];
    final validStatus = <bool>[];
    
    for (int i = 0; i < _criteriaControllers.length; i++) {
      final text = _criteriaControllers[i].text.trim();
      if (text.isNotEmpty) {
        validCriteria.add(text);
        validStatus.add(_criteriaStatus[i]);
      }
    }
    
    notifier.updateCriteria(validCriteria, validStatus);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen height and apply padding
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: bottomInsets + 24, // Account for keyboard
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Update Goal',
                    style: GoogleFonts.roboto(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Objective Field
                      Text(
                        'Objective',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TextField(
                          controller: _objectiveController,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            prefixIcon: Icon(Icons.track_changes, color: Color(0xFF9CA3AF), size: 20),
                            filled: true,
                            fillColor: Colors.transparent,
                            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Priority Tag
                      Text(
                        'Priority Tag',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPriorityPill('High Priority', true),
                            const SizedBox(width: 12),
                            _buildPriorityPill('Medium', false),
                            const SizedBox(width: 12),
                            _buildPriorityPill('Low', false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Success Criteria Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Success Criteria',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _criteriaControllers.add(TextEditingController());
                                _criteriaStatus.add(false);
                              });
                            },
                            icon: const Icon(Icons.add, size: 16, color: Color(0xFF5473F7)),
                            label: Text(
                              'Add Criteria',
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5473F7),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Criteria List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _criteriaControllers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildCriteriaItem(index);
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
              
              // Actions
              ElevatedButton(
                onPressed: _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5473F7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shadowColor: const Color(0xFF5473F7).withAlpha(100),
                ),
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel and discard edits',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityPill(String label, bool hasIcon) {
    final isSelected = _priority == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _priority = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hasIcon ? 14 : 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5473F7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF5473F7) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIcon) ...[
              Icon(
                Icons.priority_high,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaItem(int index) {
    final isChecked = _criteriaStatus[index];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _criteriaStatus[index] = !_criteriaStatus[index];
              });
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF10B981) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isChecked ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _criteriaControllers[index],
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF111827),
              ),
              maxLines: null,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Enter criteria...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _criteriaControllers.removeAt(index);
                _criteriaStatus.removeAt(index);
              });
            },
            child: const Icon(
              Icons.delete_outline,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
