import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_member.dart';
import '../services/activity_log.dart';
import '../services/best_manager.dart';
import '../services/duty_roster.dart';
import '../services/error_messages.dart';
import '../services/fixed_costs.dart';
import '../services/group_member_service.dart';
import '../services/hostel_settings.dart';
import '../services/initial_share.dart';
import '../services/daily_trend.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/month_archive.dart';
import '../services/month_records.dart';
import '../services/month_rules.dart';
import '../services/month_rules_service.dart';
import '../services/monthly_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/month_trend_chart.dart';
import 'balance_options_screen.dart';
import 'balance_share.dart';
import 'fixed_costs_screen.dart';
import 'hostel_dashboard_screen.dart';
import 'initial_share_screen.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.groupName = '',
    this.embedded = false,
  });

  final String groupId;
  final bool isAdmin;

  /// Shown on the shared picture.
  final String groupName;

  /// True inside another page that has its own app bar.
  final bool embedded;

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late DateTime _selectedMonth;
  late final Stream<List<GroupMember>> _membersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _settingsStream;

  /// The meals and expenses of the month on screen. Replaced when the
  /// month changes, so only one month is ever being read.
  late Stream<QuerySnapshot<Map<String, dynamic>>> _mealsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _expensesStream;
  late final Stream<List<MemberMealPlan>> _plansStream;

  /// The duty turns, for Best Manager.
  late final Stream<DutyRoster> _rosterStream = DutyRosterService.watch(
    widget.groupId,
  );

  /// Last month's running totals, for the chart.
  late Future<DailyTrend?> _previousTrend;

  /// True when the admins allow minimum meals and shop due to be
  /// entered on any day, not only at the month's end.
  bool _specialPermission = false;

  /// Which of Min Meals, Shop Due and Initial Share the hostel uses.
  BalanceOptions _balance = const BalanceOptions();
  StreamSubscription<HostelSettings>? _settingsSubscription;

  /// The members whose own figures are shown under their balance.
  final Set<String> _openMemberIds = {};

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _watchSelectedMonth();
    _membersStream = GroupMemberService.watch(widget.groupId);
    _settingsSubscription = HostelSettingsService.watch(widget.groupId)
        .listen((settings) {
          if (!mounted) return;
          setState(() {
            _specialPermission = settings.specialPermission;
            _balance = settings.balanceOptions;
          });
        }, onError: (_) {});
    _plansStream = MealPlanService.watchAll(widget.groupId);
    // Every month's settings, because fixed costs carry forward from
    // the last month they were saved in.
    _settingsStream = _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('monthlySettings')
        .snapshots();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
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

  void _watchSelectedMonth() {
    _mealsStream = MonthRecords.meals(
      widget.groupId,
      _selectedMonth,
    ).snapshots();
    _expensesStream = MonthRecords.expenses(
      widget.groupId,
      _selectedMonth,
    ).snapshots();
    _previousTrend = _loadPreviousTrend(_selectedMonth)
        .catchError((Object _) => null);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _watchSelectedMonth();
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (nextMonth.isAfter(currentMonth)) return;
    setState(() {
      _selectedMonth = nextMonth;
      _watchSelectedMonth();
    });
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

  /// Copies the full table (all members) to clipboard.
  Future<void> _copyFullTable({required MonthlyCalculation result}) async {
    final buffer = StringBuffer();

    buffer.writeln(_bold('HostelMate Monthly Calculation'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');

    buffer.writeln(
      '${_bold('Total Meals')}: '
      '${result.totalActualMeals.toStringAsFixed(2)}',
    );
    if ((result.totalMealNumber - result.totalActualMeals).abs() > 0.001) {
      buffer.writeln(
        '${_bold('Charged Meals')}: '
        '${result.totalMealNumber.toStringAsFixed(2)}',
      );
    }
    buffer.writeln(
      '${_bold('Member Paid')}: '
      '৳${result.memberPaidExpenses.toStringAsFixed(2)}',
    );
    if (_balance.usesShopDue(_monthKey(_selectedMonth))) {
      buffer.writeln(
        '${_bold('Shop Due')}: '
        '৳${result.shopDue.toStringAsFixed(2)}',
      );
    }
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

  /// Saves the month's figures, with a record of the one that changed
  /// in the hostel's history.
  Future<void> _saveMonthlySettings({
    required double minimumMeals,
    required double shopDue,
    required ActivityKind kind,
    required String details,
  }) async {
    final monthKey = _monthKey(_selectedMonth);
    final batch = _firestore.batch()
      ..set(
        _firestore
            .collection('groups')
            .doc(widget.groupId)
            .collection('monthlySettings')
            .doc(monthKey),
        {
          'minimumMeals': minimumMeals,
          'shopDue': shopDue,
          'monthKey': monthKey,
          'updatedBy': FirebaseAuth.instance.currentUser!.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    ActivityLog.addTo(
      batch,
      widget.groupId,
      kind: kind,
      subject: _monthName(_selectedMonth),
      day: monthKey,
      details: details,
    );
    await batch.commit();
  }

  /// Minimum meals and shop due are settled at the month's end. Says
  /// so and returns false when they cannot be entered today.
  bool _canEnterClosingFigures() {
    if (_specialPermission ||
        MonthlyCalculator.isClosingWindowOpen(_selectedMonth, DateTime.now())) {
      return true;
    }

    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    final opens = '25 ${_monthName(_selectedMonth).split(' ').first}';
    final closes = '5 ${_monthName(nextMonth).split(' ').first}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Not Open Yet'),
          content: Text(
            'Minimum meals and shop due for '
            '${_monthName(_selectedMonth)} can be entered from $opens '
            'to $closes. Wait until then, or turn on Min Meals & Shop Due Any Day '
            'in Balance Options.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return false;
  }

  Future<void> _setMinimumMeals({
    required double currentMinimum,
    required double currentShopDue,
  }) async {
    if (!_canEnterClosingFigures()) return;

    final minimum = await _showNumberDialog(
      title: 'Set Minimum Meal Number',
      label: 'Minimum Meals per Member',
      hint: 'Example: 20',
      currentValue: currentMinimum,
    );
    if (minimum == null || minimum == currentMinimum || !mounted) return;
    try {
      await _saveMonthlySettings(
        minimumMeals: minimum,
        shopDue: currentShopDue,
        kind: ActivityKind.minMealsSet,
        details:
            '${_monthName(_selectedMonth)} · '
            '${ActivityLog.number(currentMinimum)} → '
            '${ActivityLog.number(minimum)}',
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
    if (!_canEnterClosingFigures()) return;

    final due = await _showNumberDialog(
      title: 'Set Monthly Shop Due',
      label: 'Shop Due Amount',
      hint: 'Example: 2000',
      prefixText: '৳ ',
      currentValue: currentDue,
    );
    if (due == null || due == currentDue || !mounted) return;
    try {
      await _saveMonthlySettings(
        minimumMeals: minimumMeals,
        shopDue: due,
        kind: ActivityKind.shopDueSet,
        details:
            '${_monthName(_selectedMonth)} · '
            '৳${ActivityLog.number(currentDue)} → ৳${ActivityLog.number(due)}',
      );
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

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Balance')),
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
          // What is saved for the month, kept as it is when another
          // figure changes, and what counts: zero for a figure the
          // admins switched off.
          final savedMinimum =
              (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
          final savedShopDue = (settings?['shopDue'] as num?)?.toDouble() ?? 0;
          final minimumMeals = _balance.minimumMealsOf(settings, monthKey);
          final shopDue = _balance.shopDueOf(settings, monthKey);
          final rules = MonthRules.fromSettings(settings);
          final fixedCostsSince = _balance.fixedCostsSince(monthKey);
          final fixedCosts = fixedCostsSince == null
              ? null
              : FixedCostsCalculator.resolve(
                  settingsByMonth,
                  monthKey,
                  since: fixedCostsSince,
                );

          // A locked month shows the summary saved for it, not one
          // worked out again from records that may no longer be kept.
          final saved = MonthSummary.isFinal(settings)
              ? MonthSummary.fromSettings(settings)
              : null;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _mealsStream,
            builder: (context, mealSnapshot) {
              if (mealSnapshot.connectionState == ConnectionState.waiting &&
                  !mealSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (mealSnapshot.hasError) {
                return const Center(child: Text('Unable to load meals.'));
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _expensesStream,
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

                          final mealDocs = mealSnapshot.data?.docs ?? [];
                          final expenseDocs = expenseSnapshot.data?.docs ?? [];
                          final plans = planSnapshot.data ?? const [];
                          final result =
                              saved ??
                              _calculate(
                                members: members,
                                meals: mealDocs,
                                plans: plans,
                                expenses: expenseDocs,
                                minimumMeals: minimumMeals,
                                shopDue: shopDue,
                                rules: rules,
                              );

                          return _buildContent(
                            context,
                            result: result,
                            trend: _trendOf(
                              _selectedMonth,
                              meals: mealDocs.map(_mealRecord).toList(),
                              expenses: expenseDocs.map(_expenseRecord),
                              plans: plans,
                              members: members,
                              rules: rules,
                            ),
                            members: members,
                            fixedCosts: fixedCosts,
                            minimumMeals: minimumMeals,
                            shopDue: shopDue,
                            savedMinimum: savedMinimum,
                            savedShopDue: savedShopDue,
                            initialShareTotal: InitialShare.totalOf(
                              expenseDocs,
                            ),
                            managerMeals: _withPlannedMeals(
                              mealDocs.map(_mealRecord).toList(),
                              plans: plans,
                              members: members,
                              month: _selectedMonth,
                              rules: rules,
                            ),
                            // Food bought on each day: no Initial Share,
                            // and nothing of a member removed with it.
                            managerExpenses: [
                              for (final expense in expenseDocs)
                                if (!InitialShare.isPartOfShare(expense.data()))
                                  _expenseRecord(expense),
                            ].where(rules.countsExpense).toList(),
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

  /// Opens the hostel's meals (0) or expenses (1), entry by entry.
  void _openRecords(int tab) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostelRecordsScreen(
          groupId: widget.groupId,
          isAdmin: widget.isAdmin,
          initialTab: tab,
        ),
      ),
    );
  }

  void _openBalanceOptions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BalanceOptionsScreen(groupId: widget.groupId),
      ),
    );
  }

  void _openInitialShare({required bool canAdd, required bool canDelete}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InitialShareScreen(
          groupId: widget.groupId,
          month: _selectedMonth,
          monthName: _monthName(_selectedMonth),
          canAdd: canAdd,
          canDelete: canDelete,
        ),
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
    required MonthRules rules,
  }) {
    return MonthlyCalculator.calculate(
      month: _selectedMonth,
      members: members,
      meals: _withPlannedMeals(
        meals.map(_mealRecord).toList(),
        plans: plans,
        members: members,
        month: _selectedMonth,
        rules: rules,
      ),
      expenses: expenses.map(_expenseRecord),
      minimumMeals: minimumMeals,
      shopDue: shopDue,
      rules: rules,
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

    buffer.writeln(_bold('Each Member'));
    for (final settlement in settlements) {
      final fixed = settlement.rent + settlement.billShare;
      if (fixed <= 0) continue;

      final parts = [
        if (settlement.rent > 0) 'Rent ৳${_amountText(settlement.rent)}',
        if (settlement.billShare > 0)
          'Bills ৳${_amountText(settlement.billShare)}',
      ];
      buffer.writeln(
        '• ${settlement.name}: ${_bold('৳${_amountText(fixed)}')} '
        '(${parts.join(' + ')})',
      );
    }

    return _copyText(buffer.toString(), 'Fixed costs copied.');
  }

  Future<void> _copyMealPlusFixed(List<MemberSettlement> settlements) {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate – Meal + Fixed Cost'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');

    for (final settlement in settlements) {
      final fixed = settlement.rent + settlement.billShare;
      buffer.writeln(
        '• ${settlement.name} ${_resultPhrase(settlement.finalTotal)} '
        '(Meals ${_mealBalanceText(settlement.mealBalance.round())}, '
        'Fixed ৳${_amountText(fixed)})',
      );
    }

    return _copyText(buffer.toString(), 'Meal + Fixed Cost copied.');
  }

  Widget _buildContent(
    BuildContext context, {
    required MonthlyCalculation result,
    required List<CalcMember> members,
    required FixedCosts? fixedCosts,
    required double minimumMeals,
    required double shopDue,
    required double savedMinimum,
    required double savedShopDue,
    required double initialShareTotal,
    required List<MealRecord> managerMeals,
    required List<ExpenseRecord> managerExpenses,
    required bool canGoNext,
    required DailyTrend? trend,
  }) {
    final now = DateTime.now();
    // Locked months can be read, not changed.
    final canChange = widget.isAdmin && MonthLock.canEdit(_selectedMonth, now);
    // Older months keep their summary only, not each entry.
    final hasRecords = !MonthLock.isSummaryOnly(_selectedMonth, now);
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

    final selectedKey = _monthKey(_selectedMonth);
    final showsMinimum = _balance.usesMinimumMeals(selectedKey);
    final showsShopDue = _balance.usesShopDue(selectedKey);
    // With the option off, the box goes; shares already added still
    // count, as the money was really collected and spent on food.
    final showsInitialShare = _balance.initialShare && hasRecords;
    // Admins see a + while any option is off, to switch one on.
    final thisMonthKey = _monthKey(DateTime.now());
    final hasOptionOff =
        !_balance.usesMinimumMeals(thisMonthKey) ||
        !_balance.usesShopDue(thisMonthKey) ||
        !_balance.initialShare ||
        !_balance.bestManager ||
        !_balance.usesFixedCosts(thisMonthKey) ||
        !_balance.mealPlusFixed ||
        !_balance.monthTrend;
    final showsFixedCosts =
        _balance.usesFixedCosts(selectedKey) && (hasFixedCosts || canChange);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ─── Month navigation ───
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE1E7E3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    _monthName(_selectedMonth),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                  onPressed: canGoNext ? _nextMonth : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        _RateHero(
          mealRate: result.mealRate,
          totalMealNumber: result.totalMealNumber,
          totalActualMeals: result.totalActualMeals,
          totalExpense: result.totalExpense,
          shopDue: shopDue,
          minimumMeals: minimumMeals,
          showsMinimum: showsMinimum,
          showsShopDue: showsShopDue,
          initialShareTotal: showsInitialShare ? initialShareTotal : null,
          onOpenInitialShare: hasRecords
              ? () => _openInitialShare(
                  canAdd: canChange && _balance.initialShare,
                  canDelete: canChange,
                )
              : null,
          balance: _balance,
          onOpenBalanceOptions: widget.isAdmin && hasOptionOff
              ? _openBalanceOptions
              : null,
          previousMonthKey: _monthKey(previousMonth),
          groupId: widget.groupId,
          onOpenMeals: hasRecords ? () => _openRecords(0) : null,
          onOpenExpenses: hasRecords ? () => _openRecords(1) : null,
          onEditMinimum: canChange
              ? () => _setMinimumMeals(
                  currentMinimum: savedMinimum,
                  currentShopDue: savedShopDue,
                )
              : null,
          onEditShopDue: canChange
              ? () => _setShopDue(
                  currentDue: savedShopDue,
                  minimumMeals: savedMinimum,
                )
              : null,
        ),
        const SizedBox(height: 14),
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
          _MemberBalancesCard(
            members: result.members,
            openMemberIds: _openMemberIds,
            onToggle: (id) {
              setState(() {
                if (!_openMemberIds.remove(id)) _openMemberIds.add(id);
              });
            },
            onCopyBalances: () => _copyMealBalances(result: result),
            onCopyTable: () => _copyFullTable(result: result),
            onSharePicture: () => showBalanceShare(
              context,
              hostelName: widget.groupName,
              monthName: _monthName(_selectedMonth),
              result: result,
            ),
          ),
        if (_balance.bestManager && hasRecords) ...[
          const SizedBox(height: 14),
          StreamBuilder<DutyRoster>(
            stream: _rosterStream,
            builder: (context, roster) => _BestManagerCard(
              monthName: _monthName(_selectedMonth),
              report: roster.hasData
                  ? BestManager.of(
                      month: _selectedMonth,
                      roster: roster.data!,
                      meals: managerMeals,
                      expenses: managerExpenses,
                      today: DateTime.now(),
                    )
                  : null,
            ),
          ),
        ],
        if (showsFixedCosts) ...[
          const SizedBox(height: 14),
          _FixedCostsCard(
            settlements: settlements,
            sharedBills: sharedBills,
            billShare: billShare,
            carriedFrom: carriedFrom,
            onCopy: hasFixedCosts
                ? () => _copyFixedCosts(
                    settlements: settlements,
                    sharedBills: sharedBills,
                    billShare: billShare,
                  )
                : null,
            onEdit: canChange
                ? () => _openFixedCosts(
                    members: members,
                    rents: rents,
                    sharedBills: sharedBills,
                    minimumMeals: savedMinimum,
                    shopDue: savedShopDue,
                  )
                : null,
          ),
          if (hasFixedCosts && _balance.mealPlusFixed) ...[
            const SizedBox(height: 14),
            _MealPlusFixedCard(
              settlements: settlements,
              onCopy: () => _copyMealPlusFixed(settlements),
            ),
          ],
        ],
        if (trend != null && _balance.monthTrend) ...[
          const SizedBox(height: 14),
          _trendChart(trend),
        ],
      ],
    );
  }

  /// The month's running totals day by day, up to today for the
  /// current month. Null when there is nothing to show, as for a month
  /// whose records are no longer kept.
  DailyTrend? _trendOf(
    DateTime month, {
    required List<MealRecord> meals,
    required Iterable<ExpenseRecord> expenses,
    required List<MemberMealPlan> plans,
    required List<CalcMember> members,
    required MonthRules rules,
  }) {
    final now = DateTime.now();
    final isThisMonth = month.year == now.year && month.month == now.month;
    final trend = DailyTrend.build(
      month: month,
      days: isThisMonth
          ? now.day
          : DateTime(month.year, month.month + 1, 0).day,
      meals: _withPlannedMeals(
        meals,
        plans: plans,
        members: members,
        month: month,
        rules: rules,
      ),
      expenses: expenses.where(rules.countsExpense),
    );
    return trend.isEmpty ? null : trend;
  }

  /// Last month's running totals, read once for each month shown.
  /// Null when its records are no longer kept or it had none.
  Future<DailyTrend?> _loadPreviousTrend(DateTime month) async {
    final previous = DateTime(month.year, month.month - 1);
    if (MonthLock.isSummaryOnly(previous, DateTime.now())) return null;

    final meals = await MonthRecords.meals(widget.groupId, previous).get();
    if (!mounted) return null;
    final expenses = await MonthRecords.expenses(
      widget.groupId,
      previous,
    ).get();
    final plans = await MealPlanService.fetchAll(widget.groupId);
    final members = await GroupMemberService.fetchActive(widget.groupId);
    final rules = await MonthRulesService.fetch(widget.groupId, previous);

    return _trendOf(
      previous,
      rules: rules,
      meals: meals.docs.map(_mealRecord).toList(),
      expenses: expenses.docs.map(_expenseRecord),
      plans: plans,
      members: [
        for (final member in members)
          CalcMember(id: member.id, name: member.name),
      ],
    );
  }

  /// This month against last month, or this month alone when there is
  /// nothing from last month.
  Widget _trendChart(DailyTrend trend) {
    return FutureBuilder<DailyTrend?>(
      future: _previousTrend,
      builder: (context, previous) {
        return MonthTrendChart(
          key: ValueKey(_selectedMonth),
          month: _selectedMonth,
          current: trend,
          previous: previous.data,
        );
      },
    );
  }

  String _simpleNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
}

String _amountText(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

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

  final String name;
  final String text;
  final Color color;
}

// ─────────────────────────────────────────────────────────────
// The month at a glance: the meal rate and the figures behind it
// ─────────────────────────────────────────────────────────────
class _RateHero extends StatelessWidget {
  const _RateHero({
    required this.mealRate,
    required this.totalMealNumber,
    required this.totalActualMeals,
    required this.totalExpense,
    required this.shopDue,
    required this.minimumMeals,
    required this.showsMinimum,
    required this.showsShopDue,
    required this.initialShareTotal,
    required this.onOpenInitialShare,
    required this.balance,
    required this.onOpenBalanceOptions,
    required this.previousMonthKey,
    required this.groupId,
    required this.onOpenMeals,
    required this.onOpenExpenses,
    required this.onEditMinimum,
    required this.onEditShopDue,
  });

  final double mealRate;
  final double totalMealNumber;
  final double totalActualMeals;
  final double totalExpense;
  final double shopDue;
  final double minimumMeals;
  final bool showsMinimum;
  final bool showsShopDue;

  /// Null when the month has no Initial Share to show.
  final double? initialShareTotal;
  final VoidCallback? onOpenInitialShare;
  final BalanceOptions balance;

  /// Null unless an admin can switch on an option that is off.
  final VoidCallback? onOpenBalanceOptions;
  final String previousMonthKey;
  final String groupId;

  /// Null for a month whose entries are no longer kept.
  final VoidCallback? onOpenMeals;
  final VoidCallback? onOpenExpenses;

  /// Null for members: only an admin sets these two.
  final VoidCallback? onEditMinimum;
  final VoidCallback? onEditShopDue;

  @override
  Widget build(BuildContext context) {
    // With a minimum, more meals are charged than were eaten, and the
    // meal rate comes from the charged total.
    final hasChargedMeals = (totalMealNumber - totalActualMeals).abs() > 0.001;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        boxShadow: AppTheme.heroShadow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MEAL RATE',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              // A small + for admins while an option is off.
              if (onOpenBalanceOptions != null)
                TextButton.icon(
                  onPressed: onOpenBalanceOptions,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('More Options'),
                ),
              // Keeps the height the same with or without the +.
              const SizedBox(height: 40),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '৳${mealRate.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MealRateComparison(
                  groupId: groupId,
                  previousMonthKey: previousMonthKey,
                  currentRate: mealRate,
                  balance: balance,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _HeroFigure(
                        label: 'Total Meals',
                        value: _amountText(totalActualMeals),
                        note: hasChargedMeals
                            ? 'Charged ${_amountText(totalMealNumber)}'
                            : null,
                        icon: Icons.chevron_right,
                        onTap: onOpenMeals,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroFigure(
                        label: 'Total Cost',
                        value: '৳${_amountText(totalExpense)}',
                        icon: Icons.chevron_right,
                        onTap: onOpenExpenses,
                      ),
                    ),
                  ],
                ),
                for (final pair in _pairs(_optionFigures())) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // A figure on its own keeps half the width.
                      Expanded(child: pair.$1),
                      const SizedBox(width: 10),
                      Expanded(child: pair.$2 ?? const SizedBox.shrink()),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _RateHero {
  /// The figures the hostel uses: Min Meals, Shop Due, Initial Share.
  List<Widget> _optionFigures() {
    return [
      if (showsMinimum)
        _HeroFigure(
          label: 'Min Meals',
          value: minimumMeals > 0 ? _amountText(minimumMeals) : '—',
          onTap: onEditMinimum,
        ),
      if (showsShopDue)
        _HeroFigure(
          label: 'Shop Due',
          value: shopDue > 0 ? '৳${_amountText(shopDue)}' : '—',
          onTap: onEditShopDue,
        ),
      if (initialShareTotal != null)
        _HeroFigure(
          label: InitialShare.name,
          value: initialShareTotal! > 0
              ? '৳${_amountText(initialShareTotal!)}'
              : '—',
          icon: Icons.chevron_right,
          onTap: onOpenInitialShare,
        ),
    ];
  }
}

/// [figures] two to a row.
List<(Widget, Widget?)> _pairs(List<Widget> figures) {
  return [
    for (var index = 0; index < figures.length; index += 2)
      (figures[index], index + 1 < figures.length ? figures[index + 1] : null),
  ];
}

/// One figure on the [_RateHero]. With [onTap] it can be tapped, and
/// shows [icon] to say so: a pencil unless told otherwise.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({
    required this.label,
    required this.value,
    this.note,
    this.onTap,
    this.icon = Icons.edit_outlined,
  });

  final String label;
  final String value;
  final String? note;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (note != null)
                      Text(
                        note!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null) Icon(icon, size: 18, color: AppTheme.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Every member's balance. A row opens to show that member's meals,
// meal expense and spending.
// ─────────────────────────────────────────────────────────────
class _MemberBalancesCard extends StatelessWidget {
  const _MemberBalancesCard({
    required this.members,
    required this.openMemberIds,
    required this.onToggle,
    required this.onCopyBalances,
    required this.onCopyTable,
    required this.onSharePicture,
  });

  final List<MemberCalculation> members;
  final Set<String> openMemberIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onCopyBalances;
  final VoidCallback onCopyTable;
  final VoidCallback onSharePicture;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 6, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Members',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<VoidCallback>(
                  tooltip: 'Copy or Share',
                  icon: const Icon(
                    Icons.ios_share_outlined,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: onCopyBalances,
                      child: const Text('Copy Balances'),
                    ),
                    PopupMenuItem(
                      value: onCopyTable,
                      child: const Text('Copy Full Table'),
                    ),
                    PopupMenuItem(
                      value: onSharePicture,
                      child: const Text('Share as Picture'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final member in members)
            _MemberBalanceRow(
              member: member,
              isOpen: openMemberIds.contains(member.id),
              onTap: () => onToggle(member.id),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MemberBalanceRow extends StatelessWidget {
  const _MemberBalanceRow({
    required this.member,
    required this.isOpen,
    required this.onTap,
  });

  final MemberCalculation member;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final balance = _AmountRow.balance(member.name, member.finalBalance);
    final hasChargedMeals =
        (member.mealNumber - member.actualMeals).abs() > 0.001;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 11, 10, 11),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  balance.text,
                  style: TextStyle(
                    color: balance.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            if (isOpen)
              Container(
                margin: const EdgeInsets.only(top: 10, right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MemberFigure(
                        label: 'Meals',
                        value: _amountText(member.actualMeals),
                        note: hasChargedMeals
                            ? 'Charged ${_amountText(member.mealNumber)}'
                            : null,
                      ),
                    ),
                    Expanded(
                      child: _MemberFigure(
                        label: 'Meal Cost',
                        value: '৳${_amountText(member.mealExpense)}',
                      ),
                    ),
                    Expanded(
                      child: _MemberFigure(
                        label: 'Spent',
                        value: '৳${_amountText(member.spending)}',
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

class _MemberFigure extends StatelessWidget {
  const _MemberFigure({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (note != null)
          Text(
            note!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// "Get ৳310", "Pay ৳120" or "Settled".
String _mealBalanceText(int amount) => amount > 0
    ? 'Get ৳$amount'
    : amount < 0
    ? 'Pay ৳${-amount}'
    : 'Settled';

// ─────────────────────────────────────────────────────────────
// Fixed Costs and Meal + Fixed Cost: tables with a tinted header
// ─────────────────────────────────────────────────────────────

/// One member's line in a [_TableCard].
class _TableLine {
  const _TableLine(this.name, this.cells, {this.lastColor});

  final String name;
  final List<String> cells;

  /// For the last cell, such as red for Pay.
  final Color? lastColor;
}

/// A card with a tinted header in [color], column labels, and one line
/// per member. Used where a member's figures are read side by side.
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.columns,
    required this.lines,
    this.note,
    this.actions = const [],
    this.top,
    this.lastFlex = 3,
  });

  final IconData icon;
  final String title;
  final Color color;

  /// Short, such as "From October 2026".
  final String? note;
  final List<Widget> actions;
  final List<String> columns;
  final List<_TableLine> lines;

  /// Shown between the header and the lines.
  final Widget? top;
  final int lastFlex;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          ?top,
          if (lines.isNotEmpty) ...[
            _tableRow(
              name: 'Member',
              cells: columns,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: 1),
            for (final (index, line) in lines.indexed)
              Container(
                color: index.isOdd ? AppTheme.surfaceSoft : null,
                child: _tableRow(
                  name: line.name,
                  cells: line.cells,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  lastStyle: TextStyle(
                    color: line.lastColor ?? AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _tableRow({
    required String name,
    required List<String> cells,
    required TextStyle style,
    TextStyle? lastStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          for (final (index, cell) in cells.indexed)
            Expanded(
              flex: index == cells.length - 1 ? lastFlex : 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  cell,
                  textAlign: TextAlign.right,
                  style: index == cells.length - 1 ? lastStyle ?? style : style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rent and the share of the bills, set by admins. Meals are not in
/// it; Meal + Fixed Cost adds them.
class _FixedCostsCard extends StatelessWidget {
  const _FixedCostsCard({
    required this.settlements,
    required this.sharedBills,
    required this.billShare,
    required this.carriedFrom,
    required this.onCopy,
    required this.onEdit,
  });

  final List<MemberSettlement> settlements;
  final List<SharedBill> sharedBills;
  final double billShare;

  /// The month the figures were saved in, when not this one.
  final String? carriedFrom;

  /// Null while nothing is set.
  final VoidCallback? onCopy;

  /// Null unless an admin can change them.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isEmpty =
        sharedBills.isEmpty &&
        settlements.every((settlement) => settlement.rent <= 0);

    return _TableCard(
      icon: Icons.home_work_outlined,
      title: 'Fixed Costs',
      color: AppTheme.accentDeep,
      note: isEmpty || carriedFrom == null ? null : 'From $carriedFrom',
      actions: [
        if (onCopy != null)
          IconButton(
            tooltip: 'Copy',
            onPressed: onCopy,
            icon: const Icon(
              Icons.copy_outlined,
              size: 20,
              color: AppTheme.accentDeep,
            ),
          ),
        if (onEdit != null && !isEmpty)
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppTheme.accentDeep,
            ),
          ),
      ],
      top: isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.add),
                label: const Text('Add Rent & Bills'),
              ),
            )
          : sharedBills.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.6),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final bill in sharedBills)
                    _BillLine(
                      label: bill.name.isEmpty ? 'Bill' : bill.name,
                      value: '৳${_amountText(bill.amount)}',
                    ),
                  const Divider(height: 12),
                  _BillLine(
                    label: 'Each Member',
                    value: '৳${_amountText(billShare)}',
                    isStrong: true,
                  ),
                ],
              ),
            ),
      columns: const ['Rent', 'Bills', 'Total'],
      lines: isEmpty
          ? const []
          : [
              for (final settlement in settlements)
                _TableLine(settlement.name, [
                  '৳${_amountText(settlement.rent)}',
                  '৳${_amountText(settlement.billShare)}',
                  '৳${_amountText(settlement.rent + settlement.billShare)}',
                ]),
            ],
    );
  }
}

/// Each member's meal balance and fixed cost together.
class _MealPlusFixedCard extends StatelessWidget {
  const _MealPlusFixedCard({required this.settlements, required this.onCopy});

  final List<MemberSettlement> settlements;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      icon: Icons.add_card_outlined,
      title: 'Meal + Fixed Cost',
      color: AppTheme.primary,
      actions: [
        IconButton(
          tooltip: 'Copy',
          onPressed: onCopy,
          icon: const Icon(
            Icons.copy_outlined,
            size: 20,
            color: AppTheme.primary,
          ),
        ),
      ],
      columns: const ['Meals', 'Fixed', 'Total'],
      lastFlex: 4,
      lines: [
        for (final settlement in settlements)
          _TableLine(
            settlement.name,
            [
              _mealBalanceText(settlement.mealBalance.round()),
              '৳${_amountText(settlement.rent + settlement.billShare)}',
              _AmountRow.balance(settlement.name, settlement.finalTotal).text,
            ],
            lastColor: _AmountRow.balance(
              settlement.name,
              settlement.finalTotal,
            ).color,
          ),
      ],
    );
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({
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
      color: isStrong ? AppTheme.textPrimary : AppTheme.textSecondary,
      fontSize: 13.5,
      fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Best Manager: whose duty turn kept food cheapest this month
// ─────────────────────────────────────────────────────────────
String _shortDay(String dateKey) {
  const months = [
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
  final parts = dateKey.split('-').map(int.parse).toList();
  return '${parts[2]} ${months[parts[1] - 1]}';
}

class _BestManagerCard extends StatelessWidget {
  const _BestManagerCard({required this.monthName, required this.report});

  final String monthName;

  /// Null until a turn of the month is finished.
  final BestManager? report;

  void _openRanking(BuildContext context, BestManager report) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                'Best Manager · $monthName',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Month Average ৳${report.averageRate.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              for (final (index, turn) in report.turns.indexed)
                _ManagerRow(
                  rank: index + 1,
                  turn: turn,
                  difference: report.belowAverage(turn),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final best = report?.best;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
        leading: const Icon(
          Icons.emoji_events,
          color: AppTheme.accentDeep,
          size: 30,
        ),
        title: const Text(
          'Best Manager',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          best?.memberName ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: best == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '৳${best.rate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _DifferenceText(report!.belowAverage(best)),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
        onTap: best == null ? null : () => _openRanking(context, report!),
      ),
    );
  }
}

/// "৳4.20 Below Average" in green, or "৳3.10 Above Average".
class _DifferenceText extends StatelessWidget {
  const _DifferenceText(this.difference);

  final double difference;

  @override
  Widget build(BuildContext context) {
    final isBelow = difference >= 0;

    return Text(
      '৳${difference.abs().toStringAsFixed(2)} '
      '${isBelow ? 'Below' : 'Above'} Average',
      style: TextStyle(
        color: isBelow ? AppTheme.success : AppTheme.danger,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ManagerRow extends StatelessWidget {
  const _ManagerRow({
    required this.rank,
    required this.turn,
    required this.difference,
  });

  final int rank;
  final ManagerTurn turn;
  final double difference;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? AppTheme.accentDeep : AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turn.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_shortDay(turn.fromDate)} – ${_shortDay(turn.toDate)}'
                  ' · ${turn.days} Days',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '৳${turn.rate.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _DifferenceText(difference),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Meal rate comparison widget
// ─────────────────────────────────────────────────────────────
class _MealRateComparison extends StatefulWidget {
  const _MealRateComparison({
    required this.groupId,
    required this.previousMonthKey,
    required this.currentRate,
    required this.balance,
  });

  final String groupId;
  final String previousMonthKey;
  final double currentRate;
  final BalanceOptions balance;

  @override
  State<_MealRateComparison> createState() => _MealRateComparisonState();
}

class _MealRateComparisonState extends State<_MealRateComparison> {
  /// Last month's meal rate. Loaded once for each month shown, and
  /// not again every time the page redraws.
  late Future<double?> _previousRate = _load();

  Future<double?> _load() {
    final previousMonthStart = _monthStartFromKey(widget.previousMonthKey);

    return _previousMealRate(
      groupId: widget.groupId,
      previousMonthKey: widget.previousMonthKey,
      previousMonthStart: previousMonthStart,
      balance: widget.balance,
    );
  }

  @override
  void didUpdateWidget(_MealRateComparison oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.groupId != widget.groupId ||
        oldWidget.previousMonthKey != widget.previousMonthKey ||
        !oldWidget.balance.countsLike(
          widget.balance,
          widget.previousMonthKey,
        )) {
      _previousRate = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = widget.currentRate;

    return FutureBuilder<double?>(
      future: _previousRate,
      builder: (context, rateSnapshot) {
        final previousRate = rateSnapshot.data;

        // Nothing to compare with: the card shows the rate alone.
        if (previousRate == null || previousRate == 0) {
          return const SizedBox.shrink();
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
  required BalanceOptions balance,
}) async {
  final firestore = FirebaseFirestore.instance;
  final groupRef = firestore.collection('groups').doc(groupId);

  final settingsDoc = await groupRef
      .collection('monthlySettings')
      .doc(previousMonthKey)
      .get();
  final settings = settingsDoc.data();
  final saved = MonthSummary.fromSettings(settings);
  if (saved != null) {
    return saved.totalMealNumber > 0 ? saved.mealRate : null;
  }
  final minimumMeals = balance.minimumMealsOf(settings, previousMonthKey);
  final shopDue = balance.shopDueOf(settings, previousMonthKey);

  final members = await GroupMemberService.fetchActive(groupId);

  // That month's records only.
  final mealsSnapshot = await MonthRecords.meals(
    groupId,
    previousMonthStart,
  ).get();
  final expensesSnapshot = await MonthRecords.expenses(
    groupId,
    previousMonthStart,
  ).get();
  final plans = await MealPlanService.fetchAll(groupId);
  final calcMembers = [
    for (final member in members) CalcMember(id: member.id, name: member.name),
  ];

  final rules = MonthRules.fromSettings(settings);
  final result = MonthlyCalculator.calculate(
    month: previousMonthStart,
    members: calcMembers,
    meals: _withPlannedMeals(
      mealsSnapshot.docs.map(_mealRecord).toList(),
      plans: plans,
      members: calcMembers,
      month: previousMonthStart,
      rules: rules,
    ),
    expenses: expensesSnapshot.docs.map(_expenseRecord),
    minimumMeals: minimumMeals,
    shopDue: shopDue,
    rules: rules,
  );

  if (result.totalMealNumber <= 0) return null;
  return result.mealRate;
}

/// The saved meal entries, plus what the meal plans count for the
/// days of [month] that have no entry, counted as the month's [rules]
/// say: cancelled meals as zero, and removed leavers left out.
List<MealRecord> _withPlannedMeals(
  List<MealRecord> meals, {
  required List<MemberMealPlan> plans,
  required List<CalcMember> members,
  required DateTime month,
  required MonthRules rules,
}) {
  return rules.applyToMeals([
    ...meals,
    ...MealPlans.automaticMeals(
      plans: plans,
      meals: meals,
      activeMemberIds: {for (final member in members) member.id},
      month: month,
      today: DateTime.now(),
    ),
  ]);
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
