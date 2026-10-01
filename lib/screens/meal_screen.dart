import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'meal_ledger_screen.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late DateTime _selectedDate;

  double _lunch = 0;
  double _dinner = 0;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasEntry = false;

  User get _user => FirebaseAuth.instance.currentUser!;

  CollectionReference<Map<String, dynamic>> get _mealCollection =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('meals');

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadEntry();
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _monthKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');

    return '$year-$month';
  }

  String _displayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _displayQuantity(double value) {
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  String get _entryId => '${_user.uid}_${_dateKey(_selectedDate)}';

  Future<void> _loadEntry() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _mealCollection.doc(_entryId).get();
      final data = snapshot.data();

      if (!mounted) return;

      setState(() {
        _hasEntry = snapshot.exists;
        _lunch = (data?['lunch'] as num?)?.toDouble() ?? 0;
        _dinner = (data?['dinner'] as num?)?.toDouble() ?? 0;
      });
    } on FirebaseException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load the meal entry.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month);
    final lastDate = DateTime(now.year, now.month + 1, 0);

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select a meal date',
    );

    if (selected == null || selected == _selectedDate) return;

    setState(() {
      _selectedDate = selected;
      _lunch = 0;
      _dinner = 0;
      _hasEntry = false;
    });

    await _loadEntry();
  }

  void _changeLunch(double amount) {
    setState(() {
      _lunch = (_lunch + amount).clamp(0, double.infinity);
    });
  }

  void _changeDinner(double amount) {
    setState(() {
      _dinner = (_dinner + amount).clamp(0, double.infinity);
    });
  }

  Future<bool> _confirmLargeQuantity() async {
    if (_lunch <= 5 && _dinner <= 5) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm large quantity'),
              content: Text(
                'You entered ${_displayQuantity(_lunch)} lunch and '
                '${_displayQuantity(_dinner)} dinner meals. '
                'Are these values correct?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Review'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _saveEntry() async {
    final confirmed = await _confirmLargeQuantity();

    if (!confirmed) return;

    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'groupId': widget.groupId,
        'userId': _user.uid,
        'userName': _user.displayName ?? 'Member',
        'dateKey': _dateKey(_selectedDate),
        'date': Timestamp.fromDate(_selectedDate),
        'lunch': _lunch,
        'dinner': _dinner,
        'total': _lunch + _dinner,
        'submitted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_hasEntry) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _mealCollection.doc(_entryId).set(
            data,
            SetOptions(merge: true),
          );

      if (!mounted) return;

      setState(() => _hasEntry = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meals saved for ${_displayDate(_selectedDate)}.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'You do not have permission to save this entry.'
                : 'Unable to save the meal entry.',
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
    final currentMonth = _monthKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
  title: const Text('My Meals'),
  actions: [
    IconButton(
      tooltip: 'Shared meal ledger',
      icon: const Icon(Icons.table_chart_outlined),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MealLedgerScreen(
              groupId: widget.groupId,
            ),
          ),
        );
      },
    ),
  ],
),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _mealCollection
              .where('userId', isEqualTo: _user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            double monthlyTotal = 0;

            if (snapshot.hasData) {
              for (final document in snapshot.data!.docs) {
                final data = document.data();
                final dateKey = data['dateKey'] as String? ?? '';

                if (dateKey.startsWith(currentMonth)) {
                  monthlyTotal +=
                      (data['total'] as num?)?.toDouble() ?? 0;
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Selected date'),
                    subtitle: Text(_displayDate(_selectedDate)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.summarize_outlined),
                    title: const Text('My meals this month'),
                    trailing: Text(
                      _displayQuantity(monthlyTotal),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _hasEntry
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasEntry
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _hasEntry
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hasEntry
                                ? 'Entry saved. You can update it.'
                                : 'Not entered for this date.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _MealCounter(
                    title: 'Lunch',
                    value: _displayQuantity(_lunch),
                    icon: Icons.lunch_dining_outlined,
                    onDecrease: () => _changeLunch(-0.5),
                    onIncrease: () => _changeLunch(0.5),
                  ),
                  const SizedBox(height: 16),
                  _MealCounter(
                    title: 'Dinner',
                    value: _displayQuantity(_dinner),
                    icon: Icons.dinner_dining_outlined,
                    onDecrease: () => _changeDinner(-0.5),
                    onIncrease: () => _changeDinner(0.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveEntry,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _hasEntry ? 'Update Entry' : 'Save Entry',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MealCounter extends StatelessWidget {
  const _MealCounter({
    required this.title,
    required this.value,
    required this.icon,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 54,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton.filled(
              onPressed: onIncrease,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}