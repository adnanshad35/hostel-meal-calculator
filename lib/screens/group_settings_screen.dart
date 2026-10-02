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

  FirebaseFirestore get _firestore =>
      FirebaseFirestore.instance;

  User get _currentUser =>
      FirebaseAuth.instance.currentUser!;

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
      final groupReference =
          _firestore.collection('groups').doc(widget.groupId);

      final userReference =
          _firestore.collection('users').doc(_currentUser.uid);

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

        if (currentlyAdmin && currentAdmins.length <= 1) {
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
              child: Text('Unable to load group settings.'),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isLeaving
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