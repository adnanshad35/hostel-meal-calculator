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
                final name =
                    data['name'] as String? ?? 'Expense';
                final paidByName =
                    data['paidByName'] as String? ??
                        'Unknown member';
                final paidById =
                    data['paidById'] as String? ?? '';
                final amount = data['amount'];
                final date =
                    (data['date'] as Timestamp?)?.toDate();

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
                            icon: const Icon(
                              Icons.edit_outlined,
                            ),
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
    required this.isAdmin,
    this.expense,
  });

  final String groupId;
  final bool isAdmin;
  final DocumentSnapshot<Map<String, dynamic>>? expense;

  @override
  State<_ExpenseFormDialog> createState() =>
      _ExpenseFormDialogState();
}

class _ExpenseFormDialogState
    extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late DateTime _selectedDate;

  List<_ExpenseMember> _members = [];
  String? _selectedMemberId;

  bool _isLoadingMembers = false;
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  User get _currentUser =>
      FirebaseAuth.instance.currentUser!;

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
        (data?['date'] as Timestamp?)?.toDate() ??
            DateTime.now();

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

      if (!members.any(
        (member) => member.id == _currentUser.uid,
      )) {
        members.add(
          _ExpenseMember(
            id: _currentUser.uid,
            name: _currentUser.displayName
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? _currentUser.displayName!.trim()
                : _currentUser.email ?? 'Administrator',
          ),
        );
      }

      members.sort(
        (first, second) =>
            first.name.compareTo(second.name),
      );

      if (!mounted) return;

      setState(() {
        _members = members;

        if (!_members.any(
          (member) => member.id == _selectedMemberId,
        )) {
          _selectedMemberId = _currentUser.uid;
        }
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to load members.',
          ),
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

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isAdmin &&
        !_isEditing &&
        _selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a member.'),
        ),
      );
      return;
    }

    final amount =
        double.parse(_amountController.text.trim());

    final selectedMember = _members
        .where(
          (member) => member.id == _selectedMemberId,
        )
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
              _currentUser.displayName?.trim().isNotEmpty ==
                      true
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
          content: Text(
            error.message ?? 'Unable to save expense.',
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
    final day =
        _selectedDate.day.toString().padLeft(2, '0');
    final month =
        _selectedDate.month.toString().padLeft(2, '0');
    final formattedDate =
        '$day/$month/${_selectedDate.year}';

    final existingPaidByName =
        widget.expense?.data()?['paidByName'] as String?;

    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Expense' : 'Add Expense',
      ),
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
                      prefixIcon: Icon(
                        Icons.person_outline,
                      ),
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
                            setState(() {
                              _selectedMemberId = value;
                            });
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
              if (_isEditing &&
                  existingPaidByName != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_outline,
                  ),
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
                  hintText:
                      'Example: Rice or electricity bill',
                  prefixIcon: Icon(
                    Icons.description_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter the expense name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '৳ ',
                  prefixIcon:
                      Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount =
                      double.tryParse(value?.trim() ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_outlined,
                ),
                title: const Text('Date'),
                subtitle: Text(formattedDate),
                trailing: TextButton(
                  onPressed:
                      _isSaving ? null : _selectDate,
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

class _ExpenseMember {
  const _ExpenseMember({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}