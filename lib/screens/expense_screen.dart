import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/fund_service.dart';
import '../services/group_member_service.dart';
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

/// Where the money for an expense came from, and what it was for.
/// One expense can use more than one.
enum _Source {
  fund(
    'Meal fund',
    'Money from the hostel fund, spent on meals',
    Icons.savings_outlined,
  ),
  pocket(
    'My pocket',
    'The member\'s own money, spent on meals',
    Icons.account_balance_wallet_outlined,
  ),
  share(
    'Share cost',
    'A shared bill such as water, paid with own money',
    Icons.receipt_long_outlined,
  );

  const _Source(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;
}

/// The usual things a hostel spends on. "Other" lets the member type
/// a name instead.
const _sectors = [
  'Bazar',
  'Rice',
  'Fish & Meat',
  'Vegetables',
  'Grocery',
  'Gas',
];

const _otherSector = 'Other';

String _plainNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
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
  final _otherNameController = TextEditingController();
  final _amountControllers = {
    for (final source in _Source.values) source: TextEditingController(),
  };
  final _noteControllers = {
    for (final source in _Source.values) source: TextEditingController(),
  };

  /// The sources that can be chosen. A saved expense keeps its kind:
  /// a meal expense cannot be turned into a shared bill, or back.
  late final List<_Source> _available;

  /// Checked sources, each with its own amount field.
  final _checked = <_Source>{};

  /// Sources whose description box is open.
  final _notesOpen = <_Source>{};

  String _sector = _sectors.first;
  late DateTime _selectedDate;

  List<GroupMember> _members = [];
  StreamSubscription<List<GroupMember>>? _membersSubscription;
  String? _selectedMemberId;

  bool _isLoadingMembers = false;
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

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

    if (data == null) {
      _available = _Source.values;
      _checked.add(_Source.pocket);
    } else {
      _loadSaved(data);
    }

