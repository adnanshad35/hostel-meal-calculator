import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import 'admin_meal_edit_screen.dart';

class MealLedgerScreen extends StatefulWidget {
  const MealLedgerScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

  @override
  State<MealLedgerScreen> createState() => _MealLedgerScreenState();
}

class _MealLedgerScreenState extends State<MealLedgerScreen> {
  late final Stream<List<GroupMember>> _membersStream;
  late final Stream<List<MemberMealPlan>> _plansStream;

  String get groupId => widget.groupId;
  bool get isAdmin => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _membersStream = GroupMemberService.watch(widget.groupId);
    _plansStream = MealPlanService.watchAll(widget.groupId);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _nextMonthKey(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1);
    final year = nextMonth.year.toString();
    final month = nextMonth.month.toString().padLeft(2, '0');

    return '$year-$month-01';
  }

  String _displayQuantity(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month);
    final totalDays = DateTime(now.year, now.month + 1, 0).day;

    final startKey = _dateKey(firstDay);
    final endKey = _nextMonthKey(now);
    final todayKey = _dateKey(now);

    final mealsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('meals')
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThan: endKey)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Meal Ledger')),
      body: StreamBuilder<List<GroupMember>>(
        stream: _membersStream,
        builder: (context, usersSnapshot) {
          if (usersSnapshot.connectionState == ConnectionState.waiting &&
              !usersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (usersSnapshot.hasError) {
            return const Center(child: Text('Unable to load group members.'));
          }

          final members = usersSnapshot.data ?? [];

          return StreamBuilder<List<MemberMealPlan>>(
            stream: _plansStream,
            builder: (context, plansSnapshot) {
              final plans = plansSnapshot.data ?? const <MemberMealPlan>[];

              return _buildLedger(
                context,
                now: now,
                totalDays: totalDays,
                todayKey: todayKey,
                mealsStream: mealsStream,
                members: members,
                plans: plans,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLedger(
    BuildContext context, {
    required DateTime now,
    required int totalDays,
    required String todayKey,
    required Stream<QuerySnapshot<Map<String, dynamic>>> mealsStream,
    required List<GroupMember> members,
    required List<MemberMealPlan> plans,
  }) {
    final memberIds = {for (final member in members) member.id};
    final rulesByMember = {
      for (final plan in plans)
        if (memberIds.contains(plan.memberId)) plan.memberId: plan.rules,
    };

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: mealsStream,
      builder: (context, mealsSnapshot) {
        if (mealsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (mealsSnapshot.hasError) {
          return const Center(child: Text('Unable to load the meal ledger.'));
        }

        final entryMap = <String, Map<String, dynamic>>{};
        double groupMonthlyTotal = 0;

        for (final document in mealsSnapshot.data?.docs ?? []) {
          final data = document.data();
          final dateKey = data['dateKey'] as String? ?? '';
          final userId = data['userId'] as String? ?? '';

          entryMap['$dateKey|$userId'] = data;
          groupMonthlyTotal += (data['total'] as num?)?.toDouble() ?? 0;
        }

        // Days without an entry are filled in from the member's
        // meal plan. Up to today they are counted; later days
        // only show what is planned.
        for (int day = 1; day <= totalDays; day++) {
          final dateKey = _dateKey(DateTime(now.year, now.month, day));

          for (final member in members) {
            final key = '$dateKey|${member.id}';
            if (entryMap.containsKey(key)) continue;

            final planned = MealPlans.forDay(
              rulesByMember[member.id] ?? const [],
              dateKey,
            );
            if (planned == null) continue;

            final isCounted = dateKey.compareTo(todayKey) <= 0;

            entryMap[key] = {
              'lunch': planned.lunch,
              'dinner': planned.dinner,
              'total': planned.total,
              'planned': true,
              'counted': isCounted,
            };

            if (isCounted) groupMonthlyTotal += planned.total;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 38,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_monthName(now.month)} ${now.year}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('${members.length} members'),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total meals'),
                        Text(
                          _displayQuantity(groupMonthlyTotal),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text('Administrator editing enabled'),
                  subtitle: Text(
                    'Tap any member to add or correct their meals.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (members.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No members were found in this group.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (int day = 1; day <= totalDays; day++)
                _DateMealCard(
                  groupId: groupId,
                  isAdmin: isAdmin,
                  date: DateTime(now.year, now.month, day),
                  dateKey: _dateKey(DateTime(now.year, now.month, day)),
                  todayKey: todayKey,
                  members: members,
                  entryMap: entryMap,
                  displayQuantity: _displayQuantity,
                ),
          ],
        );
      },
    );
  }
}

class _DateMealCard extends StatelessWidget {
  const _DateMealCard({
    required this.groupId,
    required this.isAdmin,
    required this.date,
    required this.dateKey,
    required this.todayKey,
    required this.members,
    required this.entryMap,
    required this.displayQuantity,
  });

  final String groupId;
  final bool isAdmin;
  final DateTime date;
  final String dateKey;
  final String todayKey;
  final List<GroupMember> members;
  final Map<String, Map<String, dynamic>> entryMap;
  final String Function(double) displayQuantity;

  String _weekdayName(int weekday) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return weekdays[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final submittedCount = members.where((member) {
      final entry = entryMap['$dateKey|${member.id}'];
      return entry != null && entry['planned'] != true;
    }).length;

    final isToday = dateKey == todayKey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: isToday,
        leading: CircleAvatar(
          backgroundColor: isToday
              ? const Color(0xFF2E7D32)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: isToday ? Colors.white : null,
          child: Text(date.day.toString()),
        ),
        title: Text(
          '${_weekdayName(date.weekday)}${isToday ? ' • Today' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$submittedCount of ${members.length} members submitted',
        ),
        children: [
          const Divider(height: 1),
          for (final member in members)
            _MemberMealRow(
              groupId: groupId,
              isAdmin: isAdmin,
              memberId: member.id,
              memberName: member.name,
              date: date,
              dateKey: dateKey,
              entry: entryMap['$dateKey|${member.id}'],
              displayQuantity: displayQuantity,
            ),
        ],
      ),
    );
  }
}

class _MemberMealRow extends StatelessWidget {
  const _MemberMealRow({
    required this.groupId,
    required this.isAdmin,
    required this.memberId,
    required this.memberName,
    required this.date,
    required this.dateKey,
    required this.entry,
    required this.displayQuantity,
  });

  final String groupId;
  final bool isAdmin;
  final String memberId;
  final String memberName;
  final DateTime date;
  final String dateKey;
  final Map<String, dynamic>? entry;
  final String Function(double) displayQuantity;

  void _openEditor(BuildContext context) {
    final lunch = (entry?['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (entry?['dinner'] as num?)?.toDouble() ?? 0;
    final isSaved = entry != null && entry!['planned'] != true;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminMealEditScreen(
          groupId: groupId,
          memberId: memberId,
          memberName: memberName,
          date: date,
          dateKey: dateKey,
          initialLunch: lunch,
          initialDinner: dinner,
          hasEntry: isSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return ListTile(
        leading: const Icon(Icons.help_outline, color: Colors.orange),
        title: Text(memberName),
        subtitle: Text(isAdmin ? 'Not entered • Tap to add' : 'Not entered'),
        trailing: isAdmin ? const Icon(Icons.edit_outlined) : null,
        onTap: isAdmin ? () => _openEditor(context) : null,
      );
    }

    final lunch = (entry!['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (entry!['dinner'] as num?)?.toDouble() ?? 0;
    final total = (entry!['total'] as num?)?.toDouble() ?? 0;
    final isPlanned = entry!['planned'] == true;
    final isCounted = !isPlanned || entry!['counted'] == true;

    return ListTile(
      leading: isPlanned
          ? Icon(
              Icons.event_repeat_outlined,
              color: isCounted ? Colors.green : Colors.grey,
            )
          : const Icon(Icons.check_circle_outline, color: Colors.green),
      title: Text(memberName),
      subtitle: Text(
        'Lunch: ${displayQuantity(lunch)}   '
        'Dinner: ${displayQuantity(dinner)}'
        '${isPlanned ? (isCounted ? '  •  From meal plan' : '  •  Planned') : ''}',
      ),
      trailing: isAdmin
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayQuantity(total),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined),
              ],
            )
          : Text(
              displayQuantity(total),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
      onTap: isAdmin ? () => _openEditor(context) : null,
    );
  }
}
