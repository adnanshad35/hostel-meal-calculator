import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/group_member_service.dart';
import '../widgets/member_name_dialog.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _isResetting = false;
  bool _isAddingMember = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User get _currentUser => FirebaseAuth.instance.currentUser!;

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _monthName(DateTime date) {
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

    return '${months[date.month - 1]} ${date.year}';
  }

  bool _mealBelongsToMonth(
    QueryDocumentSnapshot<Map<String, dynamic>> meal,
    String selectedMonthKey,
  ) {
    final data = meal.data();
    final savedMonthKey = data['monthKey'] as String?;
    final dateKey = data['dateKey'] as String?;

    return savedMonthKey == selectedMonthKey ||
        dateKey?.startsWith(selectedMonthKey) == true ||
        meal.id.contains('_$selectedMonthKey-');
  }

  bool _expenseBelongsToMonth(
    QueryDocumentSnapshot<Map<String, dynamic>> expense,
    DateTime firstDay,
    DateTime nextMonth,
  ) {
    final timestamp = expense.data()['date'];

    if (timestamp is! Timestamp) {
      return false;
    }

    final date = timestamp.toDate();

    return !date.isBefore(firstDay) && date.isBefore(nextMonth);
  }

  Future<void> _deleteDocuments(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (final reference in references) {
      try {
        await reference.delete();
      } on FirebaseException catch (error) {
        throw Exception(
          'Reset failed while deleting:\n'
          '${reference.path}\n\n'
          '${error.message ?? error.code}',
        );
      }
    }
  }

  Future<void> _resetCurrentMonth() async {
    final now = DateTime.now();
    final selectedMonth = DateTime(now.year, now.month);
    final selectedMonthKey = _monthKey(selectedMonth);
    final selectedMonthName = _monthName(selectedMonth);

    String confirmationText = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Current Month?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will permanently delete all meals, '
                      'expenses, and the minimum-meal setting for '
                      '$selectedMonthName.',
                    ),
                    const SizedBox(height: 12),
                    const Text('Members and the hostel will not be deleted.'),
                    const SizedBox(height: 18),
                    const Text(
                      'Type RESET to continue:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'RESET',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          confirmationText = value.trim();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: confirmationText == 'RESET'
                      ? () {
                          Navigator.of(dialogContext).pop(true);
                        }
                      : null,
                  child: const Text('Reset Month'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);

    try {
      final groupReference = _firestore
          .collection('groups')
          .doc(widget.groupId);

      final groupSnapshot = await groupReference.get();

      if (!groupSnapshot.exists) {
        throw Exception('The hostel could not be found.');
      }

      final groupData = groupSnapshot.data()!;

      final admins = List<String>.from(groupData['admins'] as List? ?? []);

      if (!admins.contains(_currentUser.uid)) {
        throw Exception('Only an administrator can reset a month.');
      }

      final firstDay = DateTime(selectedMonth.year, selectedMonth.month);

      final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);

      final mealSnapshot = await groupReference.collection('meals').get();

      final expenseSnapshot = await groupReference.collection('expenses').get();

      final mealReferences = <DocumentReference<Map<String, dynamic>>>[];

      final expenseReferences = <DocumentReference<Map<String, dynamic>>>[];

      for (final meal in mealSnapshot.docs) {
        if (_mealBelongsToMonth(meal, selectedMonthKey)) {
          mealReferences.add(meal.reference);
        }
      }

      for (final expense in expenseSnapshot.docs) {
        // Entries without a readable date belong to no month, so no
        // reset would ever clear them and no calculation counts them.
        final hasNoDate = expense.data()['date'] is! Timestamp;

        if (hasNoDate || _expenseBelongsToMonth(expense, firstDay, nextMonth)) {
          expenseReferences.add(expense.reference);
        }
      }

      final depositSnapshot = await groupReference.collection('deposits').get();
      final depositReferences = [
        for (final deposit in depositSnapshot.docs)
          if (deposit.data()['date'] is! Timestamp ||
              _expenseBelongsToMonth(deposit, firstDay, nextMonth))
            deposit.reference,
      ];

      await _deleteDocuments(mealReferences);
      await _deleteDocuments(expenseReferences);
      await _deleteDocuments(depositReferences);

      final monthlySettingReference = groupReference
          .collection('monthlySettings')
          .doc(selectedMonthKey);

      final monthlySettingSnapshot = await monthlySettingReference.get();

      if (monthlySettingSnapshot.exists) {
        try {
          await monthlySettingReference.delete();
        } on FirebaseException catch (error) {
          throw Exception(
            'Reset failed while deleting:\n'
            '${monthlySettingReference.path}\n\n'
            '${error.message ?? error.code}',
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$selectedMonthName reset successfully. '
            '${mealReferences.length} meal entries and '
            '${expenseReferences.length} expenses were removed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _addShadowMember() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const MemberNameDialog(title: 'Add Member'),
    );

    if (name == null || !mounted) return;

    setState(() => _isAddingMember = true);

    try {
      await GroupMemberService.addShadowMember(
        groupId: widget.groupId,
        name: name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name was added to the hostel.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an administrator can add members.'
                : error.message ?? 'Unable to add the member.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingMember = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Settings')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Unable to load group settings.'));
          }

          final groupData = snapshot.data!.data()!;

          final admins = List<String>.from(groupData['admins'] as List? ?? []);

          final isAdmin = admins.contains(_currentUser.uid);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: const Color(0xFFE8F5E9),
                child: ListTile(
                  leading: const Icon(
                    Icons.apartment_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text(widget.groupName),
                  subtitle: Text(isAdmin ? 'Administrator' : 'Member'),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                Text(
                  'Administrator Settings',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: const Text(
                      'Add Member Without the App',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Add someone by name so their meals and '
                      'expenses can be recorded.',
                    ),
                    trailing: _isAddingMember
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isAddingMember ? null : _addShadowMember,
                  ),
                ),
                const SizedBox(height: 8),
                if ((groupData['inviteCode'] as String? ?? '').isNotEmpty) ...[
                  _InviteSwitchCard(
                    key: ValueKey(groupData['inviteCode']),
                    inviteCode: groupData['inviteCode'] as String,
                  ),
                  const SizedBox(height: 8),
                ],
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restart_alt, color: Colors.red),
                    title: const Text(
                      'Reset Current Month',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Delete this month’s meals, expenses, '
                      'and minimum-meal setting.',
                    ),
                    trailing: _isResetting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isResetting ? null : _resetCurrentMonth,
                  ),
                ),
              ],
              if (!isAdmin) ...[
                const SizedBox(height: 20),
                const Text(
                  'Only administrators can change group settings.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Lets an admin switch the hostel's invitation code off and on.
class _InviteSwitchCard extends StatefulWidget {
  const _InviteSwitchCard({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  State<_InviteSwitchCard> createState() => _InviteSwitchCardState();
}

class _InviteSwitchCardState extends State<_InviteSwitchCard> {
  late final DocumentReference<Map<String, dynamic>> _invite;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _invite = FirebaseFirestore.instance
        .collection('invites')
        .doc(widget.inviteCode);
    _stream = _invite.snapshots();
  }

  Future<void> _setActive(bool active) async {
    setState(() => _isSaving = true);

    try {
      await _invite.update({
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'New members can join with the invitation code.'
                : 'Joining is switched off.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to update the invitation.'),
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isActive = data?['active'] == true;

        return Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text(
              'Allow new members to join',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              data == null
                  ? 'Checking the invitation code…'
                  : isActive
                  ? 'Anyone with the invitation code can join.'
                  : 'The invitation code is switched off.',
            ),
            value: isActive,
            onChanged: data == null || _isSaving ? null : _setActive,
          ),
        );
      },
    );
  }
}
