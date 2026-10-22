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

  /// Each member's lunches and dinners this month, the most first.
  void _showMemberTotals(
    List<GroupMember> members,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, double> lunchOf,
    Map<String, double> dinnerOf,
  ) {
    // Current members, plus anyone else who has meals this month.
    final names = <String, String>{
      for (final document in docs)
        if (lunchOf.containsKey(document.data()['userId']))
          document.data()['userId'] as String:
              document.data()['userName'] as String? ?? 'Member',
      for (final member in members) member.id: member.name,
    };

    double totalOf(String id) => (lunchOf[id] ?? 0) + (dinnerOf[id] ?? 0);

    final ids = names.keys.toList()
      ..sort((a, b) {
        final byTotal = totalOf(b).compareTo(totalOf(a));
        return byTotal != 0 ? byTotal : names[a]!.compareTo(names[b]!);
      });

    final hostelLunch = lunchOf.values.fold<double>(0, (a, b) => a + b);
    final hostelDinner = dinnerOf.values.fold<double>(0, (a, b) => a + b);

    Widget row(
      String name,
      List<String> figures, {
      bool isHeader = false,
      bool isStrong = false,
    }) {
      final style = isHeader
          ? const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            )
          : TextStyle(
              color: isStrong ? AppTheme.primary : AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: isStrong ? FontWeight.w900 : FontWeight.w700,
            );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: isHeader
                    ? style
                    : TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: isStrong
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
              ),
            ),
            for (final figure in figures)
              SizedBox(
                width: 60,
                child: Text(figure, textAlign: TextAlign.end, style: style),
              ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Text(
                    'Member Totals',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                row('', const ['Lunch', 'Dinner', 'Total'], isHeader: true),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final id in ids)
                        row(names[id]!, [
                          _quantity(lunchOf[id] ?? 0),
                          _quantity(dinnerOf[id] ?? 0),
                          _quantity(totalOf(id)),
                        ]),
                    ],
                  ),
                ),
                const Divider(height: 1),
                row('Total', [
                  _quantity(hostelLunch),
                  _quantity(hostelDinner),
                  _quantity(hostelLunch + hostelDinner),
                ], isStrong: true),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
    // Each member's month, for the totals behind the top card.
    final lunchOf = <String, double>{};
    final dinnerOf = <String, double>{};

    byDay.forEach((day, meals) {
      meals.forEach((userId, meal) {
        if (!counts(day, meal)) return;

        monthTotal += meal.total;
        if (meal.total > 0) markedDays.add(day);
        lunchOf[userId] = (lunchOf[userId] ?? 0) + meal.lunch;
        dinnerOf[userId] = (dinnerOf[userId] ?? 0) + meal.dinner;
      });
    });

    CalendarLine totalOf(int day) {
      double lunch = 0;
      double dinner = 0;
      for (final meal in (byDay[day] ?? const <String, _DayMeal>{}).values) {
        if (!counts(day, meal)) continue;
        lunch += meal.lunch;
        dinner += meal.dinner;
      }

      return CalendarLine(
        title: 'Total',
        trailing: '',
        values: [_quantity(lunch), _quantity(dinner)],
        isStrong: true,
        // Leaves the room the members' menu takes, so the total lines
        // up with their figures.
        action: widget.isAdmin ? const SizedBox(width: _menuWidth) : null,
      );
    }

    // Column titles, above the total and the members' figures.
    CalendarLine header() {
      return CalendarLine(
        title: '',
        trailing: '',
        values: const ['Lunch', 'Dinner'],
        isHeader: true,
        action: widget.isAdmin ? const SizedBox(width: _menuWidth) : null,
      );
    }

    return MonthCalendarView(
      month: _now,
      label: 'Total Meals',
      total: _quantity(monthTotal),
      markedDays: markedDays,
      emptyText: 'No members',
      showMonthOption: true,
      // The hostel's figure opens each member's share of it.
      onTotalTap: () => _showMemberTotals(members, docs, lunchOf, dinnerOf),
      // The month view lists each day's total only.
      shortLinesOf: (day) =>
          members.isEmpty ? const [] : [header(), totalOf(day)],
      linesOf: (day) {
        final meals = byDay[day] ?? const <String, _DayMeal>{};
        if (members.isEmpty) return const [];

        return [
          header(),
          totalOf(day),
          for (final member in members)
            CalendarLine(
              title: member.name,
              note: meals[member.id]?.isPlan == true ? 'plan' : null,
              trailing: '',
              values: meals[member.id] == null
                  ? const ['—', '—']
                  : [
                      _quantity(meals[member.id]!.lunch),
                      _quantity(meals[member.id]!.dinner),
                    ],
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
