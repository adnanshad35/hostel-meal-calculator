import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/fund_service.dart';
import '../services/group_member_service.dart';
import '../services/hostel_fund.dart';
import '../services/monthly_calculator.dart';
import '../services/notification_service.dart';
import 'fund_screen.dart';

/// Opens the Add Expense form, unless the hostel is read-only.
Future<void> showExpenseForm(
  BuildContext context, {
  required String groupId,
  required bool isAdmin,
}) async {
  if (!await ensureHostelEditable(context, groupId)) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => _ExpenseFormDialog(groupId: groupId, isAdmin: isAdmin),
  );
}

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

  Future<void> _openExpenseForm(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? expense,
  }) async {
    if (!await ensureHostelEditable(context, groupId)) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        groupId: groupId,
        isAdmin: isAdmin,
        expense: expense,
      ),
    );
  }

  void _openTotalExpenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TotalExpensesScreen(groupId: groupId, isAdmin: isAdmin),
      ),
    );
  }

  void _openMyExpenses(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyExpensesScreen(groupId: groupId, currentUserId: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Update')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExpenseForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load expenses.'));
          }

          final expenses = _currentMonthExpenses(snapshot.data);

          double totalExpense = 0;
          double myExpense = 0;

          for (final expense in expenses) {
            final data = expense.data();
            final amount = data['amount'];
            final value = amount is num ? amount.toDouble() : 0.0;

            totalExpense += value;

            // Only what came out of the member's own pocket.
            if (data['paidById'] == currentUser.uid) {
              myExpense += FundService.expenseRecord(data).pocketPart;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Total Expense',
                      value: '৳${totalExpense.toStringAsFixed(2)}',
                      subtitle: 'This month',
                      color: const Color(0xFF2E7D32),
                      onTap: () => _openTotalExpenses(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      icon: Icons.person_outline,
                      title: 'My Expense',
                      value: '৳${myExpense.toStringAsFixed(2)}',
                      subtitle: 'This month',
                      color: const Color(0xFF2E7D32),
                      onTap: () => _openMyExpenses(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (expenses.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No expenses this month',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tap Add Expense to record the first expense.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  color: const Color(0xFFE8F5E9),
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2E7D32),
                    ),
                    title: Text(
                      '${expenses.length} expense'
                      '${expenses.length == 1 ? '' : 's'} this month',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Tap Total Expense to view the full list.',
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              if (isAdmin)
                _AdminFundCard(
                  groupId: groupId,
                  expenses: [
                    for (final expense in expenses)
                      FundService.expenseRecord(expense.data()),
                  ],
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FundScreen(groupId: groupId, isAdmin: isAdmin),
                        ),
                      );
                    },
                    leading: const Icon(
                      Icons.savings_outlined,
                      color: Color(0xFF2E7D32),
                    ),
                    title: const Text(
                      'Hostel Fund',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Money collected from members in advance.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// The fund at a glance, for admins
// ─────────────────────────────────────────────────────────────
/// This month's fund for the admin who holds it: what was collected,
/// what was spent from it and the cash left, with a button to record
/// money collected from a member.
class _AdminFundCard extends StatefulWidget {
  const _AdminFundCard({required this.groupId, required this.expenses});

  final String groupId;

  /// This month's expenses.
  final List<ExpenseRecord> expenses;

  @override
  State<_AdminFundCard> createState() => _AdminFundCardState();
}

class _AdminFundCardState extends State<_AdminFundCard> {
  late final Stream<List<FundDeposit>> _deposits = FundService.watch(
    widget.groupId,
  );

  void _openFund() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FundScreen(groupId: widget.groupId, isAdmin: true),
      ),
    );
  }

  static String _taka(double value) {
    final text = value.abs() % 1 == 0
        ? value.abs().toInt().toString()
        : value.abs().toStringAsFixed(2);

    return value < 0 ? '−৳$text' : '৳$text';
  }

  Widget _figure(String label, double value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _taka(value),
              style: TextStyle(
                color: color ?? const Color(0xFF17211C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FundDeposit>>(
      stream: _deposits,
      builder: (context, snapshot) {
        final fund = FundCalculator.summarize(
          month: DateTime.now(),
          deposits: snapshot.data ?? const [],
          expenses: widget.expenses,
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openFund,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.savings_outlined,
                        color: Color(0xFF2E7D32),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Hostel Fund',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.outline,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.hasError)
                    const Text('Unable to load the fund.')
                  else
                    Row(
                      children: [
                        _figure('Collected', fund.collected),
                        const SizedBox(width: 8),
                        _figure('Expenses', fund.spent),
                        const SizedBox(width: 8),
                        _figure(
                          'Cash in hand',
                          fund.balance,
                          color: fund.balance < 0
                              ? Colors.red
                              : const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        showCollectFundForm(context, groupId: widget.groupId),
                    icon: const Icon(Icons.add),
                    label: const Text('Collect Fund'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Total expenses screen
// ─────────────────────────────────────────────────────────────
class TotalExpensesScreen extends StatelessWidget {
  const TotalExpensesScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

  Future<void> _openExpenseForm(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? expense,
  }) async {
    if (!await ensureHostelEditable(context, groupId)) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        groupId: groupId,
        isAdmin: isAdmin,
        expense: expense,
      ),
    );
  }

  Future<void> _deleteExpense(
    BuildContext context, {
    required DocumentSnapshot<Map<String, dynamic>> expense,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Expense?'),
          content: Text(
            'Delete "$name" from the hostel records? '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await expense.reference.delete();
      messenger.showSnackBar(SnackBar(content: Text('"$name" was deleted.')));
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to delete the expense.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Total Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExpenseForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load expenses.'));
          }

          final expenses = _currentMonthExpenses(snapshot.data);

          if (expenses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No expenses this month.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final total = expenses.fold<double>(0, (currentTotal, expense) {
            final amount = expense.data()['amount'];
            return currentTotal + (amount is num ? amount.toDouble() : 0);
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Shared expenses this month'),
                      const SizedBox(height: 6),
                      Text(
                        '৳${total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...expenses.map((expense) {
                final data = expense.data();
                final name = data['name'] as String? ?? 'Expense';
                final paidByName =
                    data['paidByName'] as String? ?? 'Unknown member';
                final paidById = data['paidById'] as String? ?? '';
                final amount = data['amount'];
                final date = (data['date'] as Timestamp?)?.toDate();

                final canEdit = isAdmin || paidById == currentUser.uid;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_outlined),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_formatDate(date)}${_expenseNote(data)}\n'
                      'Paid by $paidByName${_expenseDetails(data)}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '৳${_formatAmount(amount)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (isAdmin)
                          PopupMenuButton<String>(
                            tooltip: 'Expense options',
                            onSelected: (action) {
                              if (action == 'edit') {
                                _openExpenseForm(context, expense: expense);
                              } else {
                                _deleteExpense(
                                  context,
                                  expense: expense,
                                  name: name,
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          )
                        else if (canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Edit expense',
                            onPressed: () {
                              _openExpenseForm(context, expense: expense);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// My expenses screen — personal history
// ─────────────────────────────────────────────────────────────
class MyExpensesScreen extends StatelessWidget {
  const MyExpensesScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  final String groupId;
  final String currentUserId;

  Future<void> _openExpenseForm(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? expense,
  }) async {
    if (!await ensureHostelEditable(context, groupId)) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        groupId: groupId,
        isAdmin: false,
        expense: expense,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExpenseForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your expenses.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = _currentMonthExpenses(snapshot.data)
              .where((d) => d.data()['paidById'] == currentUserId)
              .toList();

          docs.sort((a, b) {
            final aDate = (a.data()['date'] as Timestamp?)?.toDate();
            final bDate = (b.data()['date'] as Timestamp?)?.toDate();
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          double total = 0;
          for (final d in docs) {
            total += FundService.expenseRecord(d.data()).pocketPart;
          }

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Color(0xFF2E7D32),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'You have not added any expense yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap Add Expense to record your first expense.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Paid from my own pocket'),
                      const SizedBox(height: 6),
                      Text(
                        '৳${total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...docs.map((expense) {
                final data = expense.data();
                final name = data['name'] as String? ?? 'Expense';
                final amount = data['amount'];
                final date = (data['date'] as Timestamp?)?.toDate();

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_outlined),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_formatDate(date)}${_expenseNote(data)}'
                      '${_expenseDetails(data)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '৳${_formatAmount(amount)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Edit expense',
                          onPressed: () {
                            _openExpenseForm(context, expense: expense);
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary tile
// ─────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
/// Expenses dated in the current month, matching what the monthly
/// calculation counts and what a month reset clears.
List<QueryDocumentSnapshot<Map<String, dynamic>>> _currentMonthExpenses(
  QuerySnapshot<Map<String, dynamic>>? snapshot,
) {
  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month);
  final nextMonth = DateTime(now.year, now.month + 1);

  return (snapshot?.docs ?? []).where((expense) {
    final date = expense.data()['date'];
    if (date is! Timestamp) return false;

    final value = date.toDate();
    return !value.isBefore(firstDay) && value.isBefore(nextMonth);
  }).toList();
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown date';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatAmount(dynamic amount) {
  if (amount is num) {
    return amount.toDouble().toStringAsFixed(2);
  }
  return '0.00';
}

/// Marks an expense that is a shared bill or used the fund's money.
String _expenseNote(Map<String, dynamic> data) {
  final expense = FundService.expenseRecord(data);
  final notes = [
    if (expense.isBill) 'Bill',
    if (expense.fundPart > 0 && expense.pocketPart == 0)
      'from fund'
    else if (expense.fundPart > 0)
      '৳${_formatAmount(expense.fundPart)} from fund',
  ];

  return notes.isEmpty ? '' : '  •  ${notes.join(', ')}';
}

/// What the member wrote about how the money was spent, on new lines.
String _expenseDetails(Map<String, dynamic> data) {
  final details = [
    for (final key in const ['fundNote', 'pocketNote'])
      if (data[key] is String && (data[key] as String).trim().isNotEmpty)
        (data[key] as String).trim(),
  ];

  return details.isEmpty ? '' : '\n${details.join('\n')}';
}

/// The parts of the expense form a member can hide when their hostel
/// does not use them. The choice is saved on their own profile, so it
/// follows them to every device.
enum _FormField {
  shareCost('Share cost', 'Shared bills such as water'),
  pocket('My pocket', 'How much was your own money'),
  fund('From meal fund', 'How much came from the hostel fund'),
  total('Total', 'The sum of everything entered'),
  date('Date', 'Hidden, an expense is saved for today');

  const _FormField(this.label, this.hint);

  final String label;
  final String hint;
}

String _plainNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

/// One shared bill being typed into the expense form.
class _ShareCostRow {
  _ShareCostRow({String description = '', String cost = ''})
    : description = TextEditingController(text: description),
      cost = TextEditingController(text: cost);

  final TextEditingController description;
  final TextEditingController cost;

  void dispose() {
    description.dispose();
    cost.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// Expense form dialog
// ─────────────────────────────────────────────────────────────
class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.groupId,
    required this.isAdmin,
    this.expense,
  });

  final String groupId;
  final bool isAdmin;
  final DocumentSnapshot<Map<String, dynamic>>? expense;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  // What was bought.
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  /// The shared bill, such as water, if one was added. At most one,
  /// saved as its own record.
  final _shareCosts = <_ShareCostRow>[];

  // How it was paid. Together these must equal the total.
  final _pocketController = TextEditingController();
  final _fundController = TextEditingController();

  /// Whether the member typed these themselves. One that was not
  /// typed is filled in as the rest of the total.
  bool _pocketTyped = false;
  bool _fundTyped = false;

  late DateTime _selectedDate;

  List<GroupMember> _members = [];
  StreamSubscription<List<GroupMember>>? _membersSubscription;
  String? _selectedMemberId;

  bool _isLoadingMembers = false;
  bool _isSaving = false;

  /// Parts of the form this member has switched off.
  Set<_FormField> _hidden = {};

  /// Parts that hold something in the expense being edited. They are
  /// shown even when switched off, so nothing is changed unseen.
  final _needed = <_FormField>{};

  bool _shows(_FormField field) {
    return !_hidden.contains(field) || _needed.contains(field);
  }

  /// True when the member says how much came from each source. With
  /// only one source switched on, there is nothing to split.
  bool get _splitsPayment {
    return _shows(_FormField.pocket) && _shows(_FormField.fund);
  }

  bool get _isEditing => widget.expense != null;

  /// True when a saved shared bill is being edited. It then shows
  /// only its own line instead of the meal expense.
  bool _isEditingBill = false;

  User get _currentUser => FirebaseAuth.instance.currentUser!;

  String get _ownName {
    final name = _currentUser.displayName?.trim() ?? '';
    return name.isNotEmpty ? name : _currentUser.email ?? 'Member';
  }

  @override
  void initState() {
    super.initState();

    final data = widget.expense?.data();

    _selectedDate = (data?['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    _selectedMemberId = data?['paidById'] as String? ?? _currentUser.uid;

    if (data != null) _loadSaved(data);

    if (widget.isAdmin && !_isEditing) {
      _watchMembers();
    }

    _loadFormSettings();
  }

  DocumentReference<Map<String, dynamic>> get _profile {
    return FirebaseFirestore.instance.collection('users').doc(_currentUser.uid);
  }

  Future<void> _loadFormSettings() async {
    try {
      final saved = (await _profile.get()).data()?['expenseFormHidden'];
      if (saved is! List || !mounted) return;

      setState(() {
        _hidden = {
          for (final field in _FormField.values)
            if (saved.contains(field.name)) field,
        };
        _applyHidden();
      });
    } on FirebaseException {
      // The whole form is shown.
    }
  }

  /// Empties the payment fields that are hidden, so they cannot hold
  /// an amount nobody can see.
  void _applyHidden() {
    if (!_shows(_FormField.fund)) {
      _fundController.clear();
      _fundTyped = false;
    }
    if (!_shows(_FormField.pocket)) {
      _pocketTyped = false;
    }
    if (!_shows(_FormField.shareCost)) {
      for (final row in _shareCosts) {
        row.dispose();
      }
      _shareCosts.clear();
    }
    _balancePayment();
  }

  Future<void> _openFormSettings() async {
    final chosen = await showDialog<Set<_FormField>>(
      context: context,
      builder: (_) => _FormSettingsDialog(hidden: {..._hidden}),
    );

    if (chosen == null || !mounted) return;

    setState(() {
      _hidden = chosen;
      _applyHidden();
    });

    try {
      await _profile.update({
        'expenseFormHidden': [for (final field in chosen) field.name],
      });
    } on FirebaseException {
      if (!mounted) return;
      _showMessage('The form settings could not be saved.');
    }
  }

  void _loadSaved(Map<String, dynamic> data) {
    final saved = FundService.expenseRecord(data);
    final name = (data['name'] as String? ?? '').trim();

    if (saved.isBill) {
      _isEditingBill = true;
      _shareCosts.add(
        _ShareCostRow(description: name, cost: _plainNumber(saved.amount)),
      );
    } else {
      final more = (data['pocketNote'] as String? ?? '').trim();
      _descriptionController.text = more.isEmpty ? name : '$name\n$more';
      _amountController.text = _plainNumber(saved.amount);
    }

    // The fund's part stays as saved; the pocket's part follows the
    // amount if it is changed.
    _fundTyped = saved.fundPart > 0;
    if (saved.fundPart > 0) {
      _fundController.text = _plainNumber(saved.fundPart);
      _needed.add(_FormField.fund);
    }
    if (saved.pocketPart > 0) _needed.add(_FormField.pocket);
    if (saved.isBill) _needed.add(_FormField.shareCost);
    _needed.add(_FormField.date);
    _pocketController.text = _plainNumber(saved.pocketPart);
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _descriptionController.dispose();
    _amountController.dispose();
    _pocketController.dispose();
    _fundController.dispose();
    for (final row in _shareCosts) {
      row.dispose();
    }
    super.dispose();
  }

  void _watchMembers() {
    _isLoadingMembers = true;

    _membersSubscription = GroupMemberService.watch(widget.groupId).listen(
      (activeMembers) {
        final members = [...activeMembers];

        if (!members.any((member) => member.id == _currentUser.uid)) {
          members.add(
            GroupMember(
              id: _currentUser.uid,
              name: _ownName,
              isAppUser: true,
              userId: _currentUser.uid,
            ),
          );
          members.sort(GroupMember.compareByName);
        }

        if (!mounted) return;

        setState(() {
          _members = members;
          _isLoadingMembers = false;
          if (!_members.any((m) => m.id == _selectedMemberId)) {
            _selectedMemberId = _currentUser.uid;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() => _isLoadingMembers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load members.')),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null && mounted) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  static double _amountIn(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value == null || value < 0 ? 0 : value;
  }

  static bool _isInvalid(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return false;

    final value = double.tryParse(text);
    return value == null || value < 0;
  }

  double get _mealAmount => _isEditingBill ? 0 : _amountIn(_amountController);

  double get _total {
    return _shareCosts.fold<double>(
      _mealAmount,
      (total, row) => total + _amountIn(row.cost),
    );
  }

  /// Keeps "My pocket" and "From meal fund" adding up to the total:
  /// whichever one the member has not typed becomes the rest.
  void _balancePayment() {
    final total = _total;

    void fill(TextEditingController target, double other) {
      final rest = total - other;
      target.text = rest > 0 ? _plainNumber(rest) : '';
    }

    if (!_pocketTyped) {
      fill(_pocketController, _amountIn(_fundController));
    } else if (!_fundTyped) {
      fill(_fundController, _amountIn(_pocketController));
    }
  }

  void _onCostsChanged() => setState(_balancePayment);

  /// Opens the calculator. "Use It" puts the result into [target].
  Future<void> _openCalculator(
    TextEditingController target, {
    VoidCallback? onUsed,
  }) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _CalculatorDialog(initialValue: target.text.trim()),
    );

    if (result == null || !mounted) return;

    setState(() {
      target.text = _plainNumber(result);
      onUsed?.call();
      _balancePayment();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveExpense() async {
    if ([
      _amountController,
      _pocketController,
      _fundController,
    ].any(_isInvalid)) {
      _showMessage('Please enter valid amounts.');
      return;
    }

    final mealAmount = _mealAmount;

    // The first line names the expense; the rest is kept as detail.
    final lines = _descriptionController.text.trim().split('\n');
    final name = lines.first.trim();
    final details = lines.skip(1).join('\n').trim();

    if (mealAmount > 0 && name.isEmpty) {
      _showMessage('Please describe the expense.');
      return;
    }
    if (mealAmount <= 0 && name.isNotEmpty && !_isEditingBill) {
      _showMessage('Please enter the amount of the expense.');
      return;
    }

    // Share cost lines left completely empty are ignored.
    final bills = <({String name, double amount})>[];

    for (final row in _shareCosts) {
      final description = row.description.text.trim();
      final costText = row.cost.text.trim();

      if (description.isEmpty && costText.isEmpty) continue;

      final cost = double.tryParse(costText);

      if (cost == null || cost <= 0) {
        _showMessage('Please enter the cost of each share cost.');
        return;
      }
      if (description.isEmpty) {
        _showMessage('Please describe each share cost, for example "Water".');
        return;
      }

      bills.add((name: description, amount: cost));
    }

    if (mealAmount <= 0 && bills.isEmpty) {
      _showMessage('Please enter an amount.');
      return;
    }

    final total = bills.fold<double>(
      mealAmount,
      (running, bill) => running + bill.amount,
    );
    // The split is typed only when both sources are in use. With one
    // of them, the whole total came from it.
    final double fund;
    final double pocket;

    if (_splitsPayment) {
      fund = _amountIn(_fundController);
      pocket = _amountIn(_pocketController);
    } else if (_shows(_FormField.fund) && !_shows(_FormField.pocket)) {
      fund = total;
      pocket = 0;
    } else {
      fund = 0;
      pocket = total;
    }

    if (pocket < 0) {
      _showMessage('From meal fund cannot be more than the total.');
      return;
    }

    if ((pocket + fund - total).abs() > 0.005) {
      _showMessage(
        'My pocket and From meal fund must add up to the total of '
        '৳${_plainNumber(total)}.',
      );
      return;
    }

    final selectedMember = _members
        .where((member) => member.id == _selectedMemberId)
        .firstOrNull;

    final paidById = widget.isAdmin && !_isEditing
        ? _selectedMemberId ?? _currentUser.uid
        : _currentUser.uid;

    final paidByName = widget.isAdmin && !_isEditing
        ? selectedMember?.name ?? 'Member'
        : _ownName;

    // Built in one tested place, so a meal cost is always saved as a
    // meal expense and a share cost as a shared bill.
    final entry = ExpenseEntry.split(
      name: name,
      details: details,
      mealCost: mealAmount,
      shareCosts: [
        for (final bill in bills) (name: bill.name, amount: bill.amount),
      ],
      fromFund: fund,
    );
    final mealFields = entry.meal;
    final billFields = entry.bills;

    setState(() => _isSaving = true);

    try {
      final expenses = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses');

      if (_isEditing) {
        await expenses.doc(widget.expense!.id).update({
          ...(_isEditingBill ? billFields.first : mealFields),
          'date': Timestamp.fromDate(_selectedDate),
          'updatedBy': _currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final common = <String, dynamic>{
          'date': Timestamp.fromDate(_selectedDate),
          'paidById': paidById,
          'paidByName': paidByName,
          'enteredBy': _currentUser.uid,
          'enteredByName': _ownName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Meals and shared bills are counted differently, so each is
        // its own record, saved together.
        final batch = FirebaseFirestore.instance.batch();

        if (mealAmount > 0) {
          batch.set(expenses.doc(), {...mealFields, ...common});
        }
        for (final fields in billFields) {
          batch.set(expenses.doc(), {...fields, ...common});
        }

        await batch.commit();

        // Not awaited: the expense is saved either way.
        unawaited(
          NotificationService.notifyGroup(
            groupId: widget.groupId,
            title: 'New expense',
            message:
                '${name.isEmpty ? bills.first.name : name} · '
                '৳${_plainNumber(total)}, paid by $paidByName',
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(
        saveErrorMessage(error, fallback: 'Unable to save expense.'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _amountDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      hintText: '0',
      prefixText: '৳ ',
      isDense: true,
      border: const OutlineInputBorder(),
      suffixIcon: suffixIcon,
    );
  }

  Widget _calculatorButton(
    TextEditingController target, {
    VoidCallback? onUsed,
  }) {
    return IconButton(
      tooltip: 'Calculator',
      visualDensity: VisualDensity.compact,
      onPressed: _isSaving
          ? null
          : () => _openCalculator(target, onUsed: onUsed),
      icon: const Icon(Icons.calculate_outlined, size: 20),
    );
  }

  /// One thing that was paid for: its description across the full
  /// width, a line, and its cost underneath, in a single box.
  Widget _costLine({
    required TextEditingController description,
    required TextEditingController amount,
    required String label,
    required String hint,
    int maxLines = 1,
    Widget? trailing,
    String? title,
  }) {
    // The box draws the outline, so the fields inside have none.
    const plain = InputDecoration(
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    final box = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5DDD8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: description,
            enabled: !_isSaving,
            // The main description is two lines tall, with room for
            // what was bought; a share cost is a single line.
            minLines: maxLines > 1 ? 2 : 1,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: plain.copyWith(hintText: '$label, e.g. $hint'),
          ),
          const Divider(height: 1, color: Color(0xFFD5DDD8)),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Text(
                  'Cost',
                  style: TextStyle(
                    color: Color(0xFF647069),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: amount,
                  enabled: !_isSaving,
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _onCostsChanged(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: plain.copyWith(hintText: '0', prefixText: '৳ '),
                ),
              ),
              _calculatorButton(amount),
              ?trailing,
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );

    if (title == null) return box;

    // Named, so two boxes can be told apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17211C),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        box,
      ],
    );
  }

  /// How much of the total came from one place: its name on the left
  /// and the amount on the right.
  Widget _paymentLine({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onTyped,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: TextField(
              controller: controller,
              enabled: !_isSaving,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                setState(() {
                  onTyped();
                  _balancePayment();
                });
              },
              decoration: _amountDecoration(
                suffixIcon: _calculatorButton(controller, onUsed: onTyped),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final formattedDate = '$day/$month/${_selectedDate.year}';

    // Only an admin adding an expense chooses whose it is.
    final canPickMember = widget.isAdmin && !_isEditing;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
      title: Row(
        children: [
          Expanded(child: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
          IconButton(
            tooltip: 'Show or hide fields',
            onPressed: _isSaving ? null : _openFormSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      // A set width, so the form does not shrink when fields are
      // hidden. On a phone it is as wide as the screen allows.
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canPickMember) ...[
                if (_isLoadingMembers)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    // Rebuilt when the member list changes, so the
                    // selection can never point at a missing member.
                    key: ValueKey(
                      _members.map((member) => member.id).join(','),
                    ),
                    initialValue: _selectedMemberId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Paid by',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final member in _members)
                        DropdownMenuItem<String>(
                          value: member.id,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (member.isAppUser) ...[
                                const SizedBox(width: 8),
                                const _AppUserChip(),
                              ],
                            ],
                          ),
                        ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _selectedMemberId = value),
                  ),
                const SizedBox(height: 16),
              ],

              // ─── What was bought ───
              if (!_isEditingBill)
                _costLine(
                  description: _descriptionController,
                  amount: _amountController,
                  label: 'Description',
                  hint: 'Bazar',
                  maxLines: 5,
                  // Named only when a share cost sits beside it.
                  title: _shareCosts.isEmpty ? null : 'Meal cost',
                ),
              for (final row in _shareCosts)
                Padding(
                  padding: EdgeInsets.only(top: _isEditingBill ? 0 : 12),
                  child: _costLine(
                    description: row.description,
                    amount: row.cost,
                    label: 'Description',
                    hint: 'Water bill',
                    title: _isEditingBill ? null : 'Share cost',
                    trailing: _isEditingBill
                        ? null
                        : IconButton(
                            tooltip: 'Remove this share cost',
                            visualDensity: VisualDensity.compact,
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _shareCosts.remove(row);
                                      _balancePayment();
                                    });
                                    row.dispose();
                                  },
                            icon: const Icon(Icons.close, size: 20),
                          ),
                  ),
                ),
              if (!_isEditing &&
                  _shareCosts.isEmpty &&
                  _shows(_FormField.shareCost))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () =>
                              setState(() => _shareCosts.add(_ShareCostRow())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add share cost'),
                  ),
                ),

              // ─── The total, then how it was paid ───
              if (_shows(_FormField.total)) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '৳${_plainNumber(_total)}',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
              if (_splitsPayment) ...[
                _paymentLine(
                  label: 'My pocket',
                  icon: Icons.account_balance_wallet_outlined,
                  controller: _pocketController,
                  onTyped: () => _pocketTyped = true,
                ),
                _paymentLine(
                  label: 'From meal fund',
                  icon: Icons.savings_outlined,
                  controller: _fundController,
                  onTyped: () => _fundTyped = true,
                ),
              ] else if (_shows(_FormField.pocket) || _shows(_FormField.fund))
                // One source only: nothing to type, just a reminder.
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        _shows(_FormField.fund)
                            ? Icons.savings_outlined
                            : Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: const Color(0xFF647069),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _shows(_FormField.fund)
                            ? 'Paid from the meal fund'
                            : 'Paid from my pocket',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (_shows(_FormField.date)) ...[
                const SizedBox(height: 8),
                // Just the date: tapping it opens the calendar.
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: _isSaving ? null : _selectDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: Color(0xFF176B4D),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving || (canPickMember && _isLoadingMembers)
              ? null
              : _saveExpense,
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

/// Switches for the optional parts of the expense form.
class _FormSettingsDialog extends StatefulWidget {
  const _FormSettingsDialog({required this.hidden});

  final Set<_FormField> hidden;

  @override
  State<_FormSettingsDialog> createState() => _FormSettingsDialogState();
}

class _FormSettingsDialogState extends State<_FormSettingsDialog> {
  late final Set<_FormField> _hidden = widget.hidden;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Show in This Form'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in _FormField.values)
              SwitchListTile(
                value: !_hidden.contains(field),
                title: Text(
                  field.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(field.hint),
                onChanged: (isShown) {
                  setState(() {
                    if (isShown) {
                      _hidden.remove(field);
                    } else {
                      _hidden.add(field);
                    }
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_hidden),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Calculator dialog — a safe evaluator and keypad. "OK" just closes
// it; "Use It" puts the result into an amount
// ─────────────────────────────────────────────────────────────
class _CalculatorDialog extends StatefulWidget {
  const _CalculatorDialog({this.initialValue});

  final String? initialValue;

  /// Safely evaluates an expression supporting + - * / ( ) × ÷.
  static double? evaluate(String input) {
    final expr = input.trim();
    if (expr.isEmpty) return null;

    final plain = double.tryParse(expr);
    if (plain != null) return plain;

    try {
      final parser = _ExpressionParser(expr);
      final value = parser.parse();
      if (value.isNaN || value.isInfinite) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  @override
  State<_CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<_CalculatorDialog> {
  late final TextEditingController _controller;
  double? _preview;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _preview = _CalculatorDialog.evaluate(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {
      _preview = _CalculatorDialog.evaluate(_controller.text);
    });
  }

  void _append(String text) {
    final current = _controller.text;
    _controller.value = TextEditingValue(
      text: current + text,
      selection: TextSelection.collapsed(offset: current.length + text.length),
    );
    _onChanged(_controller.text);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final newText = text.substring(0, text.length - 1);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    _onChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Calculator'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Expression',
                hintText: 'Example: 10+45+5-60+1200',
                border: OutlineInputBorder(),
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  const Text('Result: '),
                  Expanded(
                    child: Text(
                      _preview == null
                          ? '—'
                          : '৳${_preview!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CalcKeypad(
              onKey: _append,
              onClear: _clear,
              onBackspace: _backspace,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
        FilledButton(
          onPressed: _preview == null
              ? null
              : () => Navigator.of(context).pop(_preview),
          child: const Text('Use It'),
        ),
      ],
    );
  }
}

class _CalcKeypad extends StatelessWidget {
  const _CalcKeypad({
    required this.onKey,
    required this.onClear,
    required this.onBackspace,
  });

  final void Function(String) onKey;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      [
        _Key('7', onTap: () => onKey('7')),
        _Key('8', onTap: () => onKey('8')),
        _Key('9', onTap: () => onKey('9')),
        _Key('÷', onTap: () => onKey('÷')),
      ],
      [
        _Key('4', onTap: () => onKey('4')),
        _Key('5', onTap: () => onKey('5')),
        _Key('6', onTap: () => onKey('6')),
        _Key('×', onTap: () => onKey('×')),
      ],
      [
        _Key('1', onTap: () => onKey('1')),
        _Key('2', onTap: () => onKey('2')),
        _Key('3', onTap: () => onKey('3')),
        _Key('−', onTap: () => onKey('-')),
      ],
      [
        _Key('0', onTap: () => onKey('0')),
        _Key('.', onTap: () => onKey('.')),
        _Key('+', onTap: () => onKey('+')),
        _Key('C', onTap: onClear, highlight: true),
      ],
      [
        _Key('(', onTap: () => onKey('(')),
        _Key(')', onTap: () => onKey(')')),
        _Key('⌫', onTap: onBackspace, highlight: true),
        _Key('', onTap: () {}, disabled: true),
      ],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: key,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(
    this.label, {
    required this.onTap,
    this.highlight = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: highlight ? const Color(0xFF2E7D32) : null,
          side: highlight ? const BorderSide(color: Color(0xFF2E7D32)) : null,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tiny expression parser (used only inside the calculator)
// ─────────────────────────────────────────────────────────────
class _ExpressionParser {
  _ExpressionParser(this.input);

  final String input;
  int _pos = 0;

  double parse() {
    final value = _parseExpression();
    _skipWhitespace();
    if (_pos < input.length) {
      throw FormatException('Unexpected character at $_pos');
    }
    return value;
  }

  double _parseExpression() {
    double value = _parseTerm();
    while (true) {
      _skipWhitespace();
      if (_peek('+')) {
        _next();
        value += _parseTerm();
      } else if (_peek('-')) {
        _next();
        value -= _parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  double _parseTerm() {
    double value = _parseFactor();
    while (true) {
      _skipWhitespace();
      if (_peek('*') || _peek('×')) {
        _next();
        value *= _parseFactor();
      } else if (_peek('/') || _peek('÷')) {
        _next();
        value /= _parseFactor();
      } else {
        break;
      }
    }
    return value;
  }

  double _parseFactor() {
    _skipWhitespace();
    if (_peek('+')) {
      _next();
      return _parseFactor();
    }
    if (_peek('-')) {
      _next();
      return -_parseFactor();
    }
    if (_peek('(')) {
      _next();
      final value = _parseExpression();
      _skipWhitespace();
      if (!_peek(')')) {
        throw FormatException('Missing )');
      }
      _next();
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipWhitespace();
    final start = _pos;
    while (_pos < input.length) {
      final c = input[_pos];
      if ((c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) || c == '.') {
        _pos++;
      } else {
        break;
      }
    }
    if (_pos == start) {
      throw FormatException('Expected number at $start');
    }
    return double.parse(input.substring(start, _pos));
  }

  bool _peek(String c) => _pos < input.length && input[_pos] == c;

  void _next() => _pos++;

  void _skipWhitespace() {
    while (_pos < input.length && input[_pos].trim().isEmpty) {
      _pos++;
    }
  }
}

class _AppUserChip extends StatelessWidget {
  const _AppUserChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'App User',
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
