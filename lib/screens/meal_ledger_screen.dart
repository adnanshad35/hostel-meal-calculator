import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/edit_mark.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/month_records.dart';
import '../theme/app_theme.dart';
import '../widgets/month_calendar.dart';
import 'admin_meal_edit_screen.dart';
import 'meal_screen.dart';

/// One member's meals on one day, saved or from their meal plan.
class _DayMeal {
  const _DayMeal({
    required this.lunch,
    required this.dinner,
    this.isPlan = false,
    this.isEdited = false,
  });

  final double lunch;
  final double dinner;

  /// True when it comes from the meal plan, not a saved entry.
  final bool isPlan;

  /// True when it was changed after it was first saved, so everyone
  /// can see it was edited.
  final bool isEdited;

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
  /// The month on screen: this month, or an earlier one.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  late final Stream<List<GroupMember>> _membersStream;
  late final Stream<List<MemberMealPlan>> _plansStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _mealsStream;

  /// The signed-in member, whose own meals are picked out.
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  /// Admins correct meals in the current month only.
  bool get _canEdit => widget.isAdmin && isEditableMonth(_month);

  @override
  void initState() {
    super.initState();

    _membersStream = GroupMemberService.watch(widget.groupId);
    _plansStream = MealPlanService.watchAll(widget.groupId);
    // One month at a time.
    _mealsStream = MonthRecords.meals(widget.groupId, _month).snapshots();
  }

  void _showMonth(DateTime month) {
    setState(() {
      _month = month;
      _mealsStream = MonthRecords.meals(widget.groupId, month).snapshots();
    });
  }

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

    _showTable(
      title: 'Member Totals',
      rows: [
        for (final id in ids)
          (
            names[id]!,
            [
              _quantity(lunchOf[id] ?? 0),
              _quantity(dinnerOf[id] ?? 0),
              _quantity(totalOf(id)),
            ],
          ),
      ],
      total: [
        _quantity(hostelLunch),
        _quantity(hostelDinner),
        _quantity(hostelLunch + hostelDinner),
      ],
    );
  }

  /// A sheet with a table of lunch, dinner and total, one row each,
  /// and the total at the foot.
  void _showTable({
    required String title,
    required List<(String, List<String>)> rows,
    required List<String> total,
  }) {
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Text(
                    title,
                    style: const TextStyle(
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
                      for (final (name, figures) in rows) row(name, figures),
                    ],
                  ),
                ),
                const Divider(height: 1),
                row('Total', total, isStrong: true),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditor(GroupMember member, int day, _DayMeal? meal) {
    final date = DateTime(_month.year, _month.month, day);

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
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
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
        isEdited: isEditedEntry(data),
      );
    }

    // A member with no entry gets what their meal plan says, for the
    // days it covers.
    for (var day = 1; day <= daysInMonth; day++) {
      final dateKey = MealPlans.dateKey(
        DateTime(_month.year, _month.month, day),
      );

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
    // already saved, since a plan there is still only a plan. Every day
    // of an earlier month has passed.
    final today = DateTime.now();
    bool counts(int day, _DayMeal meal) =>
        !meal.isPlan ||
        !DateTime(_month.year, _month.month, day).isAfter(today);

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

    final previous = shiftMonth(_month, -1);
    final next = shiftMonth(_month, 1);

    // The member's own row comes first, then the others in order.
    final ordered = [
      ...members.where((member) => member.id == _uid),
      ...members.where((member) => member.id != _uid),
    ];

    return MonthCalendarView(
      // A new month starts on its own selected day.
      key: ValueKey(_month),
      month: _month,
      onPreviousMonth: previous == null ? null : () => _showMonth(previous),
      onNextMonth: next == null ? null : () => _showMonth(next),
      label: 'Total Meals',
      total: _quantity(monthTotal),
      markedDays: markedDays,
      emptyText: 'No members',
      showMonthOption: true,
      calendarOnly: true,
      figures: [
        if (_uid != null)
          CalendarFigure(
            label: 'My Meals',
            value: _quantity((lunchOf[_uid] ?? 0) + (dinnerOf[_uid] ?? 0)),
            onTap: () => _showMyMeals(byDay, counts),
          ),
        CalendarFigure(
          label: 'Total Meals',
          value: _quantity(monthTotal),
          // Each member's share of the hostel's meals.
          onTap: () => _showMemberTotals(members, docs, lunchOf, dinnerOf),
        ),
      ],
      linesOf: (day) => const [],
      dayDetails: (day) {
        if (members.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No members'),
          );
        }

        final meals = byDay[day] ?? const <String, _DayMeal>{};
        double lunch = 0;
        double dinner = 0;
        for (final meal in meals.values) {
          if (!counts(day, meal)) continue;
          lunch += meal.lunch;
          dinner += meal.dinner;
        }

        return _MealTable(
          rows: [
            for (final member in ordered)
              _MealRow(
                name: member.name,
                meal: meals[member.id],
                isMine: member.id == _uid,
                onTap: _editorFor(member, day, meals[member.id]),
              ),
          ],
          lunch: lunch,
          dinner: dinner,
        );
      },
    );
  }

  /// What tapping a member's row does on [day]: an admin corrects
  /// anyone's meals, and a member enters their own, up to today.
  VoidCallback? _editorFor(GroupMember member, int day, _DayMeal? meal) {
    if (_canEdit) return () => _openEditor(member, day, meal);

    final now = DateTime.now();
    final isPast = !isCurrentMonth(_month) || day <= now.day;
    if (member.id != _uid || !isEditableMonth(_month) || !isPast) return null;

    return () => showMealForm(
      context,
      groupId: widget.groupId,
      isAdmin: false,
      date: DateTime(_month.year, _month.month, day),
    );
  }

  /// The member's own meals this month, day by day.
  void _showMyMeals(
    Map<int, Map<String, _DayMeal>> byDay,
    bool Function(int day, _DayMeal meal) counts,
  ) {
    final days = byDay.keys.toList()..sort();
    double lunch = 0;
    double dinner = 0;

    final rows = <(String, List<String>)>[];
    for (final day in days) {
      final meal = byDay[day]![_uid];
      if (meal == null || !counts(day, meal) || meal.total == 0) continue;

      lunch += meal.lunch;
      dinner += meal.dinner;
      rows.add((
        '$day ${_shortMonths[_month.month - 1]}'
            '${meal.isPlan ? '  Auto' : ''}'
            '${meal.isEdited ? '  Edited' : ''}',
        [_quantity(meal.lunch), _quantity(meal.dinner), _quantity(meal.total)],
      ));
    }

    _showTable(
      title: 'My Meals',
      rows: rows,
      total: [_quantity(lunch), _quantity(dinner), _quantity(lunch + dinner)],
    );
  }
}

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One member's line in a day's table.
class _MealRow {
  const _MealRow({
    required this.name,
    required this.meal,
    required this.isMine,
    required this.onTap,
  });

