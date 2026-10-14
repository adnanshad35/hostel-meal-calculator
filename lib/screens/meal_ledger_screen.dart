import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/month_calendar.dart';
import 'admin_meal_edit_screen.dart';

/// One member's meals on one day, saved or from their meal plan.
class _DayMeal {
  const _DayMeal({
    required this.lunch,
    required this.dinner,
    this.isPlan = false,
  });

  final double lunch;
  final double dinner;

  /// True when it comes from the meal plan, not a saved entry.
  final bool isPlan;

  double get total => lunch + dinner;
}

/// The whole hostel's meals this month, as a calendar. Tapping a day
/// lists every member's lunch and dinner; an admin can tap a member
/// to add or correct theirs.
class MealLedgerScreen extends StatefulWidget {
  const MealLedgerScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.embedded = false,
  });

  final String groupId;
  final bool isAdmin;

  /// True when shown as a tab of another page, which has the title.
  final bool embedded;

  @override
  State<MealLedgerScreen> createState() => _MealLedgerScreenState();
}

class _MealLedgerScreenState extends State<MealLedgerScreen> {
  late final DateTime _now = DateTime.now();
  late final Stream<List<GroupMember>> _membersStream;
  late final Stream<List<MemberMealPlan>> _plansStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _mealsStream;

  @override
  void initState() {
    super.initState();

    _membersStream = GroupMemberService.watch(widget.groupId);
    _plansStream = MealPlanService.watchAll(widget.groupId);
    // This month only.
    _mealsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('meals')
        .where(
          'dateKey',
          isGreaterThanOrEqualTo: MealPlans.dateKey(
            DateTime(_now.year, _now.month),
          ),
        )
        .where(
          'dateKey',
          isLessThan: MealPlans.dateKey(DateTime(_now.year, _now.month + 1)),
        )
        .snapshots();
  }

  /// The space the three-dot mark takes at the end of a line.
  static const double _menuWidth = 28;

  static String _quantity(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  static String _meals(double lunch, double dinner) {
    return 'L ${_quantity(lunch)} · D ${_quantity(dinner)}';
  }

  void _openEditor(GroupMember member, int day, _DayMeal? meal) {
    final date = DateTime(_now.year, _now.month, day);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminMealEditScreen(
          groupId: widget.groupId,
          memberId: member.id,
          memberName: member.name,
          date: date,
          dateKey: MealPlans.dateKey(date),
          initialLunch: meal?.lunch ?? 0,
          initialDinner: meal?.dinner ?? 0,
          hasEntry: meal != null && !meal.isPlan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Total Meals')),
      body: StreamBuilder<List<GroupMember>>(
        stream: _membersStream,
        builder: (context, members) {
          return StreamBuilder<List<MemberMealPlan>>(
            stream: _plansStream,
            builder: (context, plans) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _mealsStream,
                builder: (context, meals) {
                  if (members.hasError || meals.hasError) {
                    return const Center(
                      child: Text('Unable to load the meals.'),
                    );
                  }

                  if (!members.hasData || !meals.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return _buildCalendar(
                    members.data!,
                    plans.data ?? const [],
                    meals.data!.docs,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendar(
    List<GroupMember> members,
    List<MemberMealPlan> plans,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final daysInMonth = DateTime(_now.year, _now.month + 1, 0).day;
    final rulesOf = {for (final plan in plans) plan.memberId: plan.rules};

    // day → member → what they have that day.
    final byDay = <int, Map<String, _DayMeal>>{};

    for (final document in docs) {
      final data = document.data();
      final dateKey = data['dateKey'] as String? ?? '';
      final userId = data['userId'] as String? ?? '';
      final day = int.tryParse(dateKey.split('-').last);
      if (day == null || userId.isEmpty) continue;

      byDay.putIfAbsent(day, () => {})[userId] = _DayMeal(
        lunch: (data['lunch'] as num?)?.toDouble() ?? 0,
        dinner: (data['dinner'] as num?)?.toDouble() ?? 0,
      );
    }

    // A member with no entry gets what their meal plan says, for the
    // days it covers.
    for (var day = 1; day <= daysInMonth; day++) {
      final dateKey = MealPlans.dateKey(DateTime(_now.year, _now.month, day));

      for (final member in members) {
        if (byDay[day]?.containsKey(member.id) ?? false) continue;

        final planned = MealPlans.forDay(
          rulesOf[member.id] ?? const [],
          dateKey,
        );
        if (planned == null) continue;

        byDay.putIfAbsent(day, () => {})[member.id] = _DayMeal(
          lunch: planned.lunch,
          dinner: planned.dinner,
          isPlan: true,
        );
      }
    }

    // Up to today everything counts; a later day counts only what was
    // already saved, since a plan there is still only a plan.
    bool counts(int day, _DayMeal meal) => !meal.isPlan || day <= _now.day;

    double monthTotal = 0;
    final markedDays = <int>{};

    byDay.forEach((day, meals) {
      for (final meal in meals.values) {
        if (!counts(day, meal)) continue;

        monthTotal += meal.total;
        if (meal.total > 0) markedDays.add(day);
      }
    });

    return MonthCalendarView(
      month: _now,
      label: 'Total meals',
      total: _quantity(monthTotal),
      markedDays: markedDays,
      emptyText: 'No members',
      linesOf: (day) {
        final meals = byDay[day] ?? const <String, _DayMeal>{};
        if (members.isEmpty) return const [];

        double lunch = 0;
        double dinner = 0;
        for (final meal in meals.values) {
          if (!counts(day, meal)) continue;
          lunch += meal.lunch;
          dinner += meal.dinner;
        }

        return [
          CalendarLine(
            title: 'Total',
            trailing: _meals(lunch, dinner),
            isStrong: true,
            // Leaves the room the members' menu takes, so the total
            // lines up with their figures.
            action: widget.isAdmin ? const SizedBox(width: _menuWidth) : null,
          ),
          for (final member in members)
            CalendarLine(
              title: member.name,
              note: meals[member.id]?.isPlan == true ? 'plan' : null,
              trailing: meals[member.id] == null
                  ? '—'
                  : _meals(meals[member.id]!.lunch, meals[member.id]!.dinner),
              onTap: widget.isAdmin
                  ? () => _openEditor(member, day, meals[member.id])
                  : null,
              // Three dots mark a line an admin can open.
              action: widget.isAdmin
                  ? const SizedBox(
                      width: _menuWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : null,
            ),
        ];
      },
    );
  }
}
