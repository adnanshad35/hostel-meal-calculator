import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/activity_log.dart';
import '../services/group_member_service.dart';
import '../services/hostel_settings.dart';
import '../services/member_departure_service.dart';
import '../services/month_rules.dart';
import '../widgets/app_tiles.dart';
import '../widgets/leaving_choice_sheet.dart';
import '../widgets/member_name_dialog.dart';
import 'alumni_screen.dart';
import 'duty_roster_screen.dart';
import 'notifications_screen.dart';

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

  /// Who left in a month that is still open. Read once, so the list
  /// does not restart with every change to the hostel.
  late final Stream<List<Departure>> _departures =
      MemberDepartureService.watchOpen(widget.groupId);

  /// The hostel, live. Each page listens on its own, so every page
  /// gets the current figures as soon as it opens.
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _group =>
      _firestore.collection('groups').doc(widget.groupId).snapshots();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _mainGroup = _group;

  /// Bumped on every rebuild, so an open section page rebuilds too.
  final _changes = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _changes.value++;
  }

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  /// Opens one section of the settings on its own page.
  void _openSection(
    String title,
    List<Widget> Function(Map<String, dynamic> groupData) tiles,
  ) {
    final sectionGroup = _group;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: sectionGroup,
            builder: (context, snapshot) {
              final groupData = snapshot.data?.data();
              if (groupData == null) {
                return snapshot.hasError
                    ? const Center(child: Text('Unable to load the settings.'))
                    : const Center(child: CircularProgressIndicator());
              }

              return ListenableBuilder(
                listenable: _changes,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [TileGroup(children: tiles(groupData))],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static const Widget _progress = SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  List<Widget> _memberTiles(Map<String, dynamic> groupData) {
    final inviteCode = groupData['inviteCode'] as String? ?? '';

    // The member list itself is in Hostel Details.
    return [
      GroupTile(
        icon: Icons.school_outlined,
        title: 'Alumni',
        onTap: () => _open(AlumniScreen(groupId: widget.groupId)),
      ),
      if (inviteCode.isNotEmpty)
        _InviteSwitch(key: ValueKey(inviteCode), inviteCode: inviteCode),
      GroupTile(
        icon: Icons.person_add_alt_outlined,
        title: 'Add Member Without App',
        trailing: _isAddingMember
            ? _progress
            : const Icon(Icons.add, color: AppTheme.primary),
        onTap: _isAddingMember ? null : _addShadowMember,
      ),
      GroupTile(
        icon: Icons.assignment_ind_outlined,
        title: 'Duty Roster',
        onTap: () => _open(DutyRosterScreen(groupId: widget.groupId)),
      ),
    ];
  }

  List<Widget> _permissionTiles(Map<String, dynamic> groupData) {
    final settings = HostelSettings.fromGroupData(groupData);

    return [
      SwitchTile(
        icon: Icons.restaurant_outlined,
        title: 'Add Meals',
        value: settings.membersCanAddMeals,
        onChanged: (isOn) =>
            _saveSettings(settings.copyWith(membersCanAddMeals: isOn)),
      ),
      SwitchTile(
        icon: Icons.receipt_long_outlined,
        title: 'Add Expenses',
        value: settings.membersCanAddExpenses,
        onChanged: (isOn) =>
            _saveSettings(settings.copyWith(membersCanAddExpenses: isOn)),
      ),
      SwitchTile(
        icon: Icons.edit_note_outlined,
        title: 'Edit Their Entries',
        value: settings.membersCanEdit,
        onChanged: (isOn) =>
            _saveSettings(settings.copyWith(membersCanEdit: isOn)),
      ),
    ];
  }

  List<Widget> _monthEndTiles(Map<String, dynamic> groupData) {
    final settings = HostelSettings.fromGroupData(groupData);

    return [
      // Min Meals and Shop Due open from the 25th to the 5th, unless
      // this is on.
      SwitchTile(
        icon: Icons.lock_open_outlined,
        title: 'Min Meals & Shop Due Any Day',
        value: settings.specialPermission,
        onChanged: (isOn) =>
            _saveSettings(settings.copyWith(specialPermission: isOn)),
      ),
      GroupTile(
        icon: Icons.person_remove_outlined,
        title: 'Remove All Limits',
        trailing: _LimitsLabel(settings.removeAllLimits),
        onTap: () => _editLimits(settings),
      ),
    ];
  }

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

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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

      // Recorded first, so a reset can never happen unseen.
      await ActivityLog.add(
        widget.groupId,
        kind: ActivityKind.monthReset,
        subject: selectedMonthName,
        day: selectedMonthKey,
        details:
            '${mealReferences.length} meal entries and '
            '${expenseReferences.length} expenses deleted',
      );

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

  /// Shows how [departure]'s month counts, so an admin can choose it or
  /// change it while the month is open.
  Future<void> _openDeparture(
    Departure departure,
    HostelSettings settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final parts = departure.leftOn.split('-').map(int.parse).toList();

    DepartureSummary summary;
    try {
      summary = await MemberDepartureService.summarize(
        groupId: widget.groupId,
        memberId: departure.memberId,
        leftOn: DateTime(parts[0], parts[1], parts[2]),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to load this month.')),
      );
      return;
    }

    if (!mounted) return;

    final choice = await showLeavingChoiceSheet(
      context,
      memberName: departure.memberName,
      summary: summary,
      limits: settings.removeAllLimits,
      initial: departure.choice,
    );

    if (choice == null || choice == departure.choice) return;

    try {
      await MemberDepartureService.decide(
        groupId: widget.groupId,
        departure: departure,
        choice: choice,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${departure.memberName}: ${choice.label}.')),
      );
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'This month is closed, so it can no longer change.'
                : error.message ?? 'Unable to save the choice.',
          ),
        ),
      );
    }
  }

  /// Lets an admin change when Remove All is offered.
  Future<void> _editLimits(HostelSettings settings) async {
    final limits = await showDialog<RemoveAllLimits>(
      context: context,
      builder: (_) => _LimitsDialog(initial: settings.removeAllLimits),
    );

    if (limits == null) return;
    await _saveSettings(settings.copyWith(removeAllLimits: limits));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _mainGroup,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (isAdmin) ...[
                _DeparturesGroup(
                  departures: _departures,
                  onOpen: (departure) => _openDeparture(departure, settings),
                ),
                TileGroup(
                  children: [
                    GroupTile(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Member Settings',
                      onTap: () =>
                          _openSection('Member Settings', _memberTiles),
                    ),
                    GroupTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Member Permissions',
                      onTap: () =>
                          _openSection('Member Permissions', _permissionTiles),
                    ),
                    GroupTile(
                      icon: Icons.event_available_outlined,
                      title: 'Month End',
                      onTap: () => _openSection('Month End', _monthEndTiles),
                    ),
                    GroupTile(
                      icon: Icons.campaign_outlined,
                      title: 'Send Announcement',
                      onTap: () => _open(
                        NotificationsScreen(
                          groupId: widget.groupId,
                          isAdmin: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TileGroup(
                  title: 'Danger Zone',
                  children: [
                    GroupTile(
                      icon: Icons.restart_alt,
                      title: 'Reset This Month',
                      isDanger: true,
                      trailing: _isResetting ? _progress : null,
                      onTap: _isResetting ? null : _resetCurrentMonth,
                    ),
                  ],
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

/// Lets an admin switch the hostel's invitation code off and on.
class _InviteSwitch extends StatefulWidget {
  const _InviteSwitch({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  State<_InviteSwitch> createState() => _InviteSwitchState();
}

class _InviteSwitchState extends State<_InviteSwitch> {
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

        return SwitchTile(
          icon: Icons.group_add_outlined,
          title: 'Allow New Members',
          value: isActive,
          onChanged: data == null || _isSaving ? null : _setActive,
        );
      },
    );
  }
}

/// Members who left in a month that is still open, at the top of the
/// page, with the ones waiting for a choice marked. Shows nothing when
/// there are none.
class _DeparturesGroup extends StatelessWidget {
  const _DeparturesGroup({required this.departures, required this.onOpen});

  final Stream<List<Departure>> departures;
  final ValueChanged<Departure> onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Departure>>(
      stream: departures,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Departure>[];
        if (items.isEmpty) return const SizedBox.shrink();

        final pending = items.where((item) => item.isPending).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: TileGroup(
            title: pending == 0
                ? 'Members Who Left'
                : 'Members Who Left · $pending Pending',
            children: [
              for (final departure in items)
                GroupTile(
                  icon: Icons.exit_to_app,
                  title: departure.memberName,
                  onTap: () => onOpen(departure),
                  trailing: departure.isPending
                      ? const Text(
                          'Pending',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : Text(
                          _shortLabel(departure.choice!),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _shortLabel(LeavingChoice choice) => switch (choice) {
    LeavingChoice.normal => 'Normal',
    LeavingChoice.actualOnly => 'Actual Only',
    LeavingChoice.removeAll => 'Removed',
  };
}

/// "5 · ৳200", the limits on the tile.
class _LimitsLabel extends StatelessWidget {
  const _LimitsLabel(this.limits);

  final RemoveAllLimits limits;

  static String _number(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_number(limits.maxMeals)} · ৳${_number(limits.maxExpense)}',
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The two limits for Remove All: fewer meals and less paid than these.
class _LimitsDialog extends StatefulWidget {
  const _LimitsDialog({required this.initial});

  final RemoveAllLimits initial;

  @override
  State<_LimitsDialog> createState() => _LimitsDialogState();
}

class _LimitsDialogState extends State<_LimitsDialog> {
  late final TextEditingController _meals;
  late final TextEditingController _expense;

  static String _number(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  @override
  void initState() {
    super.initState();
    _meals = TextEditingController(text: _number(widget.initial.maxMeals));
    _expense = TextEditingController(text: _number(widget.initial.maxExpense));
  }

  @override
  void dispose() {
    _meals.dispose();
    _expense.dispose();
    super.dispose();
  }

  double? _read(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value == null || value < 0 ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final meals = _read(_meals);
    final expense = _read(_expense);

    return AlertDialog(
      title: const Text('Remove All Limits'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Remove All is offered only for a member below both.'),
          const SizedBox(height: 16),
          TextField(
            controller: _meals,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Max Meals',
              prefixIcon: Icon(Icons.restaurant_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expense,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Max Expense (৳)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const RemoveAllLimits()),
          child: const Text('Reset'),
        ),
        FilledButton(
          onPressed: meals == null || expense == null
              ? null
              : () => Navigator.of(context)
                    .pop(RemoveAllLimits(maxMeals: meals, maxExpense: expense)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