  final String name;

  /// Null when the member has nothing that day.
  final _DayMeal? meal;
  final bool isMine;
  final VoidCallback? onTap;
}

/// A day's meals as a table: each member's lunch, dinner and total,
/// with the day's total at the foot.
class _MealTable extends StatelessWidget {
  const _MealTable({
    required this.rows,
    required this.lunch,
    required this.dinner,
  });

  final List<_MealRow> rows;
  final double lunch;
  final double dinner;

  static const double _column = 50;
  static const double _editWidth = 24;

  static String _quantity(double value) =>
      _MealLedgerScreenState._quantity(value);

  Widget _line({
    required Widget name,
    required List<String> values,
    required TextStyle style,
    required bool hasEdit,
    Widget? edit,
  }) {
    return Row(
      children: [
        Expanded(child: name),
        for (final value in values)
          SizedBox(
            width: _column,
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        if (hasEdit) SizedBox(width: _editWidth, child: edit),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // A column for the pencil, when any row opens for editing.
    final hasEdit = rows.any((row) => row.onTap != null);

    const headStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    const valueStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
    );
    const totalStyle = TextStyle(
      color: AppTheme.primary,
      fontSize: 15,
      fontWeight: FontWeight.w900,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _line(
              name: const Text('Member', style: headStyle),
              values: const ['Lunch', 'Dinner', 'Total'],
              style: headStyle,
              hasEdit: hasEdit,
            ),
          ),
          for (final row in rows)
            Material(
              color: row.isMine
                  ? AppTheme.primary.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: row.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: _line(
                    name: Text.rich(
                      TextSpan(
                        text: row.name,
                        children: [
                          if (row.meal?.isPlan ?? false)
                            const TextSpan(
                              text: '  Auto',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (row.meal?.isEdited ?? false)
                            const TextSpan(
                              text: '  Edited',
                              style: TextStyle(
                                color: AppTheme.accentDeep,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14.5,
                        fontWeight: row.isMine
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    values: row.meal == null
                        ? const ['—', '—', '—']
                        : [
                            _quantity(row.meal!.lunch),
                            _quantity(row.meal!.dinner),
                            _quantity(row.meal!.total),
                          ],
                    style: valueStyle,
                    hasEdit: hasEdit,
                    edit: row.onTap == null
                        ? null
                        : const Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _line(
              name: const Text('Total', style: totalStyle),
              values: [
                _quantity(lunch),
                _quantity(dinner),
                _quantity(lunch + dinner),
              ],
              style: totalStyle,
              hasEdit: hasEdit,
            ),
          ),
        ],
      ),
    );
  }
}
