import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/notification_bell.dart';
import '../widgets/web_layout.dart';
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
  calculation('Monthly Calculation', Icons.calculate_outlined),
  details('Hostel Details', Icons.info_outline_rounded),
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
  static const double _contentWidth = 860;

  _Section _section = _Section.overview;

  /// Increased to rebuild a section from its first screen when its
  /// sidebar item is chosen again.
  int _visit = 0;

  bool get _isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    // After this frame, because the frame around the app is already
    // being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebLayout.shellActive.value = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebLayout.shellActive.value = false;
    });
    super.dispose();
  }

  void _open(_Section section) {
    setState(() {
      _section = section;
      _visit++;
    });
  }

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
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE9EFEB),
      body: Row(
        children: [
          _Sidebar(
            groupId: widget.groupId,
            groupName: widget.groupName,
            isAdmin: _isAdmin,
            selected: _section,
            onSelect: _open,
          ),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: _contentWidth),
                margin: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDDE5E0)),
                ),
                // Screens measure themselves against the content area,
                // not the whole window.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return MediaQuery(
                      data: media.copyWith(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                      ),
                      child: Navigator(
                        key: ValueKey('${_section.name}-$_visit'),
                        onGenerateRoute: (settings) {
                          return MaterialPageRoute<void>(
                            settings: settings,
                            builder: (_) => _screenFor(_section),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.selected,
    required this.onSelect,
  });

  final String groupId;
  final String groupName;
  final bool isAdmin;
  final _Section selected;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B3D2C), Color(0xFF0A2F22)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 12, 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'HostelMate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // App notices, with their own unread badge.
                  const IconTheme(
                    data: IconThemeData(color: Colors.white),
                    child: NotificationBell(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isAdmin ? 'Administrator' : 'Member',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickButton(
                      label: 'Meal',
                      onPressed: () => showMealForm(
                        context,
                        groupId: groupId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickButton(
                      label: 'Expense',
                      onPressed: () => showExpenseForm(
                        context,
                        groupId: groupId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 16,
              indent: 22,
              endIndent: 22,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final section in _Section.values)
                    _NavItem(
                      section: section,
                      isSelected: section == selected,
                      onTap: () => onSelect(section),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final _Section section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(section.icon, size: 21, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
