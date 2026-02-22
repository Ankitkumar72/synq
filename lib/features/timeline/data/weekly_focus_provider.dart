import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyFocusState {
  final String objective;
  final String priority;
  final List<String> criteria;
  final List<bool> criteriaStatus;
  final List<bool> dailyIntentions; // 7 days, Mon-Sun

  const WeeklyFocusState({
    this.objective = '',
    this.priority = '',
    this.criteria = const [],
    this.criteriaStatus = const [],
    this.dailyIntentions = const [false, false, false, false, false, false, false],
  });

  WeeklyFocusState copyWith({
    String? objective,
    String? priority,
    List<String>? criteria,
    List<bool>? criteriaStatus,
    List<bool>? dailyIntentions,
  }) {
    return WeeklyFocusState(
      objective: objective ?? this.objective,
      priority: priority ?? this.priority,
      criteria: criteria ?? this.criteria,
      criteriaStatus: criteriaStatus ?? this.criteriaStatus,
      dailyIntentions: dailyIntentions ?? this.dailyIntentions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'objective': objective,
      'priority': priority,
      'criteria': criteria,
      'criteriaStatus': criteriaStatus,
      'dailyIntentions': dailyIntentions,
    };
  }

  factory WeeklyFocusState.fromJson(Map<String, dynamic> json) {
    return WeeklyFocusState(
      objective: json['objective'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      criteria: (json['criteria'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      criteriaStatus: (json['criteriaStatus'] as List<dynamic>?)?.map((e) => e as bool).toList() ?? [],
      dailyIntentions: (json['dailyIntentions'] as List<dynamic>?)?.map((e) => e as bool).toList() ?? [false, false, false, false, false, false, false],
    );
  }
}

class WeeklyFocusNotifier extends StateNotifier<WeeklyFocusState> {
  WeeklyFocusNotifier() : super(const WeeklyFocusState()) {
    _load();
  }

  static const String _prefKey = 'weekly_focus_state';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = WeeklyFocusState.fromJson(decoded);
      } catch (e) {
        // Fallback to default state on error
      }
    }
  }

  Future<void> _save(WeeklyFocusState newState) async {
    state = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(newState.toJson()));
  }

  Future<void> updateObjective(String newObjective) async {
    await _save(state.copyWith(objective: newObjective));
  }

  Future<void> updatePriority(String newPriority) async {
    await _save(state.copyWith(priority: newPriority));
  }

  Future<void> toggleCriterion(int index) async {
    if (index < 0 || index >= state.criteriaStatus.length) return;
    
    final newStatus = List<bool>.from(state.criteriaStatus);
    newStatus[index] = !newStatus[index];
    await _save(state.copyWith(criteriaStatus: newStatus));
  }

  Future<void> updateCriteria(List<String> newCriteria, List<bool> newStatus) async {
    await _save(state.copyWith(
      criteria: newCriteria,
      criteriaStatus: newStatus,
    ));
  }

  Future<void> toggleDailyIntention(int index) async {
    if (index < 0 || index >= state.dailyIntentions.length) return;
    
    final newIntentions = List<bool>.from(state.dailyIntentions);
    newIntentions[index] = !newIntentions[index];
    await _save(state.copyWith(dailyIntentions: newIntentions));
  }
}

final weeklyFocusProvider = StateNotifierProvider<WeeklyFocusNotifier, WeeklyFocusState>((ref) {
  return WeeklyFocusNotifier();
});
