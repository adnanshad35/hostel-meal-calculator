import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'expense_screen.dart';
import 'group_settings_screen.dart';
import 'manage_members_screen.dart';
import 'meal_screen.dart';
import 'monthly_summary_screen.dart';

class HostelDashboardScreen
    extends StatelessWidget {
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

  Future<void> _copyInviteCode(
    BuildContext context,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: inviteCode),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invitation code copied.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Dashboard'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            32,
          ),
          children: [
            _HostelHeader(
              groupName: groupName,
              inviteCode: inviteCode,
              isAdmin: isAdmin,
              onCopyCode: () {
                _copyInviteCode(context);
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Management',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
              children: [
                _DashboardTile(
                  icon:
                      Icons.restaurant_outlined,
                  title: 'Meals',
                  color: AppTheme.primary,
                  backgroundColor:
                      const Color(0xFFE4F3EB),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MealScreen(
                          groupId: groupId,
                          isAdmin: isAdmin,
                        ),
                      ),
                    );
                  },
                ),
                _DashboardTile(
                  icon:
                      Icons.receipt_long_outlined,
                  title: 'Expenses',
                  color:
                      const Color(0xFFD78116),
                  backgroundColor:
                      const Color(0xFFFFF1DB),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExpenseScreen(
                          groupId: groupId,
                          isAdmin: isAdmin,
                        ),
                      ),
                    );
                  },
                ),
                _DashboardTile(
                  icon:
                      Icons.calculate_outlined,
                  title: 'Monthly\nCalculation',
                  color:
                      const Color(0xFF4869A4),
                  backgroundColor:
                      const Color(0xFFE8EEF8),
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
                if (isAdmin)
                  _DashboardTile(
                    icon: Icons
                        .manage_accounts_outlined,
                    title: 'Manage\nMembers',
                    color:
                        const Color(0xFF7956A8),
                    backgroundColor:
                        const Color(0xFFF0E9F8),
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
                _DashboardTile(
                  icon:
                      Icons.settings_outlined,
                  title: 'Hostel\nSettings',
                  color:
                      AppTheme.textSecondary,
                  backgroundColor:
                      const Color(0xFFEEF1EF),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HostelHeader extends StatelessWidget {
  const _HostelHeader({
    required this.groupName,
    required this.inviteCode,
    required this.isAdmin,
    required this.onCopyCode,
  });

  final String groupName;
  final String inviteCode;
  final bool isAdmin;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark,
            AppTheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary
                .withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 29,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.14),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAdmin
                          ? Icons
                              .verified_user_outlined
                          : Icons.person_outline,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAdmin
                          ? 'Administrator'
                          : 'Member',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            groupName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(
              15,
              12,
              8,
              12,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.13),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVITATION CODE',
                        style: TextStyle(
                          color: Colors.white
                              .withValues(
                            alpha: 0.66,
                          ),
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        inviteCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy invitation code',
                  onPressed: onCopyCode,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white
                        .withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                  ),
                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 19,
                    color:
                        AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}