import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_group_screen.dart';
import 'join_group_screen.dart';
import 'meal_screen.dart';
import 'expense_screen.dart';
import 'monthly_summary_screen.dart';
import 'manage_members_screen.dart';

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
            final role = userData?['role'] as String? ?? 'member';

            if (groupId == null || groupId.isEmpty) {
              return _NoGroupView(
                name: user.displayName,
                email: user.email,
                onCreateGroup: () => _openCreateGroup(context),
                onJoinGroup: () => _openJoinGroup(context),
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

                if (groupSnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load the hostel group.'),
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
                  groupId: groupId,
                  memberName: user.displayName,
                  groupName: group['name'] as String? ?? 'Hostel Group',
                  inviteCode: group['inviteCode'] as String? ?? '',
                  role: role,
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
    required this.onJoinGroup,
  });

  final String? name;
  final String? email;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

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
                  onPressed: onJoinGroup,
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
    required this.groupId,
    required this.memberName,
    required this.groupName,
    required this.inviteCode,
    required this.role,
  });

  final String groupId;
  final String? memberName;
  final String groupName;
  final String inviteCode;
  final String role;

  @override
  Widget build(BuildContext context) {
    final roleLabel = role == 'admin' ? 'Administrator' : 'Member';

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
                Text('Role: $roleLabel'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant_outlined),
            title: const Text('Meals'),
            subtitle: const Text('Enter and update your daily meals.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MealScreen(
  groupId: groupId,
  isAdmin: role == 'admin',
),
                ),
              );
            },
          ),
        ),
        
        
        Card(
  child: ListTile(
    leading: const Icon(Icons.receipt_long_outlined),
    title: const Text('Expenses'),
    subtitle: const Text('Add and view shared expenses.'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseScreen(
            groupId: groupId,
            isAdmin: role == 'admin',
          ),
        ),
      );
    },
  ),
),
Card(
  child: ListTile(
    leading: const Icon(Icons.calculate_outlined),
    title: const Text('Monthly Calculation'),
    subtitle: const Text(
      'View meal rate, expenses, and member balances.',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MonthlySummaryScreen(
            groupId: groupId,
            isAdmin: role == 'admin',
          ),
        ),
      );
    },
  ),
),
if (role == 'admin')
  Card(
    child: ListTile(
      leading: const Icon(
        Icons.manage_accounts_outlined,
      ),
      title: const Text('Manage Members'),
      subtitle: const Text(
        'Promote members and manage administrator roles.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ManageMembersScreen(
              groupId: groupId,
            ),
          ),
        );
      },
    ),
  ),
      ],
    );
  }
}