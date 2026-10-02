import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageMembersScreen extends StatefulWidget {
  const ManageMembersScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<ManageMembersScreen> createState() =>
      _ManageMembersScreenState();
}

class _ManageMembersScreenState
    extends State<ManageMembersScreen> {
  String? _updatingMemberId;

  FirebaseFirestore get _firestore =>
      FirebaseFirestore.instance;

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser!.uid;

  Future<void> _changeAdminRole({
    required String memberId,
    required String memberName,
    required bool makeAdmin,
  }) async {
    final role = makeAdmin ? 'administrator' : 'member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            makeAdmin ? 'Promote Member' : 'Remove Admin Role',
          ),
          content: Text(
            makeAdmin
                ? 'Promote $memberName to administrator?'
                : 'Change $memberName from administrator to member?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(makeAdmin ? 'Promote' : 'Demote'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updatingMemberId = memberId);

    try {
      final groupReference =
          _firestore.collection('groups').doc(widget.groupId);

      final userReference =
          _firestore.collection('users').doc(memberId);

      await _firestore.runTransaction((transaction) async {
        final groupSnapshot =
            await transaction.get(groupReference);

        if (!groupSnapshot.exists) {
          throw Exception('The hostel group could not be found.');
        }

        final groupData = groupSnapshot.data()!;
        final admins = List<String>.from(
          groupData['admins'] as List? ?? [],
        );

        if (!admins.contains(_currentUserId)) {
          throw Exception(
            'Only an administrator can change member roles.',
          );
        }

        if (makeAdmin) {
          if (!admins.contains(memberId)) {
            admins.add(memberId);
          }
        } else {
          if (!admins.contains(memberId)) return;

          if (admins.length <= 1) {
            throw Exception(
              'The hostel must always have at least one administrator.',
            );
          }

          admins.remove(memberId);
        }

        transaction.update(groupReference, {
          'admins': admins,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(userReference, {
          'role': role == 'administrator'
              ? 'admin'
              : 'member',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            makeAdmin
                ? '$memberName is now an administrator.'
                : '$memberName is now a member.',
          ),
        ),
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
        setState(() => _updatingMemberId = null);
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

    return data['email'] as String? ?? 'Member';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Members'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('groups')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (groupSnapshot.hasError ||
              !groupSnapshot.hasData ||
              !groupSnapshot.data!.exists) {
            return const Center(
              child: Text('Unable to load the hostel group.'),
            );
          }

          final groupData = groupSnapshot.data!.data()!;
          final admins = List<String>.from(
            groupData['admins'] as List? ?? [],
          );

          if (!admins.contains(_currentUserId)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only administrators can manage member roles.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('users')
                .where(
                  'groupId',
                  isEqualTo: widget.groupId,
                )
                .snapshots(),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (memberSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load members.'),
                );
              }

              final members =
                  memberSnapshot.data?.docs ?? [];

              members.sort((first, second) {
                final firstName =
                    _readMemberName(first.data());
                final secondName =
                    _readMemberName(second.data());

                return firstName.compareTo(secondName);
              });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFFE8F5E9),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'A hostel can have multiple administrators, '
                              'but it must always have at least one.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${members.length} Members',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...members.map((member) {
                    final data = member.data();
                    final memberName =
                        _readMemberName(data);
                    final email =
                        data['email'] as String? ?? '';
                    final isAdmin =
                        admins.contains(member.id);
                    final isCurrentUser =
                        member.id == _currentUserId;
                    final isUpdating =
                        _updatingMemberId == member.id;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            isAdmin
                                ? Icons
                                    .admin_panel_settings_outlined
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(
                          isCurrentUser
                              ? '$memberName (You)'
                              : memberName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          email.isEmpty
                              ? isAdmin
                                  ? 'Administrator'
                                  : 'Member'
                              : '$email\n'
                                  '${isAdmin ? 'Administrator' : 'Member'}',
                        ),
                        isThreeLine: email.isNotEmpty,
                        trailing: isUpdating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : PopupMenuButton<String>(
                                tooltip: 'Member options',
                                onSelected: (value) {
                                  if (value == 'promote') {
                                    _changeAdminRole(
                                      memberId: member.id,
                                      memberName:
                                          memberName,
                                      makeAdmin: true,
                                    );
                                  } else if (value ==
                                      'demote') {
                                    _changeAdminRole(
                                      memberId: member.id,
                                      memberName:
                                          memberName,
                                      makeAdmin: false,
                                    );
                                  }
                                },
                                itemBuilder: (context) {
                                  if (isAdmin) {
                                    return const [
                                      PopupMenuItem(
                                        value: 'demote',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .person_remove_outlined,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Change to Member',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ];
                                  }

                                  return const [
                                    PopupMenuItem(
                                      value: 'promote',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .admin_panel_settings_outlined,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Make Administrator',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}