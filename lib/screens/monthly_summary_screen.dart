import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/fixed_costs.dart';
import '../services/group_member_service.dart';
import '../services/hostel_settings.dart';
import '../services/daily_trend.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/month_archive.dart';
import '../services/month_records.dart';
import '../services/monthly_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/month_trend_chart.dart';
import 'fixed_costs_screen.dart';
import 'hostel_dashboard_screen.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.embedded = false,
  });

  final String groupId;
  final bool isAdmin;

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

  /// Last month's running totals, for the chart.
  late Future<DailyTrend?> _previousTrend;

  _CalcTab _tab = _CalcTab.meals;

  /// False while the app settles meals only: the Fixed and Overall
  /// tabs are then not offered. Off until other costs are released.
  final bool _fixedCostsEnabled = false;

  /// True when the admins allow minimum meals and shop due to be
  /// entered on any day, not only at the month's end.
  bool _specialPermission = false;
  StreamSubscription<HostelSettings>? _settingsSubscription;

  /// The members whose own figures are shown under their balance.
  final Set<String> _openMemberIds = {};
  bool _showFixedDetails = false;

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

  Future<void> _copySummaryCard({required MonthlyCalculation result}) async {
    final buffer = StringBuffer();
    buffer.writeln(_bold('HostelMate Monthly Summary'));
    buffer.writeln(_bold(_monthName(_selectedMonth)));
    buffer.writeln('');
    buffer.writeln(
      '${_bold('Meal Rate')}: ৳${result.mealRate.toStringAsFixed(2)}',
    );
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
            'to $closes. Wait until then, or turn on Special permission '
            'in Settings.',
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
    if (!_canEnterClosingFigures()) return;

    final due = await _showNumberDialog(
      title: 'Set Monthly Shop Due',
      label: 'Shop Due Amount',
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
          final minimumMeals =
              (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
          final shopDue = (settings?['shopDue'] as num?)?.toDouble() ?? 0;
          final fixedCosts = FixedCostsCalculator.resolve(
            settingsByMonth,
            monthKey,
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
                            ),
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

    // A hostel that does not use fixed costs sees the meals only.
    final tab = _fixedCostsEnabled ? _tab : _CalcTab.meals;

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

        // ─── Meals / Fixed / Overall ───
        if (_fixedCostsEnabled)
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
        if (_fixedCostsEnabled) const SizedBox(height: 16),

        // ═══ Meals ═══
        if (tab == _CalcTab.meals) ...[
          _RateHero(
            mealRate: result.mealRate,
            totalMealNumber: result.totalMealNumber,
            totalActualMeals: result.totalActualMeals,
            totalExpense: result.totalExpense,
            shopDue: shopDue,
            minimumMeals: minimumMeals,
            previousMonthKey: _monthKey(previousMonth),
            groupId: widget.groupId,
            onCopy: () => _copySummaryCard(result: result),
            onOpenMeals: hasRecords ? () => _openRecords(0) : null,
            onOpenExpenses: hasRecords ? () => _openRecords(1) : null,
            onEditMinimum: canChange
                ? () => _setMinimumMeals(
                    currentMinimum: minimumMeals,
                    currentShopDue: shopDue,
                  )
                : null,
            onEditShopDue: canChange
                ? () => _setShopDue(
                    currentDue: shopDue,
                    minimumMeals: minimumMeals,
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
            ),
          if (trend != null) ...[
            const SizedBox(height: 14),
            _trendChart(trend),
          ],
        ],

        // ═══ Fixed ═══
        if (tab == _CalcTab.fixed) ...[
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
        if (tab == _CalcTab.overall) ...[
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

  /// The month's running totals day by day, up to today for the
  /// current month. Null when there is nothing to show, as for a month
  /// whose records are no longer kept.
  DailyTrend? _trendOf(
    DateTime month, {
    required List<MealRecord> meals,
    required Iterable<ExpenseRecord> expenses,
    required List<MemberMealPlan> plans,
    required List<CalcMember> members,
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
      ),
      expenses: expenses,
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

    return _trendOf(
      previous,
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
                label: 'Each Member Pays',
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
                label: 'Total Rent',
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
    required this.previousMonthKey,
    required this.groupId,
    required this.onCopy,
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
  final String previousMonthKey;
  final String groupId;
  final VoidCallback onCopy;

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
              IconButton(
                tooltip: 'Copy summary',
                onPressed: onCopy,
                icon: Icon(
                  Icons.copy_outlined,
                  size: 19,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HeroFigure(
                        label: 'Min Meals',
                        value: minimumMeals > 0
                            ? _amountText(minimumMeals)
                            : '—',
                        onTap: onEditMinimum,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroFigure(
                        label: 'Shop Due',
                        value: shopDue > 0 ? '৳${_amountText(shopDue)}' : '—',
                        onTap: onEditShopDue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  });

  final List<MemberCalculation> members;
  final Set<String> openMemberIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onCopyBalances;
  final VoidCallback onCopyTable;

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
                PopupMenuButton<bool>(
                  tooltip: 'Copy',
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                  onSelected: (isTable) =>
                      isTable ? onCopyTable() : onCopyBalances(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: false, child: Text('Copy Balances')),
                    PopupMenuItem(value: true, child: Text('Copy Full Table')),
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

// ─────────────────────────────────────────────────────────────
// Meal rate comparison widget
// ─────────────────────────────────────────────────────────────
class _MealRateComparison extends StatefulWidget {
  const _MealRateComparison({
    required this.groupId,
    required this.previousMonthKey,
    required this.currentRate,
  });

  final String groupId;
  final String previousMonthKey;
  final double currentRate;

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
    );
  }

  @override
  void didUpdateWidget(_MealRateComparison oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.groupId != widget.groupId ||
        oldWidget.previousMonthKey != widget.previousMonthKey) {
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
  final minimumMeals = (settings?['minimumMeals'] as num?)?.toDouble() ?? 0;
  final shopDue = (settings?['shopDue'] as num?)?.toDouble() ?? 0;

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
