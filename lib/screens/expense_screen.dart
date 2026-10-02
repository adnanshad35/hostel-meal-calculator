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
        expense: expense,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Expenses'),
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
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Color(0xFF2E7D32),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No expenses added yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap Add Expense to record the first expense.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final total = expenses.fold<double>(
  0,
  (currentTotal, expense) {
    final amount = expense.data()['amount'];
    return currentTotal + (amount is num ? amount.toDouble() : 0);
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
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  static String _formatAmount(dynamic amount) {
    if (amount is num) {
      return amount.toDouble().toStringAsFixed(2);
    }

    return '0.00';
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.groupId,
    this.expense,
  });

  final String groupId;
  final DocumentSnapshot<Map<String, dynamic>>? expense;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late DateTime _selectedDate;
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final data = widget.expense?.data();
    final amount = data?['amount'];

    _nameController = TextEditingController(
      text: data?['name'] as String? ?? '',
    );

    _amountController = TextEditingController(
      text: amount is num ? amount.toString() : '',
    );

    _selectedDate =
        (data?['date'] as Timestamp?)?.toDate() ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser!;
    final amount = double.parse(_amountController.text.trim());

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
          'updatedBy': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final paidByName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email ?? 'Member';

        await expenses.add({
          'name': _nameController.text.trim(),
          'amount': amount,
          'date': Timestamp.fromDate(_selectedDate),
          'paidById': user.uid,
          'paidByName': paidByName,
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

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '৳ ',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(formattedDate),
                trailing: TextButton(
                  onPressed: _selectDate,
                  child: const Text('Change'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveExpense,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}