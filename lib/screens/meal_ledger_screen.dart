import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MealLedgerScreen extends StatelessWidget {
  const MealLedgerScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

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
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
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

    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('groupId', isEqualTo: groupId)
        .snapshots();

    final mealsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('meals')
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThan: endKey)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Meal Ledger'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, usersSnapshot) {
          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (usersSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load group members.'),
            );
          }

          final members = usersSnapshot.data?.docs ?? [];

          members.sort((first, second) {
            final firstName =
                first.data()['fullName'] as String? ?? 'Member';
            final secondName =
                second.data()['fullName'] as String? ?? 'Member';

            return firstName.compareTo(secondName);
          });

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: mealsStream,
            builder: (context, mealsSnapshot) {
              if (mealsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (mealsSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load the meal ledger.'),
                );
              }

              final entryMap =
                  <String, Map<String, dynamic>>{};

              double groupMonthlyTotal = 0;

              for (final document
                  in mealsSnapshot.data?.docs ?? []) {
                final data = document.data();
                final dateKey = data['dateKey'] as String? ?? '';
                final userId = data['userId'] as String? ?? '';

                entryMap['$dateKey|$userId'] = data;
                groupMonthlyTotal +=
                    (data['total'] as num?)?.toDouble() ?? 0;
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_monthName(now.month)} ${now.year}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
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
                        date: DateTime(now.year, now.month, day),
                        dateKey: _dateKey(
                          DateTime(now.year, now.month, day),
                        ),
                        todayKey: todayKey,
                        members: members,
                        entryMap: entryMap,
                        displayQuantity: _displayQuantity,
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DateMealCard extends StatelessWidget {
  const _DateMealCard({
    required this.date,
    required this.dateKey,
    required this.todayKey,
    required this.members,
    required this.entryMap,
    required this.displayQuantity,
  });

  final DateTime date;
  final String dateKey;
  final String todayKey;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;
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
      return entryMap.containsKey('$dateKey|${member.id}');
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$submittedCount of ${members.length} members submitted',
        ),
        children: [
          const Divider(height: 1),
          for (final member in members)
            _MemberMealRow(
              memberName:
                  member.data()['fullName'] as String? ?? 'Member',
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
    required this.memberName,
    required this.entry,
    required this.displayQuantity,
  });

  final String memberName;
  final Map<String, dynamic>? entry;
  final String Function(double) displayQuantity;

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return ListTile(
        leading: const Icon(
          Icons.help_outline,
          color: Colors.orange,
        ),
        title: Text(memberName),
        subtitle: const Text('Not entered'),
      );
    }

    final lunch = (entry!['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (entry!['dinner'] as num?)?.toDouble() ?? 0;
    final total = (entry!['total'] as num?)?.toDouble() ?? 0;

    return ListTile(
      leading: const Icon(
        Icons.check_circle_outline,
        color: Colors.green,
      ),
      title: Text(memberName),
      subtitle: Text(
        'Lunch: ${displayQuantity(lunch)}   '
        'Dinner: ${displayQuantity(dinner)}',
      ),
      trailing: Text(
        displayQuantity(total),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}