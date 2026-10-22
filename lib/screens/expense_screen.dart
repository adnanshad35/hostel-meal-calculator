import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/group_member_service.dart';
import '../services/month_records.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/month_calendar.dart';

/// Opens the Add Expense form, unless the hostel is read-only.
Future<void> showExpenseForm(
  BuildContext context, {
  required String groupId,
  required bool isAdmin,
}) async {
  if (!await ensureHostelEditable(context, groupId)) return;
  if (!context.mounted) return;
  if (!await ensureMemberMayAdd(context, groupId, meals: false)) return;
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
    if (!await ensureMemberMayAdd(context, groupId, meals: false)) return;
    if (!context.mounted) return;
    if (expense != null && !await ensureMemberMayEdit(context, groupId)) {
      return;
    }
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
        // This month only: the page shows nothing older.
        stream: MonthRecords.expenses(groupId, DateTime.now()).snapshots(),
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

            if (data['paidById'] == currentUser.uid) {
              myExpense += value;
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
                      color: AppTheme.primary,
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
                      color: AppTheme.primary,
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
                          color: AppTheme.primary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No Expenses This Month',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  color: AppTheme.surfaceSoft,
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppTheme.primary,
                    ),
                    title: Text(
                      '${expenses.length} '
                      '${expenses.length == 1 ? 'Expense' : 'Expenses'} '
                      'This Month',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
// Total expenses: the whole hostel's month, as a calendar
// ─────────────────────────────────────────────────────────────
class TotalExpensesScreen extends StatelessWidget {
  const TotalExpensesScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.embedded = false,
  });

  final String groupId;
  final bool isAdmin;

  /// True when shown as a tab of another page, which has the title.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return _ExpenseCalendar(
      groupId: groupId,
      isAdmin: isAdmin,
      embedded: embedded,
      onlyMine: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// My expenses: what the signed-in member paid this month
// ─────────────────────────────────────────────────────────────
class MyExpensesScreen extends StatelessWidget {
  const MyExpensesScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
    this.embedded = false,
  });

  final String groupId;
  final String currentUserId;

  /// True when shown as a tab of another page, which has the title.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return _ExpenseCalendar(
      groupId: groupId,
      isAdmin: false,
      embedded: embedded,
      onlyMine: true,
    );
  }
}

/// This month's expenses on a calendar. Tapping a day lists what was
/// spent that day; whoever may change an expense can tap it to edit.
class _ExpenseCalendar extends StatefulWidget {
  const _ExpenseCalendar({
    required this.groupId,
    required this.isAdmin,
    required this.embedded,
    required this.onlyMine,
  });

  final String groupId;
  final bool isAdmin;
  final bool embedded;

  /// True for the member's own expenses, false for the whole hostel's.
  final bool onlyMine;

  @override
  State<_ExpenseCalendar> createState() => _ExpenseCalendarState();
}

