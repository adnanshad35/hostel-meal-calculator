import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState
    extends State<GroupSettingsScreen> {
  bool _isLeaving = false;
  bool _isResetting = false;

  FirebaseFirestore get _firestore =>
      FirebaseFirestore.instance;

  User get _currentUser =>
      FirebaseAuth.instance.currentUser!;

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

  String _readMemberName(Map<String, dynamic>? data) {
    final possibleNames = [
      data?['name'],
      data?['displayName'],
      data?['fullName'],
      _currentUser.displayName,
    ];

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return _currentUser.email ?? 'Member';
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

    return !date.isBefore(firstDay) &&
        date.isBefore(nextMonth);
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will permanently delete all meals, '
                      'expenses, and the minimum-meal setting for '
                      '$selectedMonthName.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Members and the hostel will not be deleted.',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Type RESET to continue:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: confirmationText == 'RESET'
                      ? () {
                          Navigator.of(dialogContext)
                              .pop(true);
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

      final admins = List<String>.from(
        groupData['admins'] as List? ?? [],
      );

      if (!admins.contains(_currentUser.uid)) {
        throw Exception(
          'Only an administrator can reset a month.',
        );
      }

      final firstDay = DateTime(
        selectedMonth.year,
        selectedMonth.month,
      );

      final nextMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
      );

      final mealSnapshot =
          await groupReference.collection('meals').get();

      final expenseSnapshot =
          await groupReference.collection('expenses').get();

      final mealReferences =
          <DocumentReference<Map<String, dynamic>>>[];

      final expenseReferences =
          <DocumentReference<Map<String, dynamic>>>[];

      for (final meal in mealSnapshot.docs) {
        if (_mealBelongsToMonth(
          meal,
          selectedMonthKey,
        )) {
          mealReferences.add(meal.reference);
        }
      }

      for (final expense in expenseSnapshot.docs) {
        if (_expenseBelongsToMonth(
          expense,
          firstDay,
          nextMonth,
        )) {
          expenseReferences.add(expense.reference);
        }
      }

      await _deleteDocuments(mealReferences);
      await _deleteDocuments(expenseReferences);

      final monthlySettingReference = groupReference
          .collection('monthlySettings')
          .doc(selectedMonthKey);

      final monthlySettingSnapshot =
          await monthlySettingReference.get();

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

      final message = error
          .toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _leaveGroup({
    required List<String> admins,
  }) async {
    final isAdmin = admins.contains(_currentUser.uid);

    if (isAdmin && admins.length <= 1) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cannot Leave Hostel'),
            content: const Text(
              'You are the only administrator. Promote another '
              'member to administrator before leaving.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Okay'),
              ),
            ],
          );
        },
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Hostel?'),
          content: Text(
            'Are you sure you want to leave '
            '${widget.groupName}?\n\n'
            'Your previous meals and expenses will remain '
            'in the hostel records.',
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
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Leave Hostel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLeaving = true);

    try {
      final groupReference = _firestore
          .collection('groups')
          .doc(widget.groupId);

      final userReference = _firestore
          .collection('users')
          .doc(_currentUser.uid);

      await _firestore.runTransaction((transaction) async {
        final groupSnapshot =
            await transaction.get(groupReference);

        final userSnapshot =
            await transaction.get(userReference);

        if (!groupSnapshot.exists) {
          throw Exception('The hostel could not be found.');
        }

        final groupData = groupSnapshot.data()!;
        final userData = userSnapshot.data();

        final memberIds = List<String>.from(
          groupData['memberIds'] as List? ?? [],
        );

        final currentAdmins = List<String>.from(
          groupData['admins'] as List? ?? [],
        );

        if (!memberIds.contains(_currentUser.uid)) {
          throw Exception(
            'You are no longer a member of this hostel.',
          );
        }

        final currentlyAdmin =
            currentAdmins.contains(_currentUser.uid);

        if (currentlyAdmin &&
            currentAdmins.length <= 1) {
          throw Exception(
            'Promote another member before leaving.',
          );
        }

        memberIds.remove(_currentUser.uid);
        currentAdmins.remove(_currentUser.uid);

        final memberName = _readMemberName(userData);

        transaction.update(groupReference, {
          'memberIds': memberIds,
          'admins': currentAdmins,
          'formerMembers.${_currentUser.uid}': {
            'name': memberName,
            'email': _currentUser.email ?? '',
            'leftAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(userReference, {
          'groupId': null,
          'role': 'member',
          'previousGroupId': widget.groupId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error
          .toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('groups')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Unable to load group settings.',
              ),
            );
          }

          final groupData = snapshot.data!.data()!;

          final admins = List<String>.from(
            groupData['admins'] as List? ?? [],
          );

          final isAdmin =
              admins.contains(_currentUser.uid);

          final isOnlyAdmin =
              isAdmin && admins.length <= 1;

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
                  subtitle: Text(
                    isAdmin
                        ? 'Administrator'
                        : 'Member',
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                Text(
                  'Administrator Settings',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.restart_alt,
                      color: Colors.red,
                    ),
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
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right,
                          ),
                    onTap: _isResetting || _isLeaving
                        ? null
                        : _resetCurrentMonth,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Membership',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Leave Hostel',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    isOnlyAdmin
                        ? 'Promote another administrator first.'
                        : 'Leave this hostel group.',
                  ),
                  trailing: _isLeaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right,
                        ),
                  onTap: _isLeaving || _isResetting
                      ? null
                      : () {
                          _leaveGroup(admins: admins);
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}