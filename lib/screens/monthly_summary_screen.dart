import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

  @override
  State<MonthlySummaryScreen> createState() =>
      _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late DateTime _selectedMonth;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _monthName(DateTime date) {
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

    return '${months[date.month - 1]} ${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    if (nextMonth.isAfter(currentMonth)) return;

    setState(() => _selectedMonth = nextMonth);
  }

  Future<void> _setMinimumMeals(double currentMinimum) async {
    String enteredValue = _simpleNumber(currentMinimum);

    final minimum = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Minimum Meal Number'),
          content: TextFormField(
            initialValue: enteredValue,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Minimum meals per member',
              hintText: 'Example: 20',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              enteredValue = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(enteredValue.trim());

                if (value == null || value < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid number.'),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (minimum == null || !mounted) return;

    try {
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('monthlySettings')
          .doc(_monthKey(_selectedMonth))
          .set({
        'minimumMeals': minimum,
        'monthKey': _monthKey(_selectedMonth),
        'updatedBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to save minimum meals.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final canGoNext = _selectedMonth.isBefore(currentMonth);
    final monthKey = _monthKey(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Calculation'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('groups')
            .doc(widget.groupId)
            .collection('monthlySettings')
            .doc(monthKey)
            .snapshots(),
        builder: (context, settingsSnapshot) {
          if (settingsSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (settingsSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load monthly settings.'),
            );
          }

          final settings = settingsSnapshot.data?.data();

          final minimumMeals =
              (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('groups')
                .doc(widget.groupId)
                .collection('meals')
                .snapshots(),
            builder: (context, mealSnapshot) {
              if (mealSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (mealSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load meals.'),
                );
              }

              return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('expenses')
                    .snapshots(),
                builder: (context, expenseSnapshot) {
                  if (expenseSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (expenseSnapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load expenses.'),
                    );
                  }

                  return StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('users')
                        .where(
                          'groupId',
                          isEqualTo: widget.groupId,
                        )
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (userSnapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Unable to load member information.',
                          ),
                        );
                      }

                      final members = (userSnapshot.data?.docs ?? [])
                          .map(_memberFromDocument)
                          .toList();

                      final result = _calculate(
                        members: members,
                        meals: mealSnapshot.data?.docs ?? [],
                        expenses:
                            expenseSnapshot.data?.docs ?? [],
                        minimumMeals: minimumMeals,
                      );

                      return _buildContent(
                        context,
                        result: result,
                        minimumMeals: minimumMeals,
                        canGoNext: canGoNext,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  _MemberInfo _memberFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final possibleNames = [
      data['name'],
      data['displayName'],
      data['fullName'],
    ];

    String? memberName;

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        memberName = value.trim();
        break;
      }
    }

    return _MemberInfo(
      id: document.id,
      name: memberName ?? 'Member',
    );
  }

  _CalculationResult _calculate({
    required List<_MemberInfo> members,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> meals,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    required double minimumMeals,
  }) {
    final actualMeals = <String, double>{};
    final memberSpending = <String, double>{};

    for (final member in members) {
      actualMeals[member.id] = 0;
      memberSpending[member.id] = 0;
    }

    final selectedMonthKey = _monthKey(_selectedMonth);

    for (final meal in meals) {
      final data = meal.data();
      final userId = data['userId'] as String?;

      if (userId == null || !actualMeals.containsKey(userId)) {
        continue;
      }

      final savedMonthKey = data['monthKey'] as String?;
      final dateKey = data['dateKey'] as String?;

      final belongsToMonth =
          savedMonthKey == selectedMonthKey ||
              dateKey?.startsWith(selectedMonthKey) == true ||
              meal.id.contains('_$selectedMonthKey-');

      if (!belongsToMonth) continue;

      final lunch = (data['lunch'] as num?)?.toDouble() ?? 0;
      final dinner = (data['dinner'] as num?)?.toDouble() ?? 0;

      actualMeals[userId] =
          actualMeals[userId]! + lunch + dinner;
    }

    final firstDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    for (final expense in expenses) {
      final data = expense.data();
      final userId = data['paidById'] as String?;
      final date = (data['date'] as Timestamp?)?.toDate();

      if (userId == null ||
          date == null ||
          !memberSpending.containsKey(userId)) {
        continue;
      }

      final belongsToMonth =
          !date.isBefore(firstDay) && date.isBefore(nextMonth);

      if (!belongsToMonth) continue;

      final amount = (data['amount'] as num?)?.toDouble() ?? 0;

      memberSpending[userId] =
          memberSpending[userId]! + amount;
    }

    final calculations = <_MemberCalculation>[];
    double totalMealNumber = 0;
    double totalExpense = 0;

    for (final member in members) {
      final actual = actualMeals[member.id] ?? 0;

      final calculatedMealNumber = max(
        actual,
        minimumMeals,
      ).toDouble();

      final spending = memberSpending[member.id] ?? 0;

      totalMealNumber += calculatedMealNumber;
      totalExpense += spending;

      calculations.add(
        _MemberCalculation(
          name: member.name,
          actualMeals: actual,
          mealNumber: calculatedMealNumber,
          spending: spending,
        ),
      );
    }

    final mealRate = totalMealNumber > 0
        ? totalExpense / totalMealNumber
        : 0.0;

    final completedCalculations =
        calculations.map((calculation) {
      final mealExpense =
          calculation.mealNumber * mealRate;

      final exactBalance =
          calculation.spending - mealExpense;

      return calculation.copyWith(
        mealExpense: mealExpense,
        exactBalance: exactBalance,
        finalBalance: exactBalance.round(),
      );
    }).toList();

    return _CalculationResult(
      totalMealNumber: totalMealNumber,
      totalExpense: totalExpense,
      mealRate: mealRate,
      members: completedCalculations,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required _CalculationResult result,
    required double minimumMeals,
    required bool canGoNext,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: _previousMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthName(_selectedMonth),
                textAlign: TextAlign.center,
                style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: canGoNext ? _nextMonth : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _InformationRow(
                  label: 'Total meal number',
                  value:
                      result.totalMealNumber.toStringAsFixed(4),
                ),
                _InformationRow(
                  label: 'Total meal expense',
                  value:
                      '৳${result.totalExpense.toStringAsFixed(4)}',
                ),
                const Divider(),
                _InformationRow(
                  label: 'Meal rate',
                  value: '৳${result.mealRate.toStringAsFixed(4)}',
                  important: true,
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      _setMinimumMeals(minimumMeals);
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(
                      minimumMeals > 0
                          ? 'Minimum Meals: ${_simpleNumber(minimumMeals)}'
                          : 'Set Minimum Meal Number',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Member Calculations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (result.members.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No members were found.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFE8F5E9),
                ),
                columns: const [
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Meals')),
                  DataColumn(label: Text('Spent')),
                  DataColumn(label: Text('Meal Expense')),
                  DataColumn(label: Text('Final Result')),
                ],
                rows: result.members.map((member) {
                  final finalResult = member.finalBalance < 0
                      ? 'Pay ৳${member.finalBalance.abs()}'
                      : member.finalBalance > 0
                          ? 'Collect ৳${member.finalBalance}'
                          : 'Settled';

                  final resultColor = member.finalBalance < 0
                      ? Colors.red
                      : member.finalBalance > 0
                          ? const Color(0xFF2E7D32)
                          : Colors.grey;

                  final mealText =
                      member.actualMeals < member.mealNumber
                          ? '${member.mealNumber.toStringAsFixed(4)}\n'
                              'Actual: ${member.actualMeals.toStringAsFixed(4)}'
                          : member.mealNumber.toStringAsFixed(4);

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Text(
                            member.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(mealText)),
                      DataCell(
                        Text(
                          '৳${member.spending.toStringAsFixed(4)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '৳${member.mealExpense.toStringAsFixed(4)}',
                        ),
                      ),
                      DataCell(
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              finalResult,
                              style: TextStyle(
                                color: resultColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Exact: ${member.exactBalance.toStringAsFixed(4)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        if (minimumMeals > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Members below ${_simpleNumber(minimumMeals)} meals '
            'are calculated using the minimum meal number.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _simpleNumber(double value) {
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toString();
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.important = false,
  });

  final String label;
  final String value;
  final bool important;

  @override
  Widget build(BuildContext context) {
    final valueStyle = important
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            )
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _MemberInfo {
  const _MemberInfo({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _MemberCalculation {
  const _MemberCalculation({
    required this.name,
    required this.actualMeals,
    required this.mealNumber,
    required this.spending,
    this.mealExpense = 0,
    this.exactBalance = 0,
    this.finalBalance = 0,
  });

  final String name;
  final double actualMeals;
  final double mealNumber;
  final double spending;
  final double mealExpense;
  final double exactBalance;
  final int finalBalance;

  _MemberCalculation copyWith({
    double? mealExpense,
    double? exactBalance,
    int? finalBalance,
  }) {
    return _MemberCalculation(
      name: name,
      actualMeals: actualMeals,
      mealNumber: mealNumber,
      spending: spending,
      mealExpense: mealExpense ?? this.mealExpense,
      exactBalance: exactBalance ?? this.exactBalance,
      finalBalance: finalBalance ?? this.finalBalance,
    );
  }
}

class _CalculationResult {
  const _CalculationResult({
    required this.totalMealNumber,
    required this.totalExpense,
    required this.mealRate,
    required this.members,
  });

  final double totalMealNumber;
  final double totalExpense;
  final double mealRate;
  final List<_MemberCalculation> members;
}