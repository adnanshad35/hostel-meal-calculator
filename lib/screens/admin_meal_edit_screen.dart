import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminMealEditScreen extends StatefulWidget {
  const AdminMealEditScreen({
    super.key,
    required this.groupId,
    required this.memberId,
    required this.memberName,
    required this.date,
    required this.dateKey,
    required this.initialLunch,
    required this.initialDinner,
    required this.hasEntry,
  });

  final String groupId;
  final String memberId;
  final String memberName;
  final DateTime date;
  final String dateKey;
  final double initialLunch;
  final double initialDinner;
  final bool hasEntry;

  @override
  State<AdminMealEditScreen> createState() =>
      _AdminMealEditScreenState();
}

class _AdminMealEditScreenState extends State<AdminMealEditScreen> {
  late double _lunch;
  late double _dinner;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lunch = widget.initialLunch;
    _dinner = widget.initialDinner;
  }

  String _displayQuantity(double value) {
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
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
                '${_displayQuantity(_dinner)} dinner meals for '
                '${widget.memberName}. Are these values correct?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Review'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _save() async {
    final administrator = FirebaseAuth.instance.currentUser;

    if (administrator == null) return;

    final confirmed = await _confirmLargeQuantity();

    if (!confirmed) return;

    setState(() => _isSaving = true);

    try {
      final entryId = '${widget.memberId}_${widget.dateKey}';

      final reference = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('meals')
          .doc(entryId);

      final data = <String, dynamic>{
        'groupId': widget.groupId,
        'userId': widget.memberId,
        'userName': widget.memberName,
        'dateKey': widget.dateKey,
        'date': Timestamp.fromDate(widget.date),
        'lunch': _lunch,
        'dinner': _dinner,
        'total': _lunch + _dinner,
        'submitted': true,
        'updatedBy': administrator.uid,
        'updatedByName': administrator.displayName ?? 'Administrator',
        'updatedAt': FieldValue.serverTimestamp(),
        'adminEdited': true,
      };

      if (!widget.hasEntry) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await reference.set(
        data,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.memberName}’s meal entry was saved.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an administrator can edit this member’s entry.'
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
    final displayedDate =
        '${widget.date.day}/${widget.date.month}/${widget.date.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Member Meal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                title: Text(
                  widget.memberName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(displayedDate),
                trailing: const Chip(
                  label: Text('Admin edit'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _AdminMealCounter(
              title: 'Lunch',
              value: _displayQuantity(_lunch),
              icon: Icons.lunch_dining_outlined,
              onDecrease: () => _changeLunch(-0.5),
              onIncrease: () => _changeLunch(0.5),
            ),
            const SizedBox(height: 16),
            _AdminMealCounter(
              title: 'Dinner',
              value: _displayQuantity(_dinner),
              icon: Icons.dinner_dining_outlined,
              onDecrease: () => _changeDinner(-0.5),
              onIncrease: () => _changeDinner(0.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
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
                  widget.hasEntry ? 'Update Entry' : 'Create Entry',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This administrative change records who edited the entry.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMealCounter extends StatelessWidget {
  const _AdminMealCounter({
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