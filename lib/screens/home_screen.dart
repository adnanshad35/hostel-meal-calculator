import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_group_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Meal Calculator'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (userSnapshot.hasError) {
              return const Center(
                child: Text('Unable to load your account information.'),
              );
            }

            final userData = userSnapshot.data?.data();
            final groupId = userData?['groupId'] as String?;

            if (groupId == null || groupId.isEmpty) {
              return _NoGroupView(
                name: user.displayName,
                email: user.email,
                onCreateGroup: () => _openCreateGroup(context),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

                if (!groupSnapshot.hasData ||
                    !groupSnapshot.data!.exists) {
                  return const Center(
                    child: Text('The hostel group could not be found.'),
                  );
                }

                final group = groupSnapshot.data!.data()!;

                return _GroupDashboard(
                  memberName: user.displayName,
                  groupName: group['name'] as String? ?? 'Hostel Group',
                  inviteCode: group['inviteCode'] as String? ?? '',
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NoGroupView extends StatelessWidget {
  const _NoGroupView({
    required this.name,
    required this.email,
    required this.onCreateGroup,
  });

  final String? name;
  final String? email;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, ${name?.trim().isNotEmpty == true ? name : 'Member'}!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a new group or join an existing one.',
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Join Group is coming next.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Join Group'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupDashboard extends StatelessWidget {
  const _GroupDashboard({
    required this.memberName,
    required this.groupName,
    required this.inviteCode,
  });

  final String? memberName;
  final String groupName;
  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, ${memberName?.trim().isNotEmpty == true ? memberName : 'Member'}!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                const Text('Invitation code'),
                SelectableText(
                  inviteCode,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('Role: Administrator'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.restaurant_outlined),
            title: Text('Meals'),
            subtitle: Text('Daily meal entry will be added next.'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('Expenses'),
            subtitle: Text('Shared expense entry will be added soon.'),
          ),
        ),
      ],
    );
  }
}