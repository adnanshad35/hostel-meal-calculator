import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/fixed_costs.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/monthly_calculator.dart';
import '../theme/app_theme.dart';
import 'fixed_costs_screen.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late DateTime _selectedMonth;
  late final Stream<List<GroupMember>> _membersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _settingsStream;
  late final Stream<List<MemberMealPlan>> _plansStream;

  _CalcTab _tab = _CalcTab.meals;
  bool _showMemberCards = true;
  bool _showMemberDetails = false;
  bool _showFixedDetails = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _membersStream = GroupMemberService.watch(widget.groupId);
    _plansStream = MealPlanService.watchAll(widget.groupId);
    // Every month's settings, because fixed costs carry forward from
    // the last month they were saved in.
    _settingsStream = _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('monthlySettings')
        .snapshots();
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
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
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

  Future<void> _copySummaryCard({required MonthlyCalculation result}) async {
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Summary copied.')));
  }

  /// Copies the full table (all members) to clipboard.
  Future<void> _copyFullTable({required MonthlyCalculation result}) async {
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Full table copied.')));
  }

  // ─────────────────────────────────────────────────────────────
  // Number dialog + monthly settings
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save minimum meals.'),
          ),
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
      await _saveMonthlySettings(minimumMeals: minimumMeals, shopDue: due);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save the shop due.'),
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
    final groupReference = _firestore.collection('groups').doc(widget.groupId);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Calculation')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _settingsStream,
        builder: (context, settingsSnapshot) {
          if (settingsSnapshot.connectionState == ConnectionState.waiting &&
              !settingsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (settingsSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load monthly settings.'),
            );
          }

          final settingsByMonth = <String, Map<String, dynamic>>{
            for (final document
                in settingsSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              document.id: document.data(),
          };
          final settings = settingsByMonth[monthKey];
          final minimumMeals =
              (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
          final shopDue = (settings?['shopDue'] as num?)?.toDouble() ?? 0;
          final fixedCosts = FixedCostsCalculator.resolve(
            settingsByMonth,
            monthKey,
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: groupReference.collection('meals').snapshots(),
            builder: (context, mealSnapshot) {
              if (mealSnapshot.connectionState == ConnectionState.waiting &&
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
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (expenseSnapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load expenses.'),
                    );
                  }

                  return StreamBuilder<List<GroupMember>>(
                    stream: _membersStream,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (userSnapshot.hasError) {
                        return const Center(
                          child: Text('Unable to load member information.'),
                        );
                      }

                      final members = (userSnapshot.data ?? [])
                          .map(
                            (member) =>
                                CalcMember(id: member.id, name: member.name),
                          )
                          .toList();

                      // Meal plans fill in the days without an entry.
                      return StreamBuilder<List<MemberMealPlan>>(
                        stream: _plansStream,
                        builder: (context, planSnapshot) {
                          if (planSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !planSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (planSnapshot.hasError) {
                            return const Center(
                              child: Text('Unable to load meal plans.'),
                            );
                          }

                          final result = _calculate(
                            members: members,
                            meals: mealSnapshot.data?.docs ?? [],
                            plans: planSnapshot.data ?? const [],
                            expenses: expenseSnapshot.data?.docs ?? [],
                            minimumMeals: minimumMeals,
                            shopDue: shopDue,
                          );

                          return _buildContent(
                            context,
                            result: result,
                            members: members,
                            fixedCosts: fixedCosts,
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
          );
        },
      ),
    );
  }

  MonthlyCalculation _calculate({
    required List<CalcMember> members,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> meals,
    required List<MemberMealPlan> plans,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    required double minimumMeals,
    required double shopDue,
  }) {
    return MonthlyCalculator.calculate(
      month: _selectedMonth,
      members: members,
      meals: _withPlannedMeals(
        meals.map(_mealRecord).toList(),
        plans: plans,
        members: members,
        month: _selectedMonth,
      ),
      expenses: expenses.map(_expenseRecord),
      minimumMeals: minimumMeals,
      shopDue: shopDue,
    );
  }

  void _openFixedCosts({
    required List<CalcMember> members,
    required Map<String, double> rents,
    required List<SharedBill> sharedBills,
    required double minimumMeals,
    required double shopDue,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FixedCostsScreen(
          groupId: widget.groupId,
          month: _selectedMonth,
          monthName: _monthName(_selectedMonth),
          members: members,
          rents: rents,
          bills: sharedBills,
          minimumMeals: minimumMeals,
          shopDue: shopDue,
        ),
      ),
    );
  }

  Future<void> _resetFixedCosts({
    required double minimumMeals,
    required double shopDue,
  }) async {
    final monthName = _monthName(_selectedMonth);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Fixed Costs?'),
          content: Text(
            'Rent and shared bills will be cleared from $monthName '
            'onward. Earlier months keep their figures.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final monthKey = _monthKey(_selectedMonth);

      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('monthlySettings')
          .doc(monthKey)
          .set({
            'rents': <String, double>{},
            'sharedBills': <Map<String, dynamic>>[],
            'minimumMeals': minimumMeals,
            'shopDue': shopDue,
            'monthKey': monthKey,
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fixed costs were reset.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to reset fixed costs.'),
          ),
        ),
      );
    }
  }

  Future<void> _copyText(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }

  /// "will pay ৳X", "will receive ৳X", or "is settled".
  static String _resultPhrase(int amount) {
    if (amount < 0) return '${_bold('will pay')} ৳${amount.abs()}';
    if (amount > 0) return '${_bold('will receive')} ৳$amount';
    return _bold('is settled');
  }

  Future<void> _copyMealBalances({required MonthlyCalculation result}) {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate – Meal Calculation'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');
    buffer.writeln(
      '${_bold('Meal Rate')}: ৳${result.mealRate.toStringAsFixed(2)}',
    );
    buffer.writeln('');

    for (final member in result.members) {
      buffer.writeln('• ${member.name} ${_resultPhrase(member.finalBalance)}');
    }

    return _copyText(buffer.toString(), 'Meal calculation copied.');
  }

  Future<void> _copyFixedCosts({
    required List<MemberSettlement> settlements,
    required List<SharedBill> sharedBills,
    required double billShare,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate – Fixed Costs'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');

    if (sharedBills.isNotEmpty) {
      buffer.writeln(_bold('Shared Bills'));
      for (final bill in sharedBills) {
        buffer.writeln('• ${bill.name}: ৳${_amountText(bill.amount)}');
      }
      buffer.writeln('${_bold('Each member')}: ৳${_amountText(billShare)}');
      buffer.writeln('');
    }

    buffer.writeln(_bold('Each Member Pays'));
    for (final settlement in settlements) {
      final total = settlement.rent + settlement.billShare;
      if (total <= 0) continue;

      final parts = [
        if (settlement.rent > 0) 'Rent ৳${_amountText(settlement.rent)}',
        if (settlement.billShare > 0)
          'Bills ৳${_amountText(settlement.billShare)}',
      ];

      buffer.writeln(
        '• ${settlement.name}: ${_bold('৳${_amountText(total)}')} '
        '(${parts.join(' + ')})',
      );
    }

    return _copyText(buffer.toString(), 'Fixed costs copied.');
  }

  Future<void> _copyOverall({
    required List<MemberSettlement> settlements,
    required bool includesFixedCosts,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate – Overall Calculation'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln(includesFixedCosts ? 'Meals + fixed costs' : 'Meals only');
    buffer.writeln('');

    for (final settlement in settlements) {
      buffer.writeln(
        '• ${settlement.name} ${_resultPhrase(settlement.finalTotal)}',
      );
    }

    return _copyText(buffer.toString(), 'Overall calculation copied.');
  }

  Widget _buildContent(
    BuildContext context, {
    required MonthlyCalculation result,
    required List<CalcMember> members,
    required FixedCosts? fixedCosts,
    required double minimumMeals,
    required double shopDue,
    required bool canGoNext,
  }) {
    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );
    final rents = fixedCosts?.rents ?? const <String, double>{};
    final sharedBills = fixedCosts?.bills ?? const <SharedBill>[];
    final hasFixedCosts = rents.isNotEmpty || sharedBills.isNotEmpty;
    // Set when this month is using figures saved in an earlier month.
    final carriedFrom =
        hasFixedCosts && fixedCosts!.monthKey != _monthKey(_selectedMonth)
        ? _monthName(_monthStartFromKey(fixedCosts.monthKey))
        : null;
    final settlements = FixedCostsCalculator.settle(
      members: result.members,
      rents: rents,
      bills: sharedBills,
    );
    final billShare = FixedCostsCalculator.billShare(
      members: result.members,
      bills: sharedBills,
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

        // ─── Meals / Fixed / Overall ───
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_CalcTab>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_CalcTab>(
                value: _CalcTab.meals,
                icon: Icon(Icons.restaurant_outlined, size: 18),
                label: Text('Meals'),
              ),
              ButtonSegment<_CalcTab>(
                value: _CalcTab.fixed,
                icon: Icon(Icons.home_work_outlined, size: 18),
                label: Text('Fixed'),
              ),
              ButtonSegment<_CalcTab>(
                value: _CalcTab.overall,
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                label: Text('Overall'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) {
              setState(() => _tab = selection.first);
            },
          ),
        ),
        const SizedBox(height: 16),

        // ═══ Meals ═══
        if (_tab == _CalcTab.meals) ...[
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

          // ─── Summary card (tappable to copy) ───
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

          const SizedBox(height: 12),
          if (result.members.isNotEmpty) ...[
            _AmountListCard(
              title: 'Meal Calculation',
              rows: [
                for (final member in result.members)
                  _AmountRow.balance(member.name, member.finalBalance),
              ],
              onCopy: () => _copyMealBalances(result: result),
            ),
            const SizedBox(height: 12),
          ],
          _DetailsToggle(
            title: 'Details',
            subtitle: 'Meals, spending and meal expense per member',
            isExpanded: _showMemberDetails,
            onTap: () {
              setState(() => _showMemberDetails = !_showMemberDetails);
            },
          ),
          if (_showMemberDetails) ...[
            const SizedBox(height: 12),
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
                                Text('৳${member.spending.toStringAsFixed(2)}'),
                              ),
                              DataCell(
                                Text(
                                  '৳${member.mealExpense.toStringAsFixed(2)}',
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
        ],

        // ═══ Fixed ═══
        if (_tab == _CalcTab.fixed) ...[
          if (!hasFixedCosts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.isAdmin
                          ? 'Add each member\'s rent and the shared bills '
                                '(Wi-Fi, electricity, chef). Shared bills '
                                'are divided equally, and everything stays '
                                'the same each month until you change it.'
                          : 'No rent or shared bills have been added '
                                'for this hostel yet.',
                      textAlign: TextAlign.center,
                    ),
                    if (widget.isAdmin) ...[
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _openFixedCosts(
                          members: members,
                          rents: rents,
                          sharedBills: sharedBills,
                          minimumMeals: minimumMeals,
                          shopDue: shopDue,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Fixed Costs'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else ...[
            if (carriedFrom != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2DA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 18,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isAdmin
                            ? 'Carried over from $carriedFrom. Update it '
                                  'if any bill changed this month.'
                            : 'Carried over from $carriedFrom.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _AmountListCard(
              title: 'Fixed Cost',
              rows: [
                for (final settlement in settlements)
                  if (settlement.rent + settlement.billShare > 0)
                    _AmountRow.owed(
                      settlement.name,
                      settlement.rent + settlement.billShare,
                    ),
              ],
              onCopy: () => _copyFixedCosts(
                settlements: settlements,
                sharedBills: sharedBills,
                billShare: billShare,
              ),
            ),
            const SizedBox(height: 12),
            _DetailsToggle(
              title: 'Details',
              subtitle: 'Shared bills and each member\'s rent',
              isExpanded: _showFixedDetails,
              onTap: () {
                setState(() => _showFixedDetails = !_showFixedDetails);
              },
            ),
            if (_showFixedDetails) ...[
              const SizedBox(height: 12),
              _FixedCostsDetails(
                settlements: settlements,
                sharedBills: sharedBills,
                billShare: billShare,
              ),
            ],
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _resetFixedCosts(
                        minimumMeals: minimumMeals,
                        shopDue: shopDue,
                      ),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openFixedCosts(
                        members: members,
                        rents: rents,
                        sharedBills: sharedBills,
                        minimumMeals: minimumMeals,
                        shopDue: shopDue,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],

        // ═══ Overall: meals + fixed costs, final amounts only ═══
        if (_tab == _CalcTab.overall) ...[
          if (settlements.isEmpty)
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
            _AmountListCard(
              title: 'Overall Calculation',
              subtitle: hasFixedCosts
                  ? 'Meals + fixed costs'
                  : 'Meals only. No fixed costs this month.',
              rows: [
                for (final settlement in settlements)
                  _AmountRow.balance(settlement.name, settlement.finalTotal),
              ],
              onCopy: () => _copyOverall(
                settlements: settlements,
                includesFixedCosts: hasFixedCosts,
              ),
            ),
        ],
      ],
    );
  }

  String _simpleNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
}

String _amountText(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

enum _CalcTab { meals, fixed, overall }

/// One member's line in an [_AmountListCard].
class _AmountRow {
  const _AmountRow(this.name, this.text, this.color);

  /// A balance: negative is owed, positive is to be collected.
  factory _AmountRow.balance(String name, int amount) {
    if (amount < 0) {
      return _AmountRow(name, 'Pay ৳${amount.abs()}', AppTheme.danger);
    }
    if (amount > 0) {
      return _AmountRow(name, 'Collect ৳$amount', AppTheme.success);
    }
    return _AmountRow(name, 'Settled', AppTheme.textSecondary);
  }

  /// An amount the member owes.
  factory _AmountRow.owed(String name, double amount) {
    return _AmountRow(name, '৳${_amountText(amount)}', AppTheme.textPrimary);
  }

  final String name;
  final String text;
  final Color color;
}

// ─────────────────────────────────────────────────────────────
// A titled list of one amount per member, with a copy action
// ─────────────────────────────────────────────────────────────
class _AmountListCard extends StatelessWidget {
  const _AmountListCard({
    required this.title,
    required this.rows,
    required this.onCopy,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<_AmountRow> rows;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            const Divider(height: 12, endIndent: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 7, 8, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      row.text,
                      style: TextStyle(
                        color: row.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Expand / collapse row for a tab's details
// ─────────────────────────────────────────────────────────────
class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fixed cost details — the bills and rents that were entered
// ─────────────────────────────────────────────────────────────
class _FixedCostsDetails extends StatelessWidget {
  const _FixedCostsDetails({
    required this.settlements,
    required this.sharedBills,
    required this.billShare,
  });

  final List<MemberSettlement> settlements;
  final List<SharedBill> sharedBills;
  final double billShare;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rents = settlements.where((item) => item.rent > 0).toList();
    final totalRent = rents.fold<double>(0, (total, item) => total + item.rent);

    Widget heading(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sharedBills.isNotEmpty) ...[
              heading('SHARED BILLS'),
              for (final bill in sharedBills)
                _SettlementLine(
                  label: bill.name,
                  value: '৳${_amountText(bill.amount)}',
                ),
              _SettlementLine(
                label: 'Total',
                value:
                    '৳${_amountText(FixedCostsCalculator.totalBills(sharedBills))}',
              ),
              _SettlementLine(
                label: 'Each member pays',
                value: '৳${_amountText(billShare)}',
                isStrong: true,
              ),
            ],
            if (sharedBills.isNotEmpty && rents.isNotEmpty)
              const Divider(height: 22),
            if (rents.isNotEmpty) ...[
              heading('RENT'),
              for (final item in rents)
                _SettlementLine(
                  label: item.name,
                  value: '৳${_amountText(item.rent)}',
                ),
              _SettlementLine(
                label: 'Total rent',
                value: '৳${_amountText(totalRent)}',
                isStrong: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettlementLine extends StatelessWidget {
  const _SettlementLine({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppTheme.textPrimary,
      fontWeight: isStrong ? FontWeight.w800 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${mealRate.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall
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
    final labelStyle = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700);
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
// Meal rate comparison widget
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    style: Theme.of(context).textTheme.bodySmall
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
  final minimumMeals = (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
  final shopDue = (settings?['shopDue'] as num?)?.toDouble() ?? 0;

  final members = await GroupMemberService.fetchActive(groupId);

  final mealsSnapshot = await groupRef.collection('meals').get();
  final expensesSnapshot = await groupRef.collection('expenses').get();
  final plans = await MealPlanService.fetchAll(groupId);
  final calcMembers = [
    for (final member in members) CalcMember(id: member.id, name: member.name),
  ];

  final result = MonthlyCalculator.calculate(
    month: previousMonthStart,
    members: calcMembers,
    meals: _withPlannedMeals(
      mealsSnapshot.docs.map(_mealRecord).toList(),
      plans: plans,
      members: calcMembers,
      month: previousMonthStart,
    ),
    expenses: expensesSnapshot.docs.map(_expenseRecord),
    minimumMeals: minimumMeals,
    shopDue: shopDue,
  );

  if (result.totalMealNumber <= 0) return null;
  return result.mealRate;
}

/// The saved meal entries, plus what the meal plans count for the
/// days of [month] that have no entry.
List<MealRecord> _withPlannedMeals(
  List<MealRecord> meals, {
  required List<MemberMealPlan> plans,
  required List<CalcMember> members,
  required DateTime month,
}) {
  return [
    ...meals,
    ...MealPlans.automaticMeals(
      plans: plans,
      meals: meals,
      activeMemberIds: {for (final member in members) member.id},
      month: month,
      today: DateTime.now(),
    ),
  ];
}

MealRecord _mealRecord(QueryDocumentSnapshot<Map<String, dynamic>> document) {
  return MealRecord.fromData(document.id, document.data());
}

ExpenseRecord _expenseRecord(
  QueryDocumentSnapshot<Map<String, dynamic>> document,
) {
  final data = document.data();

  return ExpenseRecord(
    paidById: data['paidById'] as String?,
    paidByName: data['paidByName'] as String?,
    date: (data['date'] as Timestamp?)?.toDate(),
    amount: (data['amount'] as num?)?.toDouble() ?? 0,
  );
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

  final MemberCalculation member;
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
