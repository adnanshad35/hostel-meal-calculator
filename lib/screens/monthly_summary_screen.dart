import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

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

class _MonthlySummaryScreenState
    extends State<MonthlySummaryScreen> {
  late DateTime _selectedMonth;
  bool _showMemberCards = true;

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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (nextMonth.isAfter(currentMonth)) return;
    setState(() => _selectedMonth = nextMonth);
  }

  // ─────────────────────────────────────────────────────────────
  // Copy helpers
  // ─────────────────────────────────────────────────────────────

  /// Converts normal ASCII letters/digits to their Unicode "bold" counterparts
  /// so the text STAYS BOLD when pasted into WhatsApp, Telegram, Notes, etc.
    /// Wraps text in single asterisks. WhatsApp, Telegram, Signal,
  /// Slack, and Discord render *this* as bold after paste.
  /// (WhatsApp does NOT support Unicode "mathematical bold"
  /// characters — they show up as broken boxes.)
  static String _bold(String input) => '*$input*';

  Future<void> _copySummaryCard({
    required _CalculationResult result,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate Monthly Summary'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');
    buffer.writeln(
      '${_bold('Meal Rate')}: ৳${result.mealRate.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Total Meal Number')}: '
      '${result.totalMealNumber.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Member Paid')}: '
      '৳${result.memberPaidExpenses.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Shop Due')}: '
      '৳${result.shopDue.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Total Monthly Cost')}: '
      '৳${result.totalExpense.toStringAsFixed(2)}',
    );

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied.')),
    );
  }

  Future<void> _copyOverallCalculation({
    required _CalculationResult result,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate – Overall Calculation'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');

    for (final member in result.members) {
      final isPayable = member.finalBalance < 0;
      final isCollectable = member.finalBalance > 0;

      final name = member.name;
      final amount = member.finalBalance.abs();

      String line;
      if (isPayable) {
        line = '$name ${_bold('will pay')} ৳$amount';
      } else if (isCollectable) {
        line = '$name ${_bold('will receive')} ৳$amount';
      } else {
        line = '$name ${_bold('is settled')}';
      }
      buffer.writeln('• $line');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Overall calculation copied.')),
    );
  }

  /// Copies the full table (all members) to clipboard.
  Future<void> _copyFullTable({
    required _CalculationResult result,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln(_bold('HostelMate Monthly Calculation'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');

    buffer.writeln(
      '${_bold('Total Meal Number')}: '
      '${result.totalMealNumber.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Member Paid')}: '
      '৳${result.memberPaidExpenses.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Shop Due')}: '
      '৳${result.shopDue.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Total Monthly Cost')}: '
      '৳${result.totalExpense.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '${_bold('Meal Rate')}: '
      '৳${result.mealRate.toStringAsFixed(2)}',
    );
    buffer.writeln('');
    buffer.writeln(_bold('Member Calculations'));
    buffer.writeln('');

    for (final member in result.members) {
      final finalResult = member.finalBalance < 0
          ? '${_bold('Pay')} ৳${member.finalBalance.abs()}'
          : member.finalBalance > 0
              ? '${_bold('Collect')} ৳${member.finalBalance}'
              : _bold('Settled');

      buffer.writeln('• ${_bold(member.name)}');
      buffer.writeln(
        '  ${_bold('Actual Meals')}: '
        '${member.actualMeals.toStringAsFixed(2)}',
      );
      buffer.writeln(
        '  ${_bold('Charged Meals')}: '
        '${member.mealNumber.toStringAsFixed(2)}',
      );
      buffer.writeln(
        '  ${_bold('Spent')}: ৳${member.spending.toStringAsFixed(2)}',
      );
      buffer.writeln(
        '  ${_bold('Meal Expense')}: '
        '৳${member.mealExpense.toStringAsFixed(2)}',
      );
      buffer.writeln(
        '  ${_bold('Exact Balance')}: '
        '৳${member.exactBalance.toStringAsFixed(2)}',
      );
      buffer.writeln('  ${_bold('Final Result')}: $finalResult');
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full table copied.')),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Number dialog + monthly settings (unchanged)
  // ─────────────────────────────────────────────────────────────

  Future<double?> _showNumberDialog({
    required String title,
    required String label,
    required String hint,
    required double currentValue,
    String? prefixText,
  }) async {
    String enteredValue = _simpleNumber(currentValue);

    return showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            initialValue: enteredValue,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixText: prefixText,
            ),
            onChanged: (value) => enteredValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
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
  }

  Future<void> _saveMonthlySettings({
    required double minimumMeals,
    required double shopDue,
  }) async {
    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('monthlySettings')
        .doc(_monthKey(_selectedMonth))
        .set({
      'minimumMeals': minimumMeals,
      'shopDue': shopDue,
      'monthKey': _monthKey(_selectedMonth),
      'updatedBy': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setMinimumMeals({
    required double currentMinimum,
    required double currentShopDue,
  }) async {
    final minimum = await _showNumberDialog(
      title: 'Set Minimum Meal Number',
      label: 'Minimum meals per member',
      hint: 'Example: 20',
      currentValue: currentMinimum,
    );
    if (minimum == null || !mounted) return;
    try {
      await _saveMonthlySettings(
        minimumMeals: minimum,
        shopDue: currentShopDue,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to save minimum meals.'),
        ),
      );
    }
  }

  Future<void> _setShopDue({
    required double currentDue,
    required double minimumMeals,
  }) async {
    final due = await _showNumberDialog(
      title: 'Set Monthly Shop Due',
      label: 'Shop due amount',
      hint: 'Example: 2000',
      prefixText: '৳ ',
      currentValue: currentDue,
    );
    if (due == null || !mounted) return;
    try {
      await _saveMonthlySettings(
        minimumMeals: minimumMeals,
        shopDue: due,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to save the shop due.'),
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
    final groupReference =
        _firestore.collection('groups').doc(widget.groupId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Calculation'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: groupReference
            .collection('monthlySettings')
            .doc(monthKey)
            .snapshots(),
        builder: (context, settingsSnapshot) {
          if (settingsSnapshot.connectionState ==
                  ConnectionState.waiting &&
              !settingsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (settingsSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load monthly settings.'),
            );
          }

          final settings = settingsSnapshot.data?.data();
          final minimumMeals =
              (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
          final shopDue =
              (settings?['shopDue'] as num?)?.toDouble() ?? 0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: groupReference.collection('meals').snapshots(),
            builder: (context, mealSnapshot) {
              if (mealSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  !mealSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (mealSnapshot.hasError) {
                return const Center(child: Text('Unable to load meals.'));
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: groupReference.collection('expenses').snapshots(),
                builder: (context, expenseSnapshot) {
                  if (expenseSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !expenseSnapshot.hasData) {
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
                        .where('groupId', isEqualTo: widget.groupId)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !userSnapshot.hasData) {
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
                        expenses: expenseSnapshot.data?.docs ?? [],
                        minimumMeals: minimumMeals,
                        shopDue: shopDue,
                      );

                      return _buildContent(
                        context,
                        result: result,
                        minimumMeals: minimumMeals,
                        shopDue: shopDue,
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

    return _MemberInfo(id: document.id, name: memberName ?? 'Member');
  }

  _CalculationResult _calculate({
    required List<_MemberInfo> members,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> meals,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    required double minimumMeals,
    required double shopDue,
  }) {
    final memberById = <String, _MemberInfo>{
      for (final member in members) member.id: member,
    };
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
      if (userId == null) continue;

      final savedMonthKey = data['monthKey'] as String?;
      final dateKey = data['dateKey'] as String?;

      final belongsToMonth = savedMonthKey == selectedMonthKey ||
          dateKey?.startsWith(selectedMonthKey) == true ||
          meal.id.contains('_$selectedMonthKey-');

      if (!belongsToMonth) continue;

      if (!memberById.containsKey(userId)) {
        final savedName = data['userName'] as String?;
        memberById[userId] = _MemberInfo(
          id: userId,
          name: savedName?.trim().isNotEmpty == true
              ? savedName!.trim()
              : 'Former Member',
        );
        actualMeals[userId] = 0;
        memberSpending[userId] = 0;
      }

      final lunch = (data['lunch'] as num?)?.toDouble() ?? 0;
      final dinner = (data['dinner'] as num?)?.toDouble() ?? 0;
      actualMeals[userId] = actualMeals[userId]! + lunch + dinner;
    }

    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month);
    final nextMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    for (final expense in expenses) {
      final data = expense.data();
      final userId = data['paidById'] as String?;
      final date = (data['date'] as Timestamp?)?.toDate();
      if (userId == null || date == null) continue;

      final belongsToMonth =
          !date.isBefore(firstDay) && date.isBefore(nextMonth);
      if (!belongsToMonth) continue;

      if (!memberById.containsKey(userId)) {
        final savedName = data['paidByName'] as String?;
        memberById[userId] = _MemberInfo(
          id: userId,
          name: savedName?.trim().isNotEmpty == true
              ? savedName!.trim()
              : 'Former Member',
        );
        actualMeals[userId] = 0;
        memberSpending[userId] = 0;
      }

      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      memberSpending[userId] = memberSpending[userId]! + amount;
    }

    final calculations = <_MemberCalculation>[];
    double totalMealNumber = 0;
    double memberPaidExpenses = 0;

    for (final member in memberById.values) {
      final actual = actualMeals[member.id] ?? 0;
      final calculatedMealNumber =
          max(actual, minimumMeals).toDouble();
      final spending = memberSpending[member.id] ?? 0;

      totalMealNumber += calculatedMealNumber;
      memberPaidExpenses += spending;

      calculations.add(
        _MemberCalculation(
          name: member.name,
          actualMeals: actual,
          mealNumber: calculatedMealNumber,
          spending: spending,
        ),
      );
    }

    final totalExpense = memberPaidExpenses + shopDue;
    final mealRate =
        totalMealNumber > 0 ? totalExpense / totalMealNumber : 0.0;

    final completedCalculations = calculations.map((calculation) {
      final mealExpense = calculation.mealNumber * mealRate;
      final exactBalance = calculation.spending - mealExpense;

      return calculation.copyWith(
        mealExpense: mealExpense,
        exactBalance: exactBalance,
        finalBalance: exactBalance.round(),
      );
    }).toList();

    return _CalculationResult(
      totalMealNumber: totalMealNumber,
      memberPaidExpenses: memberPaidExpenses,
      shopDue: shopDue,
      totalExpense: totalExpense,
      mealRate: mealRate,
      members: completedCalculations,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required _CalculationResult result,
    required double minimumMeals,
    required double shopDue,
    required bool canGoNext,
  }) {
    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ─── Month navigation ───
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
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

        // ─── Admin: Min Meals + Shop Due side by side ───
        if (widget.isAdmin)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setMinimumMeals(
                    currentMinimum: minimumMeals,
                    currentShopDue: shopDue,
                  ),
                  icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                  label: Text(
                    minimumMeals > 0
                        ? 'Min Meals: ${_simpleNumber(minimumMeals)}'
                        : 'Min Meals',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setShopDue(
                    currentDue: shopDue,
                    minimumMeals: minimumMeals,
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(
                    shopDue > 0
                        ? 'Shop Due: ৳${_simpleNumber(shopDue)}'
                        : 'Shop Due',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),

        if (widget.isAdmin) const SizedBox(height: 12),

        // ─── CARD 1: Summary card (tappable to copy) ───
        _SummaryCard(
          mealRate: result.mealRate,
          totalMealNumber: result.totalMealNumber,
          totalExpense: result.totalExpense,
          shopDue: result.shopDue,
          memberPaidExpenses: result.memberPaidExpenses,
          previousMonthKey: _monthKey(previousMonth),
          groupId: widget.groupId,
          onCopy: () => _copySummaryCard(result: result),
        ),

        const SizedBox(height: 18),

        // ─── CARD 2: Overall Calculation (centered title, table, copy) ───
        if (result.members.isNotEmpty)
          _OverallCalculationCard(
            members: result.members,
            onCopy: () => _copyOverallCalculation(result: result),
          ),

        const SizedBox(height: 18),

        // ─── CARD 3: Individual Calculation ───
        _SectionTitle(
          icon: Icons.person_outline,
          title: 'Individual Calculation',
        ),
        const SizedBox(height: 10),

        if (result.members.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.view_agenda_outlined),
                  label: Text('Card View'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.table_chart_outlined),
                  label: Text('Table View'),
                ),
              ],
              selected: {_showMemberCards},
              onSelectionChanged: (selection) {
                setState(() => _showMemberCards = selection.first);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

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
        else if (_showMemberCards)
          ...result.members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MemberCalculationCard(
                member: member,
                mealRate: result.mealRate,
                // No copy on individual cards.
                onCopy: null,
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppTheme.surfaceSoft,
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
                          ? AppTheme.danger
                          : member.finalBalance > 0
                              ? AppTheme.success
                              : AppTheme.textSecondary;

                      final mealText =
                          member.actualMeals < member.mealNumber
                              ? '${member.mealNumber.toStringAsFixed(2)}\n'
                                  'Actual: ${member.actualMeals.toStringAsFixed(2)}'
                              : member.mealNumber.toStringAsFixed(2);

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                member.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(mealText)),
                          DataCell(
                            Text(
                              '৳${member.spending.toStringAsFixed(2)}',
                            ),
                          ),
                          DataCell(
                            Text(
                              '৳${member.mealExpense.toStringAsFixed(2)}',
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Exact: ${member.exactBalance.toStringAsFixed(2)}',
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
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyFullTable(result: result),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copy Full Table'),
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (shopDue > 0) ...[
          const SizedBox(height: 10),
          Text(
            'The shop due is included in the total monthly cost but is '
            'not credited as spending to any individual member.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (minimumMeals > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Members below ${_simpleNumber(minimumMeals)} meals are '
            'calculated using the minimum.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _simpleNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
}

// ─────────────────────────────────────────────────────────────
// Section title centered with icon
// ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARD 1: Summary card — tappable to copy
// ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.mealRate,
    required this.totalMealNumber,
    required this.totalExpense,
    required this.shopDue,
    required this.memberPaidExpenses,
    required this.previousMonthKey,
    required this.groupId,
    required this.onCopy,
  });

  final double mealRate;
  final double totalMealNumber;
  final double totalExpense;
  final double shopDue;
  final double memberPaidExpenses;
  final String previousMonthKey;
  final String groupId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceSoft,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCopy,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Data rows (short labels, dark & bold) ───
              _StrongInfoRow(
                label: 'Total Meals',
                value: totalMealNumber.toStringAsFixed(2),
              ),
              _StrongInfoRow(
                label: 'Member Paid',
                value: '৳${memberPaidExpenses.toStringAsFixed(2)}',
              ),
              _StrongInfoRow(
                label: 'Shop Due',
                value: '৳${shopDue.toStringAsFixed(2)}',
              ),
              const Divider(height: 22),
              _StrongInfoRow(
                label: 'Total Cost',
                value: '৳${totalExpense.toStringAsFixed(2)}',
                emphasize: true,
              ),

              const SizedBox(height: 14),

              // ─── Meal rate + previous comparison at the BOTTOM ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meal Rate',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${mealRate.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _MealRateComparison(
                    groupId: groupId,
                    previousMonthKey: previousMonthKey,
                    currentRate: mealRate,
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to copy',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Strong info row (darker + bigger)
// ─────────────────────────────────────────────────────────────
class _StrongInfoRow extends StatelessWidget {
  const _StrongInfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        );
    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: emphasize ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Meal rate comparison widget (unchanged logic)
// ─────────────────────────────────────────────────────────────
class _MealRateComparison extends StatelessWidget {
  const _MealRateComparison({
    required this.groupId,
    required this.previousMonthKey,
    required this.currentRate,
  });

  final String groupId;
  final String previousMonthKey;
  final double currentRate;

  @override
  Widget build(BuildContext context) {
    final previousMonthSettings = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('monthlySettings')
        .doc(previousMonthKey)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: previousMonthSettings,
      builder: (context, snapshot) {
        final previousMonthStart = _monthStartFromKey(previousMonthKey);
        final previousMonthEnd = DateTime(
          previousMonthStart.year,
          previousMonthStart.month + 1,
        );

        return FutureBuilder<double?>(
          future: _previousMealRate(
            groupId: groupId,
            previousMonthKey: previousMonthKey,
            previousMonthStart: previousMonthStart,
            previousMonthEnd: previousMonthEnd,
          ),
          builder: (context, rateSnapshot) {
            final previousRate = rateSnapshot.data;

            if (previousRate == null || previousRate == 0) {
              return Text(
                'No previous data',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              );
            }

            final difference = currentRate - previousRate;
            final isIncrease = difference > 0;
            final isDecrease = difference < 0;

            final color = isIncrease
                ? AppTheme.danger
                : isDecrease
                    ? AppTheme.success
                    : AppTheme.textSecondary;

            final icon = isIncrease
                ? Icons.arrow_upward
                : isDecrease
                    ? Icons.arrow_downward
                    : Icons.remove;

            final sign = isIncrease ? '+' : '';

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$sign৳${difference.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'vs last month',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

DateTime _monthStartFromKey(String monthKey) {
  final parts = monthKey.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

Future<double?> _previousMealRate({
  required String groupId,
  required String previousMonthKey,
  required DateTime previousMonthStart,
  required DateTime previousMonthEnd,
}) async {
  final firestore = FirebaseFirestore.instance;
  final groupRef = firestore.collection('groups').doc(groupId);

  final settingsDoc = await groupRef
      .collection('monthlySettings')
      .doc(previousMonthKey)
      .get();
  final settings = settingsDoc.data();
  final minimumMeals =
      (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
  final shopDue = (settings?['shopDue'] as num?)?.toDouble() ?? 0;

  final usersSnapshot = await firestore
      .collection('users')
      .where('groupId', isEqualTo: groupId)
      .get();
  final memberIds = usersSnapshot.docs.map((d) => d.id).toSet();

  final mealsSnapshot = await groupRef.collection('meals').get();
  final actualMeals = <String, double>{};

  for (final doc in mealsSnapshot.docs) {
    final data = doc.data();
    final userId = data['userId'] as String?;
    if (userId == null) continue;

    final savedMonthKey = data['monthKey'] as String?;
    final dateKey = data['dateKey'] as String?;
    final belongsToMonth = savedMonthKey == previousMonthKey ||
        dateKey?.startsWith(previousMonthKey) == true ||
        doc.id.contains('_$previousMonthKey-');
    if (!belongsToMonth) continue;

    final lunch = (data['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (data['dinner'] as num?)?.toDouble() ?? 0;
    actualMeals[userId] = (actualMeals[userId] ?? 0) + lunch + dinner;
    memberIds.add(userId);
  }

  final expensesSnapshot = await groupRef.collection('expenses').get();
  double memberPaidExpenses = 0;

  for (final doc in expensesSnapshot.docs) {
    final data = doc.data();
    final userId = data['paidById'] as String?;
    final date = (data['date'] as Timestamp?)?.toDate();
    if (userId == null || date == null) continue;

    final belongsToMonth = !date.isBefore(previousMonthStart) &&
        date.isBefore(previousMonthEnd);
    if (!belongsToMonth) continue;

    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    memberPaidExpenses += amount;
    memberIds.add(userId);
  }

  double totalMealNumber = 0;
  for (final userId in memberIds) {
    final actual = actualMeals[userId] ?? 0;
    totalMealNumber += max(actual, minimumMeals).toDouble();
  }

  final totalExpense = memberPaidExpenses + shopDue;
  if (totalMealNumber <= 0) return null;
  return totalExpense / totalMealNumber;
}

// ─────────────────────────────────────────────────────────────
// CARD 2: Overall Calculation — centered title, table, copy
// ─────────────────────────────────────────────────────────────
class _OverallCalculationCard extends StatelessWidget {
  const _OverallCalculationCard({
    required this.members,
    required this.onCopy,
  });

  final List<_MemberCalculation> members;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Centered title with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Overall Calculation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // Table rows
            ...members.map((member) {
              final isPayable = member.finalBalance < 0;
              final isCollectable = member.finalBalance > 0;

              final amountText = isPayable
                  ? 'Pay ৳${member.finalBalance.abs()}'
                  : isCollectable
                      ? 'Receive ৳${member.finalBalance}'
                      : 'Settled';

              final color = isPayable
                  ? AppTheme.danger
                  : isCollectable
                      ? AppTheme.success
                      : AppTheme.textSecondary;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        member.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        amountText,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARD 3: Individual member calculation card
// (NOT copyable — onCopy is null)
// ─────────────────────────────────────────────────────────────
class _MemberCalculationCard extends StatelessWidget {
  const _MemberCalculationCard({
    required this.member,
    required this.mealRate,
    required this.onCopy,
  });

  final _MemberCalculation member;
  final double mealRate;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isPayable = member.finalBalance < 0;
    final isCollectable = member.finalBalance > 0;

    final resultText = isPayable
        ? 'Pay ৳${member.finalBalance.abs()}'
        : isCollectable
            ? 'Collect ৳${member.finalBalance}'
            : 'Settled';

    final resultColor = isPayable
        ? AppTheme.danger
        : isCollectable
            ? AppTheme.success
            : AppTheme.textSecondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.surfaceSoft,
                  foregroundColor: AppTheme.primary,
                  child: Text(
                    member.name.trim().isEmpty
                        ? 'M'
                        : member.name.trim()[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CardValueRow(
              label: 'Actual Meals',
              value: member.actualMeals.toStringAsFixed(2),
            ),
            _CardValueRow(
              label: 'Charged Meals',
              value: member.mealNumber.toStringAsFixed(2),
            ),
            _CardValueRow(
              label: 'Meal Expense',
              value: '৳${member.mealExpense.toStringAsFixed(2)}',
            ),
            _CardValueRow(
              label: 'Spent',
              value: '৳${member.spending.toStringAsFixed(2)}',
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    resultText,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          color: resultColor,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardValueRow extends StatelessWidget {
  const _CardValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberInfo {
  const _MemberInfo({required this.id, required this.name});
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
    required this.memberPaidExpenses,
    required this.shopDue,
    required this.totalExpense,
    required this.mealRate,
    required this.members,
  });

  final double totalMealNumber;
  final double memberPaidExpenses;
  final double shopDue;
  final double totalExpense;
  final double mealRate;
  final List<_MemberCalculation> members;
}