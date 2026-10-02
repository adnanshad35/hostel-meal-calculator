import 'package:flutter/material.dart';

import 'expense_screen.dart';
import 'group_settings_screen.dart';
import 'manage_members_screen.dart';
import 'meal_screen.dart';
import 'monthly_summary_screen.dart';

class HostelDashboardScreen extends StatelessWidget {
  const HostelDashboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
    required this.memberName,
    required this.role,
  });

  final String groupId;
  final String groupName;
  final String inviteCode;
  final String? memberName;
  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final roleLabel =
        isAdmin ? 'Administrator' : 'Member';

    final displayName =
        memberName?.trim().isNotEmpty == true
            ? memberName!.trim()
            : 'Member';

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hello, $displayName!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.apartment_outlined,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            groupName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Invitation code'),
                    SelectableText(
                      inviteCode,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color:
                                const Color(0xFF2E7D32),
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
                leading: const Icon(
                  Icons.restaurant_outlined,
                ),
                title: const Text('Meals'),
                subtitle: const Text(
                  'Enter and view daily meals.',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MealScreen(
                        groupId: groupId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.receipt_long_outlined,
                ),
                title: const Text('Expenses'),
                subtitle: const Text(
                  'Add and view shared expenses.',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpenseScreen(
                        groupId: groupId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.calculate_outlined,
                ),
                title:
                    const Text('Monthly Calculation'),
                subtitle: const Text(
                  'View meal rate, expenses, and balances.',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MonthlySummaryScreen(
                        groupId: groupId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isAdmin)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.manage_accounts_outlined,
                  ),
                  title:
                      const Text('Manage Members'),
                  subtitle: const Text(
                    'Manage members and administrator roles.',
                  ),
                  trailing:
                      const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ManageMembersScreen(
                          groupId: groupId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.settings_outlined),
                title: const Text('Group Settings'),
                subtitle: const Text(
                  'Manage your hostel membership and settings.',
                ),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupSettingsScreen(
                        groupId: groupId,
                        groupName: groupName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}