class _ExpenseCalendarState extends State<_ExpenseCalendar> {
  /// The month on screen: this month, or an earlier one.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  late Stream<QuerySnapshot<Map<String, dynamic>>> _expenses;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    // One month at a time.
    _expenses = MonthRecords.expenses(widget.groupId, _month).snapshots();
  }

  void _showMonth(DateTime month) {
    setState(() {
      _month = month;
      _expenses = MonthRecords.expenses(widget.groupId, month).snapshots();
    });
  }

  Future<void> _openExpenseForm({
    DocumentSnapshot<Map<String, dynamic>>? expense,
  }) async {
    if (!await ensureHostelEditable(context, widget.groupId)) return;
    if (!mounted) return;
    if (!await ensureMemberMayAdd(context, widget.groupId, meals: false)) {
      return;
    }
    if (!mounted) return;
    if (expense != null &&
        !await ensureMemberMayEdit(context, widget.groupId)) {
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        groupId: widget.groupId,
        isAdmin: widget.isAdmin,
        expense: expense,
      ),
    );
  }

  Future<void> _deleteExpense(
    DocumentSnapshot<Map<String, dynamic>> expense,
    String name,
  ) async {
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
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.onlyMine ? 'My Expenses' : 'Total Expenses'),
            ),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton.extended(
              onPressed: _openExpenseForm,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _expenses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load expenses.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildCalendar(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildCalendar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byDay = <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    double total = 0;

    for (final expense in docs) {
      final data = expense.data();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (widget.onlyMine && data['paidById'] != _uid) continue;

      byDay.putIfAbsent(date.day, () => []).add(expense);
      total += (data['amount'] as num?)?.toDouble() ?? 0;
    }

    // The latest expense of a day first.
    DateTime addedAt(QueryDocumentSnapshot<Map<String, dynamic>> expense) {
      final data = expense.data();
      final time = data['createdAt'] ?? data['date'];
      return time is Timestamp ? time.toDate() : DateTime(0);
    }

    for (final expenses in byDay.values) {
      expenses.sort((a, b) => addedAt(b).compareTo(addedAt(a)));
    }

    final previous = shiftMonth(_month, -1);
    final next = shiftMonth(_month, 1);

    return MonthCalendarView(
      // A new month starts on its own selected day.
      key: ValueKey(_month),
      month: _month,
      onPreviousMonth: previous == null ? null : () => _showMonth(previous),
      onNextMonth: next == null ? null : () => _showMonth(next),
      label: widget.onlyMine ? 'My Expense' : 'Total Expense',
      total: '৳${_plainAmount(total)}',
      markedDays: byDay.keys.toSet(),
      newestFirst: true,
      // The hostel's figure opens what each member paid.
      onTotalTap: widget.onlyMine ? null : () => _showMemberTotals(docs),
      belowCalendar: const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(
          'Recent Expenses',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      linesOf: (day) {
        return [for (final expense in byDay[day] ?? const []) _line(expense)];
      },
    );
  }

  /// What each member paid this month, the most first. Members who
  /// paid nothing are listed at the end with ৳0.
  void _showMemberTotals(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final paid = <String, double>{};
    final names = <String, String>{};
    double total = 0;

    for (final expense in docs) {
      final data = expense.data();
      final id = data['paidById'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;

      paid[id] = (paid[id] ?? 0) + amount;
      names[id] = data['paidByName'] as String? ?? 'Member';
      total += amount;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StreamBuilder<List<GroupMember>>(
          stream: GroupMemberService.watch(widget.groupId),
          builder: (context, snapshot) {
            final everyone = {
              ...names,
              for (final member in snapshot.data ?? const <GroupMember>[])
                member.id: member.name,
            };
            final ids = everyone.keys.toList()
              ..sort((a, b) {
                final byAmount = (paid[b] ?? 0).compareTo(paid[a] ?? 0);
                return byAmount != 0
                    ? byAmount
                    : everyone[a]!.compareTo(everyone[b]!);
              });

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text(
                        'Member Totals',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final id in ids)
                            ListTile(
                              title: Text(
                                everyone[id]!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Text(
                                '৳${_plainAmount(paid[id] ?? 0)}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                      title: const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: Text(
                        '৳${_plainAmount(total)}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  CalendarLine _line(QueryDocumentSnapshot<Map<String, dynamic>> expense) {
    final data = expense.data();
    final name = data['name'] as String? ?? 'Expense';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    // Earlier months are read-only.
    final isThisMonth = isCurrentMonth(_month);
    final canEdit = isThisMonth && (widget.isAdmin || data['paidById'] == _uid);

    return CalendarLine(
      title: name,
      // Whose it was, when the list is the whole hostel's; in the
      // member's own list, what they wrote about it.
      note: widget.onlyMine
          ? _firstLine(data['description'])
          : data['paidByName'] as String?,
      trailing: '৳${_plainAmount(amount)}',
      onTap: canEdit ? () => _openExpenseForm(expense: expense) : null,
      action: widget.isAdmin && isThisMonth
          ? PopupMenuButton<String>(
              tooltip: 'Expense options',
              padding: EdgeInsets.zero,
              onSelected: (action) {
                if (action == 'edit') {
                  _openExpenseForm(expense: expense);
                } else {
                  _deleteExpense(expense, name);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// The first line of a description, or null when there is none.
String? _firstLine(Object? description) {
  if (description is! String) return null;

  final line = description.trim().split('\n').first.trim();
  return line.isEmpty ? null : line;
}

String _plainAmount(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
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
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  /// True once the + beside the name has opened the description box.
  bool _showDescription = false;

  late DateTime _selectedDate;

  List<GroupMember> _members = [];
  StreamSubscription<List<GroupMember>>? _membersSubscription;
  String? _selectedMemberId;

  bool _isLoadingMembers = false;
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  User get _currentUser => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();

    final data = widget.expense?.data();
    final amount = data?['amount'];

    _nameController = TextEditingController(
      text: data?['name'] as String? ?? '',
    );

    _amountController = TextEditingController(
      text: amount is num
          ? (amount % 1 == 0 ? amount.toInt().toString() : amount.toString())
          : '',
    );

    final description = (data?['description'] as String? ?? '').trim();
    _descriptionController = TextEditingController(text: description);
    _showDescription = description.isNotEmpty;

    _selectedDate = (data?['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    _selectedMemberId = data?['paidById'] as String? ?? _currentUser.uid;

    if (widget.isAdmin && !_isEditing) {
      _watchMembers();
    }
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
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
              name: _currentUser.displayName?.trim().isNotEmpty == true
                  ? _currentUser.displayName!.trim()
                  : _currentUser.email ?? 'Administrator',
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
          SnackBar(
            content: Text(
              error is FirebaseException
                  ? error.message ?? 'Unable to load members.'
                  : 'Unable to load members.',
            ),
          ),
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

  /// Opens the calculator dialog. On "Use Result", writes the
  /// computed plain number into the amount field.
  Future<void> _openCalculator() async {
    // The calculator has its own keypad, so the phone's keyboard is
    // put away first.
    FocusScope.of(context).unfocus();

    final result = await showDialog<double>(
      context: context,
      builder: (_) =>
          _CalculatorDialog(initialValue: _amountController.text.trim()),
    );

    if (!mounted) return;

    if (result != null) {
      _amountController.text = result % 1 == 0
          ? result.toInt().toString()
          : result.toStringAsFixed(2);
      setState(() {});
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isAdmin && !_isEditing && _selectedMemberId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a member.')));
      return;
    }

    final parsedAmount = double.tryParse(_amountController.text.trim());

    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final amount = parsedAmount;

    final selectedMember = _members
        .where((member) => member.id == _selectedMemberId)
        .firstOrNull;

    final paidById = widget.isAdmin && !_isEditing
        ? _selectedMemberId!
        : _currentUser.uid;

    final paidByName = widget.isAdmin && !_isEditing
        ? selectedMember?.name ?? 'Member'
        : ProfileService.memberName ??
              (_currentUser.displayName?.trim().isNotEmpty == true
                  ? _currentUser.displayName!.trim()
                  : _currentUser.email ?? 'Member');

    setState(() => _isSaving = true);

    try {
      final expenses = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses');

      final description = _showDescription
          ? _descriptionController.text.trim()
          : '';
      final savedDescription =
          (widget.expense?.data()?['description'] as String? ?? '').trim();

      if (_isEditing) {
        await expenses.doc(widget.expense!.id).update({
          'name': _nameController.text.trim(),
          'amount': amount,
          'date': Timestamp.fromDate(_selectedDate),
          // Sent only when it changed.
          if (description != savedDescription) 'description': description,
          'updatedBy': _currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await expenses.add({
          'name': _nameController.text.trim(),
          'description': description,
          'amount': amount,
          'date': Timestamp.fromDate(_selectedDate),
          'paidById': paidById,
          'paidByName': paidByName,
          'enteredBy': _currentUser.uid,
          'enteredByName': _currentUser.displayName?.trim().isNotEmpty == true
              ? _currentUser.displayName!.trim()
              : _currentUser.email ?? 'Member',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final amountText = amount % 1 == 0
            ? amount.toInt().toString()
            : amount.toStringAsFixed(2);

        // Not awaited: the expense is saved either way.
        unawaited(
          NotificationService.notifyGroup(
            groupId: widget.groupId,
            title: 'New Expense',
            message:
                '${_nameController.text.trim()} · ৳$amountText, '
                'paid by $paidByName',
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save expense.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final formattedDate = '$day/$month/${_selectedDate.year}';

    final existingPaidByName = widget.expense?.data()?['paidByName'] as String?;

    return AlertDialog(
      // Wider than the default, with room around each part.
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isAdmin && !_isEditing) ...[
                  if (_isLoadingMembers)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
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
                        labelText: 'Paid By',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _members.map((member) {
                        return DropdownMenuItem<String>(
                          value: member.id,
                          // Green for a member who uses the app.
                          child: Text(
                            member.name,
                            overflow: TextOverflow.ellipsis,
                            style: member.isAppUser
                                ? const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _selectedMemberId = value);
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a member.';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 20),
                ],
                // Shown to an admin, who may be editing someone else's.
                if (widget.isAdmin &&
                    _isEditing &&
                    existingPaidByName != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Paid By'),
                    subtitle: Text(existingPaidByName),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Expense Name',
                    prefixIcon: const Icon(Icons.description_outlined),
                    // Opens a box for what was bought, or closes it.
                    suffixIcon: IconButton(
                      tooltip: _showDescription
                          ? 'Remove description'
                          : 'Add description',
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _showDescription = !_showDescription;
                              });
                            },
                      icon: Icon(_showDescription ? Icons.remove : Icons.add),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the expense name.';
                    }
                    return null;
                  },
                ),
                if (_showDescription) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 400,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      counterText: '',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Tapping the amount opens the keyboard; the calculator
                // icon opens the calculator instead.
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '৳ ',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixIcon: IconButton(
                      tooltip: 'Calculator',
                      onPressed: _isSaving ? null : _openCalculator,
                      icon: const Icon(Icons.calculate_outlined),
                    ),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid amount.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      // The date sits at the bottom left; tapping it opens the
      // calendar.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 24, 22),
      actions: [
        InkWell(
          onTap: _isSaving ? null : _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 3),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed:
                  _isSaving ||
                      (widget.isAdmin && !_isEditing && _isLoadingMembers)
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
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Calculator dialog — same safe evaluator, keypad, "Use Result"
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
              // No on-screen keyboard: the keypad below does the
              // typing. A physical keyboard still works.
              keyboardType: TextInputType.none,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Expression',
                hintText: 'Example: 10+45+5-60+1200',
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Result: '),
                  Expanded(
                    child: Text(
                      _preview == null
                          ? '—'
                          : '৳${_preview!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _preview == null
              ? null
              : () => Navigator.of(context).pop(_preview),
          child: const Text('Use Result'),
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
          foregroundColor: highlight ? AppTheme.primary : null,
          side: highlight ? const BorderSide(color: AppTheme.primary) : null,
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
