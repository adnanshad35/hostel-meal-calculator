import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_group_screen.dart';
import 'hostel_dashboard_screen.dart';
import 'join_group_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CreateGroupScreen(),
      ),
    );
  }

  Future<void> _openJoinGroup(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const JoinGroupScreen(),
      ),
    );
  }

  String _readUserName(
    User user,
    Map<String, dynamic>? userData,
  ) {
    final possibleNames = [
      userData?['name'],
      userData?['displayName'],
      userData?['fullName'],
      user.displayName,
    ];

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
  }

  Future<void> _showUserDetails(
    BuildContext context, {
    required User user,
    required String name,
    required String role,
    required String? groupName,
  }) async {
    final roleLabel =
        role == 'admin' ? 'Administrator' : 'Member';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_circle_outlined),
              SizedBox(width: 10),
              Text('My Profile'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileRow(
                label: 'Name',
                value: name,
              ),
              const SizedBox(height: 14),
              _ProfileRow(
                label: 'Email',
                value: user.email ?? 'Not available',
              ),
              const SizedBox(height: 14),
              _ProfileRow(
                label: 'Role',
                value: groupName == null
                    ? 'No hostel group'
                    : roleLabel,
              ),
              if (groupName != null) ...[
                const SizedBox(height: 14),
                _ProfileRow(
                  label: 'Hostel',
                  value: groupName,
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Color(0xFF2E7D32),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Hostel Meal Calculator'),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A simple and transparent application for '
                  'managing hostel meals, shared expenses, '
                  'meal rates, and monthly member balances.',
                ),
                SizedBox(height: 20),
                Text(
                  'Main Features',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('• Daily lunch and dinner entry'),
                Text('• Shared expense management'),
                Text('• Transparent monthly calculations'),
                Text('• Administrator and member roles'),
                Text('• Minimum monthly meal settings'),
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 12),
                Text(
                  'Developer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text('Abu Adnan Shad'),
                Text(
                  'Independent Flutter and Firebase project',
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (userSnapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load your account information.',
                ),
              );
            }

            final userData = userSnapshot.data?.data();
            final groupId =
                userData?['groupId'] as String?;
            final role =
                userData?['role'] as String? ?? 'member';
            final name = _readUserName(user, userData);

            if (groupId == null || groupId.isEmpty) {
              return _HomeWithoutGroup(
                name: name,
                email: user.email,
                onCreateGroup: () {
                  _openCreateGroup(context);
                },
                onJoinGroup: () {
                  _openJoinGroup(context);
                },
                onProfile: () {
                  _showUserDetails(
                    context,
                    user: user,
                    name: name,
                    role: role,
                    groupName: null,
                  );
                },
                onAbout: () {
                  _showAbout(context);
                },
              );
            }

            return StreamBuilder<
                DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .snapshots(),
              builder: (context, groupSnapshot) {
                if (groupSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (groupSnapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load the hostel group.',
                    ),
                  );
                }

                if (!groupSnapshot.hasData ||
                    !groupSnapshot.data!.exists) {
                  return const Center(
                    child: Text(
                      'The hostel group could not be found.',
                    ),
                  );
                }

                final group = groupSnapshot.data!.data()!;

                final groupName =
                    group['name'] as String? ??
                        'Hostel Group';

                final inviteCode =
                    group['inviteCode'] as String? ?? '';

                final memberIds = List<String>.from(
                  group['memberIds'] as List? ?? [],
                );

                return _HomeWithGroup(
                  name: name,
                  email: user.email,
                  groupName: groupName,
                  role: role,
                  memberCount: memberIds.length,
                  onOpenHostel: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            HostelDashboardScreen(
                          groupId: groupId,
                          groupName: groupName,
                          inviteCode: inviteCode,
                          memberName: name,
                          role: role,
                        ),
                      ),
                    );
                  },
                  onProfile: () {
                    _showUserDetails(
                      context,
                      user: user,
                      name: name,
                      role: role,
                      groupName: groupName,
                    );
                  },
                  onAbout: () {
                    _showAbout(context);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HomeWithoutGroup extends StatelessWidget {
  const _HomeWithoutGroup({
    required this.name,
    required this.email,
    required this.onCreateGroup,
    required this.onJoinGroup,
    required this.onProfile,
    required this.onAbout,
  });

  final String name;
  final String? email;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  final VoidCallback onProfile;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, $name!',
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
        ),
        const SizedBox(height: 4),
        Text(email ?? ''),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 48,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 12),
                Text(
                  'No hostel group yet',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a new hostel or join an existing one.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onCreateGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Group'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onJoinGroup,
                  icon:
                      const Icon(Icons.group_add_outlined),
                  label: const Text('Join Group'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _GeneralOptions(
          onProfile: onProfile,
          onAbout: onAbout,
        ),
      ],
    );
  }
}

class _HomeWithGroup extends StatelessWidget {
  const _HomeWithGroup({
    required this.name,
    required this.email,
    required this.groupName,
    required this.role,
    required this.memberCount,
    required this.onOpenHostel,
    required this.onProfile,
    required this.onAbout,
  });

  final String name;
  final String? email;
  final String groupName;
  final String role;
  final int memberCount;
  final VoidCallback onOpenHostel;
  final VoidCallback onProfile;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final roleLabel =
        role == 'admin' ? 'Administrator' : 'Member';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, $name!',
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
        ),
        const SizedBox(height: 4),
        Text(email ?? ''),
        const SizedBox(height: 24),
        Text(
          'My Hostel',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
        ),
        const SizedBox(height: 8),
        Card(
          color: const Color(0xFFE8F5E9),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpenHostel,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFC8E6C9),
                    child: Icon(
                      Icons.apartment_outlined,
                      size: 30,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$roleLabel • $memberCount '
                          '${memberCount == 1 ? 'member' : 'members'}',
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap to open hostel',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _GeneralOptions(
          onProfile: onProfile,
          onAbout: onAbout,
        ),
      ],
    );
  }
}

class _GeneralOptions extends StatelessWidget {
  const _GeneralOptions({
    required this.onProfile,
    required this.onAbout,
  });

  final VoidCallback onProfile;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.account_circle_outlined),
            title: const Text('My Profile'),
            subtitle: const Text(
              'View your account and hostel information.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onProfile,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App & Developer'),
            subtitle: const Text(
              'Learn more about this application.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAbout,
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style:
              Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
        ),
      ],
    );
  }
}