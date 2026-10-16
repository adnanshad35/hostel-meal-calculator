import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/group_member_service.dart';
import '../services/hostel_settings.dart';
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
              title: Text(
                'Reset $selectedMonthName',
                style: const TextStyle(color: AppTheme.danger),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This permanently deletes every meal, expense and '
                      'the minimum-meal setting of $selectedMonthName. '
                      'Members and the hostel stay.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Type RESET to continue',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'RESET'),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                  ),
                  onPressed: confirmationText == 'RESET'
                      ? () {
                          Navigator.of(dialogContext).pop(true);
                        }
                      : null,
                  child: const Text('Reset'),
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

      await _deleteDocuments(mealReferences);
      await _deleteDocuments(expenseReferences);

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

  /// Saves one changed switch. The switch moves at once, because the
  /// hostel's own record reports the new value straight away; nothing
  /// else on the screen changes while it saves.
  Future<void> _saveSettings(HostelSettings settings) async {
    try {
      await HostelSettingsService.save(widget.groupId, settings);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an admin can change these settings.'
                : error.message ?? 'Unable to save the settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Unable to load the settings.'));
          }

          final groupData = snapshot.data!.data()!;

          final admins = List<String>.from(groupData['admins'] as List? ?? []);

          final isAdmin = admins.contains(_currentUser.uid);
          final settings = HostelSettings.fromGroupData(groupData);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (isAdmin) ...[
                if ((groupData['inviteCode'] as String? ?? '').isNotEmpty) ...[
                  _InviteSwitchCard(
                    key: ValueKey(groupData['inviteCode']),
                    inviteCode: groupData['inviteCode'] as String,
                  ),
                  const SizedBox(height: 8),
                ],
                _SettingSwitch(
                  icon: Icons.restaurant_outlined,
                  title: 'Member Can Add Meals',
                  value: settings.membersCanAddMeals,
                  onChanged: (isOn) => _saveSettings(
                    settings.copyWith(membersCanAddMeals: isOn),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingSwitch(
                  icon: Icons.receipt_long_outlined,
                  title: 'Member Can Add Expenses',
                  value: settings.membersCanAddExpenses,
                  onChanged: (isOn) => _saveSettings(
                    settings.copyWith(membersCanAddExpenses: isOn),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingSwitch(
                  icon: Icons.edit_note_outlined,
                  title: 'Member Can Edit Meals & Expenses',
                  value: settings.membersCanEdit,
                  onChanged: (isOn) =>
                      _saveSettings(settings.copyWith(membersCanEdit: isOn)),
                ),
                const SizedBox(height: 8),
                _SettingSwitch(
                  icon: Icons.lock_open_outlined,
                  title: 'Special Permission',
                  value: settings.specialPermission,
                  onChanged: (isOn) =>
                      _saveSettings(settings.copyWith(specialPermission: isOn)),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text(
                      'Member Without App',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: _isAddingMember
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    onTap: _isAddingMember ? null : _addShadowMember,
                  ),
                ),
                const SizedBox(height: 8),
                // Not ready yet: shown so admins know it is on the way.
                const Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    enabled: false,
                    leading: Icon(Icons.home_work_outlined),
                    title: Text(
                      'Calculate Other Costs',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                  'Only administrators can change the settings.',
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

/// One on/off setting, in the same card as the other settings.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        value: value,
        onChanged: onChanged,
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'New members can now join with the invitation code.'
                  : 'No one can join the hostel now.',
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
            secondary: const Icon(Icons.group_add_outlined),
            title: const Text(
              'Allow New Member',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            value: isActive,
            onChanged: data == null || _isSaving ? null : _setActive,
          ),
        );
      },
    );
  }
}
