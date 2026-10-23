import 'package:flutter/material.dart';

import '../widgets/desktop_scaffold.dart';
import '../widgets/notification_bell.dart';
import 'expense_screen.dart';
import 'hostel_dashboard_screen.dart';
import 'hostel_details_screen.dart';
import 'meal_screen.dart';
import 'monthly_summary_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

enum _Section {
  overview('Overview', Icons.dashboard_outlined),
  meals('Meals', Icons.restaurant_outlined),
  expenses('Expenses', Icons.receipt_long_outlined),
  calculation('Balance', Icons.account_balance_wallet_outlined),
  details('Hostel Details', Icons.apartment_outlined),
  notifications('Notifications', Icons.notifications_outlined),
  profile('Profile', Icons.account_circle_outlined);

  const _Section(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The hostel on a wide browser window: navigation in a sidebar on the
/// left, and the chosen screen beside it.
///
/// The screens themselves are the same ones the phone uses. Each
/// section has its own navigator, so opening something from a screen
/// (the meal ledger, for example) stays inside the content area.
class DesktopShell extends StatefulWidget {
  const DesktopShell({
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
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  _Section _section = _Section.overview;

  /// Increased to rebuild a section from its first screen when its
  /// sidebar item is chosen again.
  int _visit = 0;

  bool get _isAdmin => widget.role == 'admin';

  Widget _screenFor(_Section section) {
    return switch (section) {
      _Section.overview => HostelDashboardScreen(
        groupId: widget.groupId,
        groupName: widget.groupName,
        inviteCode: widget.inviteCode,
        memberName: widget.memberName,
        role: widget.role,
      ),
      _Section.meals => MealScreen(groupId: widget.groupId, isAdmin: _isAdmin),
      _Section.expenses => ExpenseScreen(
        groupId: widget.groupId,
        isAdmin: _isAdmin,
      ),
      _Section.calculation => MonthlySummaryScreen(
        groupId: widget.groupId,
        isAdmin: _isAdmin,
      ),
      _Section.details => HostelDetailsScreen(
        groupId: widget.groupId,
        groupName: widget.groupName,
        isAdmin: _isAdmin,
      ),
      _Section.notifications => NotificationsScreen(
        groupId: widget.groupId,
        isAdmin: _isAdmin,
      ),
      _Section.profile => const ProfileScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      title: widget.groupName,
      subtitle: _isAdmin ? 'Administrator' : 'Member',
      // App notices, with their own unread badge.
      headerAction: const NotificationBell(),
      actions: Row(
        children: [
          Expanded(
            child: DesktopSidebarButton(
              label: 'Meal',
              onPressed: () => showMealForm(
                context,
                groupId: widget.groupId,
                isAdmin: _isAdmin,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DesktopSidebarButton(
              label: 'Expense',
              onPressed: () => showExpenseForm(
                context,
                groupId: widget.groupId,
                isAdmin: _isAdmin,
              ),
            ),
          ),
        ],
      ),
      destinations: [
        for (final section in _Section.values)
          DesktopDestination(label: section.label, icon: section.icon),
      ],
      selectedIndex: _section.index,
      onSelect: (index) {
        setState(() {
          _section = _Section.values[index];
          _visit++;
        });
      },
      content: Navigator(
        key: ValueKey('${_section.name}-$_visit'),
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _screenFor(_section),
          );
        },
      ),
    );
  }
}
