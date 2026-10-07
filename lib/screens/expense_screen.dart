import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        builder: (_) => TotalExpensesScreen(
          groupId: groupId,
          isAdmin: isAdmin,
        ),
      ),
    );
  }

  void _openMyExpenses(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyExpensesScreen(
          groupId: groupId,
          currentUserId: uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Update'),
      ),
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
            return const Center(
              child: Text('Unable to load expenses.'),
            );
          }

          final expenses = snapshot.data?.docs ?? [];

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
                      subtitle: 'All members',
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
                      subtitle: 'Paid by me',
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
                          'No expenses added yet',
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
                      '${expenses.length == 1 ? '' : 's'} recorded',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Tap Total Expense to view the full list.',
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
    await showDialog<void>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        groupId: groupId,
        isAdmin: isAdmin,
        expense: expense,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Expenses'),
      ),
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
            return const Center(
              child: Text('Unable to load expenses.'),
            );
          }

          final expenses = snapshot.data?.docs ?? [];

          if (expenses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No expenses added yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final total = expenses.fold<double>(
            0,
            (currentTotal, expense) {
              final amount = expense.data()['amount'];
              return currentTotal +
                  (amount is num ? amount.toDouble() : 0);
            },
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Total shared expenses'),
                      const SizedBox(height: 6),
                      Text(
                        '৳${total.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
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

                final canEdit =
                    isAdmin || paidById == currentUser.uid;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_outlined),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${_formatDate(date)}\nPaid by $paidByName',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '৳${_formatAmount(amount)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Edit expense',
                            onPressed: () {
                              _openExpenseForm(
                                context,
                                expense: expense,
                              );
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
      appBar: AppBar(
        title: const Text('My Expenses'),
      ),
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

          final docs = (snapshot.data?.docs ?? [])
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
            final amount = d.data()['amount'];
            if (amount is num) total += amount.toDouble();
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
                      const Text('My total expenses'),
                      const SizedBox(height: 6),
                      Text(
                        '৳${total.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(_formatDate(date)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '৳${_formatAmount(amount)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Edit expense',
                          onPressed: () {
                            _openExpenseForm(
                              context,
                              expense: expense,
                            );
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
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
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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

enum _AmountMode { fixed, calculation }

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

  late DateTime _selectedDate;

  List<_ExpenseMember> _members = [];
  String? _selectedMemberId;

  bool _isLoadingMembers = false;
  bool _isSaving = false;

  _AmountMode _amountMode = _AmountMode.fixed;

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
          ? (amount % 1 == 0
              ? amount.toInt().toString()
              : amount.toString())
          : '',
    );

    _selectedDate =
        (data?['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    _selectedMemberId =
        data?['paidById'] as String? ?? _currentUser.uid;

    if (widget.isAdmin && !_isEditing) {
      _loadMembers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('groupId', isEqualTo: widget.groupId)
          .get();

      final members = snapshot.docs.map((document) {
        final data = document.data();
        return _ExpenseMember(
          id: document.id,
          name: _readMemberName(data),
        );
      }).toList();

      if (!members.any((member) => member.id == _currentUser.uid)) {
        members.add(
          _ExpenseMember(
            id: _currentUser.uid,
            name: _currentUser.displayName?.trim().isNotEmpty == true
                ? _currentUser.displayName!.trim()
                : _currentUser.email ?? 'Administrator',
          ),
        );
      }

      members.sort(
        (first, second) => first.name.compareTo(second.name),
      );

      if (!mounted) return;

      setState(() {
        _members = members;
        if (!_members.any((m) => m.id == _selectedMemberId)) {
          _selectedMemberId = _currentUser.uid;
        }
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to load members.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  String _readMemberName(Map<String, dynamic> data) {
    final possibleNames = [
      data['name'],
      data['displayName'],
      data['fullName'],
    ];

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
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
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _CalculatorDialog(
        initialValue: _amountController.text.trim(),
      ),
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

    if (widget.isAdmin &&
        !_isEditing &&
        _selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member.')),
      );
      return;
    }

    final parsedAmount = double.tryParse(
      _amountController.text.trim(),
    );

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
        : _currentUser.displayName?.trim().isNotEmpty == true
            ? _currentUser.displayName!.trim()
            : _currentUser.email ?? 'Member';

    setState(() => _isSaving = true);

    try {
      final expenses = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses');

      if (_isEditing) {
        await expenses.doc(widget.expense!.id).update({
          'name': _nameController.text.trim(),
          'amount': amount,
          'date': Timestamp.fromDate(_selectedDate),
          'updatedBy': _currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await expenses.add({
          'name': _nameController.text.trim(),
          'amount': amount,
          'date': Timestamp.fromDate(_selectedDate),
          'paidById': paidById,
          'paidByName': paidByName,
          'enteredBy': _currentUser.uid,
          'enteredByName':
              _currentUser.displayName?.trim().isNotEmpty == true
                  ? _currentUser.displayName!.trim()
                  : _currentUser.email ?? 'Member',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to save expense.'),
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

    final existingPaidByName =
        widget.expense?.data()?['paidByName'] as String?;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
      content: Form(
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
                    initialValue: _selectedMemberId,
                    decoration: const InputDecoration(
                      labelText: 'Paid by',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: _members.map((member) {
                      return DropdownMenuItem<String>(
                        value: member.id,
                        child: Text(member.name),
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
                const SizedBox(height: 16),
              ],
              if (_isEditing && existingPaidByName != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Paid by'),
                  subtitle: Text(existingPaidByName),
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Expense name',
                  hintText: 'Example: Rice or electricity bill',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the expense name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Amount field ───
              TextFormField(
                controller: _amountController,
                readOnly: _amountMode == _AmountMode.calculation,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: _amountMode == _AmountMode.fixed
                      ? 'Example: 350'
                      : null,
                  prefixText: '৳ ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixIcon: _amountMode == _AmountMode.calculation
                      ? IconButton(
                          tooltip: 'Open calculator',
                          onPressed: _isSaving ? null : _openCalculator,
                          icon: const Icon(Icons.calculate_outlined),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid amount.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ─── Mode selector ───
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_AmountMode>(
                  segments: const [
                    ButtonSegment<_AmountMode>(
                      value: _AmountMode.fixed,
                      icon: Icon(Icons.edit_outlined, size: 18),
                      label: Text('Fixed Value'),
                    ),
                    ButtonSegment<_AmountMode>(
                      value: _AmountMode.calculation,
                      icon: Icon(Icons.calculate_outlined, size: 18),
                      label: Text('Calculation'),
                    ),
                  ],
                  selected: {_amountMode},
                  onSelectionChanged: _isSaving
                      ? null
                      : (selection) {
                          final mode = selection.first;
                          setState(() => _amountMode = mode);
                          if (mode == _AmountMode.calculation) {
                            // Open calculator immediately.
                            _openCalculator();
                          }
                        },
                ),
              ),

              const SizedBox(height: 16),
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
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ||
                  (widget.isAdmin &&
                      !_isEditing &&
                      _isLoadingMembers)
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
      selection:
          TextSelection.collapsed(offset: current.length + text.length),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
          foregroundColor:
              highlight ? const Color(0xFF2E7D32) : null,
          side: highlight
              ? const BorderSide(color: Color(0xFF2E7D32))
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
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

class _ExpenseMember {
  const _ExpenseMember({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}