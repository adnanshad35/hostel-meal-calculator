import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/error_messages.dart';
import '../widgets/meal_counter.dart';

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
  State<AdminMealEditScreen> createState() => _AdminMealEditScreenState();
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
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  Future<bool> _confirmLargeQuantity() async {
    if (_lunch <= 5 && _dinner <= 5) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Large Quantity'),
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

      await reference.set(data, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.memberName}’s meal entry was saved.')),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save the meal entry.'),
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
      appBar: AppBar(title: const Text('Edit Member Meal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  widget.memberName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(displayedDate),
                trailing: const Chip(label: Text('Admin Edit')),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    MealCounter(
                      title: 'Lunch',
                      icon: Icons.lunch_dining_outlined,
                      value: _lunch,
                      enabled: !_isSaving,
                      onChanged: (value) {
                        setState(() => _lunch = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    MealCounter(
                      title: 'Dinner',
                      icon: Icons.dinner_dining_outlined,
                      value: _dinner,
                      enabled: !_isSaving,
                      onChanged: (value) {
                        setState(() => _dinner = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(widget.hasEntry ? 'Update Entry' : 'Create Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
