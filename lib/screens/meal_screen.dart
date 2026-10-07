import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'meal_ledger_screen.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

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

  void _openLedger() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealLedgerScreen(
          groupId: widget.groupId,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  void _openMyMeals() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyMealsScreen(
          groupId: widget.groupId,
          currentUserId: _user.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Update'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _mealCollection.snapshots(),
          builder: (context, snapshot) {
            double totalMealsMonthly = 0;
            double myMonthlyTotal = 0;

            if (snapshot.hasData) {
              for (final document in snapshot.data!.docs) {
                final data = document.data();
                final dateKey = data['dateKey'] as String? ?? '';
                final userId = data['userId'] as String?;

                if (!dateKey.startsWith(currentMonth)) continue;

                final total =
                    (data['total'] as num?)?.toDouble() ?? 0;

                totalMealsMonthly += total;

                if (userId == _user.uid) {
                  myMonthlyTotal += total;
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ─── Top: two summary cards ───
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.groups_outlined,
                        title: 'Total Meals',
                        value: _displayQuantity(totalMealsMonthly),
                        subtitle: 'This month',
                        color: const Color(0xFF2E7D32), // <--- NOW GREEN
                        onTap: _openLedger,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.person_outline,
                        title: 'My Meals',
                        value: _displayQuantity(myMonthlyTotal),
                        subtitle: 'This month',
                        color: const Color(0xFF2E7D32), // green
                        onTap: _openMyMeals,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Selected date card (unchanged) ───
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Selected date'),
                    subtitle: Text(_displayDate(_selectedDate)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _selectDate,
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

// ─────────────────────────────────────────────────────────────
// Tappable summary tile
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
                    .headlineMedium
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
// My Meals screen — listens to the same simple query as the
// main screen and filters client-side to avoid needing a
// composite Firestore index.
// ─────────────────────────────────────────────────────────────
class MyMealsScreen extends StatelessWidget {
  const MyMealsScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  final String groupId;
  final String currentUserId;

  String _monthKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  String _displayQuantity(double value) {
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  String _weekdayName(int weekday) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = _monthKey(now);

    final stream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('meals')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meals'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your meals.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = (snapshot.data?.docs ?? [])
              .where((d) {
                final data = d.data();
                final userId = data['userId'] as String?;
                final dateKey = data['dateKey'] as String? ?? '';
                return userId == currentUserId &&
                    dateKey.startsWith(currentMonth);
              })
              .toList();

          docs.sort((a, b) {
            final aKey = a.data()['dateKey'] as String? ?? '';
            final bKey = b.data()['dateKey'] as String? ?? '';
            return bKey.compareTo(aKey); // newest first
          });

          double totalMeals = 0;
          for (final d in docs) {
            totalMeals +=
                (d.data()['total'] as num?)?.toDouble() ?? 0;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 38,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_monthName(now.month)} ${now.year}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text('${docs.length} entries'),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('My meals'),
                          Text(
                            _displayQuantity(totalMeals),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'You have not entered any meals this month.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final doc in docs)
                  _MyMealEntryTile(
                    data: doc.data(),
                    weekdayName: _weekdayName,
                    displayQuantity: _displayQuantity,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _MyMealEntryTile extends StatelessWidget {
  const _MyMealEntryTile({
    required this.data,
    required this.weekdayName,
    required this.displayQuantity,
  });

  final Map<String, dynamic> data;
  final String Function(int) weekdayName;
  final String Function(double) displayQuantity;

  @override
  Widget build(BuildContext context) {
    final dateKey = data['dateKey'] as String? ?? '';
    final lunch = (data['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (data['dinner'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;

    DateTime? parsedDate;
    try {
      final parts = dateKey.split('-');
      parsedDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      parsedDate = null;
    }

    final label = parsedDate != null
        ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}'
        : dateKey;

    final weekday = parsedDate != null
        ? weekdayName(parsedDate.weekday)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            parsedDate != null ? parsedDate.day.toString() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          weekday.isEmpty ? label : '$weekday • $label',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Lunch: ${displayQuantity(lunch)}   '
          'Dinner: ${displayQuantity(dinner)}',
        ),
        trailing: Text(
          displayQuantity(total),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E7D32),
              ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Existing lunch / dinner counter — unchanged
// ─────────────────────────────────────────────────────────────
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