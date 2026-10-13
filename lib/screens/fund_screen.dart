import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/fund_service.dart';
import '../services/group_member_service.dart';
import '../services/hostel_fund.dart';
import '../theme/app_theme.dart';

/// Opens the form where an admin records money collected from a
/// member, unless the hostel is read-only. [month] is the month the
/// money is for; the current one when left out.
Future<void> showCollectFundForm(
  BuildContext context, {
  required String groupId,
  DateTime? month,
}) async {
  if (!await ensureHostelEditable(context, groupId)) return;
  if (!context.mounted) return;

  final now = month ?? DateTime.now();
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showDialog<String>(
    context: context,
    builder: (_) =>
        _DepositDialog(groupId: groupId, month: DateTime(now.year, now.month)),
  );

  if (saved != null) {
    messenger.showSnackBar(SnackBar(content: Text(saved)));
  }
}

/// The hostel fund for one month: the money collected from members
/// in advance, and how much of it has been spent. Admins record the
/// deposits here.
class FundScreen extends StatefulWidget {
  const FundScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.month,
  });

  final String groupId;
  final bool isAdmin;

  /// The month to show. The current month when left out.
  final DateTime? month;

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  late final DateTime _month;
  late final Stream<List<FundDeposit>> _depositsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _expensesStream;

  @override
  void initState() {
    super.initState();

    final month = widget.month ?? DateTime.now();
    _month = DateTime(month.year, month.month);
    _depositsStream = FundService.watch(widget.groupId);
    _expensesStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .snapshots();
  }

  Future<void> _addDeposit() {
    return showCollectFundForm(context, groupId: widget.groupId, month: _month);
  }

  Future<void> _deleteDeposit(FundDeposit deposit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Deposit?'),
          content: Text(
            'Delete the ৳${_amount(deposit.amount)} deposit of '
            '${deposit.memberName}? It will no longer count as paid.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await FundService.delete(widget.groupId, deposit.id);
      messenger.showSnackBar(const SnackBar(content: Text('Deposit deleted.')));
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to delete the deposit.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hostel Fund')),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addDeposit,
              icon: const Icon(Icons.add),
              label: const Text('Collect Fund'),
            )
          : null,
      body: SafeArea(
        child: StreamBuilder<List<FundDeposit>>(
          stream: _depositsStream,
          builder: (context, depositsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _expensesStream,
              builder: (context, expensesSnapshot) {
                if (depositsSnapshot.hasError || expensesSnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load the hostel fund.'),
                  );
                }

                if (!depositsSnapshot.hasData || !expensesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final fund = FundCalculator.summarize(
                  month: _month,
                  deposits: depositsSnapshot.data!,
                  expenses: [
                    for (final expense in expensesSnapshot.data!.docs)
                      FundService.expenseRecord(expense.data()),
                  ],
                );

                return _buildFund(context, fund);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFund(BuildContext context, FundSummary fund) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Card(
          color: AppTheme.surfaceSoft,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthName(_month),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _FundLine(label: 'Total collected', amount: fund.collected),
                _FundLine(label: 'Expenses from the fund', amount: fund.spent),
                const Divider(height: 20),
                _FundLine(
                  label: 'Cash in hand',
                  amount: fund.balance,
                  isStrong: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'A deposit counts as paid by that member in the Overall '
          'calculation. "Spent" is what was marked as paid from the '
          'fund when expenses were added.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (fund.deposits.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                widget.isAdmin
                    ? 'Nothing collected this month. Tap Collect Fund when a '
                          'member gives money to the fund.'
                    : 'No deposits have been recorded this month.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final deposit in fund.deposits)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.savings_outlined),
                ),
                title: Text(
                  deposit.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_dateText(deposit.date)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '৳${_amount(deposit.amount)}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (widget.isAdmin)
                      IconButton(
                        tooltip: 'Delete deposit',
                        onPressed: () => _deleteDeposit(deposit),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

String _amount(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

String _dateText(DateTime? date) {
  if (date == null) return 'Unknown date';

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
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

class _FundLine extends StatelessWidget {
  const _FundLine({
    required this.label,
    required this.amount,
    this.isStrong = false,
  });

  final String label;
  final double amount;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isStrong && amount < 0 ? AppTheme.danger : AppTheme.textPrimary,
      fontSize: isStrong ? 18 : 15,
      fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            amount < 0 ? '−৳${_amount(-amount)}' : '৳${_amount(amount)}',
            style: style,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add a deposit
// ─────────────────────────────────────────────────────────────
class _DepositDialog extends StatefulWidget {
  const _DepositDialog({required this.groupId, required this.month});

  final String groupId;
  final DateTime month;

  @override
  State<_DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends State<_DepositDialog> {
  final _amountController = TextEditingController();

  List<GroupMember>? _members;
  String? _memberId;
  late DateTime _date;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Today in the current month, otherwise the month's first day.
    final now = DateTime.now();
    final isCurrentMonth =
        now.year == widget.month.year && now.month == widget.month.month;
    _date = isCurrentMonth
        ? DateTime(now.year, now.month, now.day)
        : widget.month;

    _loadMembers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await GroupMemberService.watch(widget.groupId).first;
      if (!mounted) return;

      setState(() => _members = members);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _members = const [];
        _error = 'Unable to load members.';
      });
    }
  }

  Future<void> _changeDate() async {
    final now = DateTime.now();
    final lastDay = DateTime(widget.month.year, widget.month.month + 1, 0);

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.month,
      lastDate: lastDay.isAfter(now)
          ? DateTime(now.year, now.month, now.day)
          : lastDay,
    );

    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    final member = _members
        ?.where((member) => member.id == _memberId)
        .firstOrNull;

    if (member == null) {
      setState(() => _error = 'Please select a member.');
      return;
    }

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await FundService.add(
        groupId: widget.groupId,
        memberId: member.id,
        memberName: member.name,
        amount: amount,
        date: _date,
      );

      if (!mounted) return;

      Navigator.of(
        context,
      ).pop('৳${_amount(amount)} from ${member.name} was added to the fund.');
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _error = saveErrorMessage(
          error,
          fallback: 'Unable to save the deposit.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;

    return AlertDialog(
      title: const Text('Collect Fund'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (members == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _memberId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Received from',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final member in members)
                    DropdownMenuItem<String>(
                      value: member.id,
                      child: Text(member.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _memberId = value),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Example: 3000',
                prefixText: '৳ ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(_dateText(_date)),
              trailing: TextButton(
                onPressed: _isSaving ? null : _changeDate,
                child: const Text('Change'),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppTheme.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving || members == null ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