    if (widget.isAdmin && !_isEditing) {
      _watchMembers();
    }
  }

  void _loadSaved(Map<String, dynamic> data) {
    final saved = FundService.expenseRecord(data);
    final name = (data['name'] as String? ?? '').trim();

    if (_sectors.contains(name)) {
      _sector = name;
    } else {
      _sector = _otherSector;
      _otherNameController.text = name;
    }

    void fill(_Source source, double amount, Object? note) {
      if (amount <= 0) return;

      _checked.add(source);
      _amountControllers[source]!.text = _plainNumber(amount);

      if (note is String && note.trim().isNotEmpty) {
        _noteControllers[source]!.text = note;
        _notesOpen.add(source);
      }
    }

    if (saved.isBill) {
      _available = const [_Source.share];
      fill(_Source.share, saved.amount, data['pocketNote']);
    } else {
      _available = const [_Source.fund, _Source.pocket];
      fill(_Source.fund, saved.fundPart, data['fundNote']);
      fill(_Source.pocket, saved.pocketPart, data['pocketNote']);
    }
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _otherNameController.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
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

  /// Lets the member tick where the money came from.
  Future<void> _chooseSources() async {
    final chosen = await showDialog<Set<_Source>>(
      context: context,
      builder: (_) =>
          _SourceChecklist(available: _available, checked: {..._checked}),
    );

    if (chosen == null || !mounted) return;

    setState(() {
      _checked
        ..clear()
        ..addAll(chosen);
    });
  }

  /// Opens the calculator. "Use It" puts the result into [opener]'s
  /// amount, or asks which one when several sources are ticked.
  Future<void> _openCalculator(_Source opener) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _CalculatorDialog(
        initialValue: _amountControllers[opener]!.text.trim(),
      ),
    );

    if (result == null || !mounted) return;

    var target = opener;

    if (_checked.length > 1) {
      final picked = await showDialog<_Source>(
        context: context,
        builder: (dialogContext) {
          return SimpleDialog(
            title: Text('Use ৳${_plainNumber(result)} for'),
            children: [
              for (final source in _Source.values)
                if (_checked.contains(source))
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(dialogContext).pop(source),
                    child: Row(
                      children: [
                        Icon(source.icon, size: 20),
                        const SizedBox(width: 12),
                        Text(source.label),
                      ],
                    ),
                  ),
            ],
          );
        },
      );

      if (picked == null || !mounted) return;
      target = picked;
    }

    setState(() {
      _amountControllers[target]!.text = _plainNumber(result);
    });
  }

  double _amountOf(_Source source) {
    if (!_checked.contains(source)) return 0;
    return double.tryParse(_amountControllers[source]!.text.trim()) ?? 0;
  }

  String _noteOf(_Source source) {
    if (!_checked.contains(source)) return '';
    return _noteControllers[source]!.text.trim();
  }

  double get _total {
    return _Source.values.fold<double>(
      0,
      (total, source) => total + _amountOf(source),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveExpense() async {
    final name = _sector == _otherSector
        ? _otherNameController.text.trim()
        : _sector;

    if (name.isEmpty) {
      _showMessage('Please type the expense name.');
      return;
    }

    if (_checked.isEmpty) {
      _showMessage('Tick where the money came from.');
      return;
    }

    for (final source in _Source.values) {
      if (_checked.contains(source) && _amountOf(source) <= 0) {
        _showMessage('Please enter the amount for "${source.label}".');
        return;
      }
    }

    final fund = _amountOf(_Source.fund);
    final pocket = _amountOf(_Source.pocket);
    final share = _amountOf(_Source.share);
    final shareNote = _noteOf(_Source.share);

    // A shared bill is listed with the fixed costs under what it was
    // for, so its description names it when there is one.
    final billName = shareNote.isEmpty
        ? name
        : shareNote.split('\n').first.trim();

    final selectedMember = _members
        .where((member) => member.id == _selectedMemberId)
        .firstOrNull;

    final paidById = widget.isAdmin && !_isEditing
        ? _selectedMemberId ?? _currentUser.uid
        : _currentUser.uid;

    final paidByName = widget.isAdmin && !_isEditing
        ? selectedMember?.name ?? 'Member'
        : _ownName;

    final mealFields = <String, dynamic>{
      'name': name,
      'amount': fund + pocket,
      'fromFund': fund,
      'category': 'meal',
      'fundNote': _noteOf(_Source.fund),
      'pocketNote': _noteOf(_Source.pocket),
    };

    final billFields = <String, dynamic>{
      'name': billName.length > 60 ? billName.substring(0, 60) : billName,
      'amount': share,
      'fromFund': 0,
      'category': 'bill',
      'fundNote': '',
      'pocketNote': shareNote,
    };

    setState(() => _isSaving = true);

    try {
      final expenses = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses');

      if (_isEditing) {
        await expenses.doc(widget.expense!.id).update({
          ...(share > 0 ? billFields : mealFields),
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

        // Meals and a shared bill are counted differently, so they
        // are saved as two records, together.
        final batch = FirebaseFirestore.instance.batch();

        if (fund + pocket > 0) {
          batch.set(expenses.doc(), {...mealFields, ...common});
        }
        if (share > 0) {
          batch.set(expenses.doc(), {...billFields, ...common});
        }

        await batch.commit();

        // Not awaited: the expense is saved either way.
        unawaited(
          NotificationService.notifyGroup(
            groupId: widget.groupId,
            title: 'New expense',
            message:
                '$name · ৳${_plainNumber(fund + pocket + share)}, '
                'paid by $paidByName',
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

  /// The amount field of one ticked source, with its calculator and
  /// description buttons.
  Widget _sourceField(_Source source) {
    final isNoteOpen = _notesOpen.contains(source);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          TextField(
            controller: _amountControllers[source],
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: source.label,
              hintText: 'Amount',
              prefixText: '৳ ',
              prefixIcon: Icon(source.icon),
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Calculator',
                    onPressed: _isSaving ? null : () => _openCalculator(source),
                    icon: const Icon(Icons.calculate_outlined),
                  ),
                  IconButton(
                    tooltip: isNoteOpen
                        ? 'Remove description'
                        : 'Add description',
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              if (isNoteOpen) {
                                _notesOpen.remove(source);
                                _noteControllers[source]!.clear();
                              } else {
                                _notesOpen.add(source);
                              }
                            });
                          },
                    icon: Icon(isNoteOpen ? Icons.remove : Icons.add),
                  ),
                ],
              ),
            ),
          ),
          if (isNoteOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _noteControllers[source],
              enabled: !_isSaving,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: source == _Source.share
                    ? 'Water bill'
                    : 'Onion 2kg 80tk\nOil 4lt 1000tk',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final formattedDate = '$day/$month/${_selectedDate.year}';

    final savedPayer = widget.expense?.data()?['paidByName'] as String?;
    final canPickMember = widget.isAdmin && !_isEditing;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Person ───
            if (canPickMember && _isLoadingMembers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (canPickMember)
              DropdownButtonFormField<String>(
                // Rebuilt when the member list changes, so the
                // selection can never point at a missing member.
                key: ValueKey(_members.map((member) => member.id).join(',')),
                initialValue: _selectedMemberId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Person',
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
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Person',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _isEditing ? savedPayer ?? 'Member' : _ownName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 16),

            // ─── Expense name ───
            DropdownButtonFormField<String>(
              initialValue: _sector,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Expense',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final sector in [..._sectors, _otherSector])
                  DropdownMenuItem<String>(value: sector, child: Text(sector)),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _sector = value ?? _sector),
            ),
            if (_sector == _otherSector) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherNameController,
                enabled: !_isSaving,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Expense name',
                  hintText: 'Example: Cleaning items',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ─── Where the money came from ───
            InkWell(
              onTap: _isSaving || _available.length == 1
                  ? null
                  : _chooseSources,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Paid from',
                  prefixIcon: const Icon(Icons.checklist_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: _available.length == 1
                      ? null
                      : const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _checked.isEmpty
                      ? 'Tap to choose'
                      : [
                          for (final source in _Source.values)
                            if (_checked.contains(source)) source.label,
                        ].join(', '),
                ),
              ),
            ),
            for (final source in _Source.values)
              if (_checked.contains(source)) _sourceField(source),
            if (_checked.length > 1) ...[
              const SizedBox(height: 10),
              Text(
                'Total  ৳${_plainNumber(_total)}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(formattedDate),
              trailing: TextButton(
                onPressed: _isSaving ? null : _selectDate,
                child: const Text('Change'),
              ),
            ),
          ],
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

/// The "Paid from" checklist: tick one or more sources.
class _SourceChecklist extends StatefulWidget {
  const _SourceChecklist({required this.available, required this.checked});

  final List<_Source> available;
  final Set<_Source> checked;

  @override
  State<_SourceChecklist> createState() => _SourceChecklistState();
}

class _SourceChecklistState extends State<_SourceChecklist> {
  late final Set<_Source> _checked = widget.checked;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paid from'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in widget.available)
            CheckboxListTile(
              value: _checked.contains(source),
              title: Text(
                source.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(source.hint),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) {
                    _checked.add(source);
                  } else {
                    _checked.remove(source);
                  }
                });
              },
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_checked),
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
