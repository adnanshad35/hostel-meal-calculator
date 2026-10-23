import 'package:flutter/material.dart';

import 'expense_screen.dart';
import 'hostel_dashboard_screen.dart';
import 'meal_ledger_screen.dart';
import 'monthly_summary_screen.dart';

/// The hostel on a phone: four tabs in a bar along the bottom, so a
/// member always knows where they are.
///
/// A tab is built the first time it is opened, and kept after that,
/// so switching back is instant and opening the app reads only Home.
class PhoneShell extends StatefulWidget {
  const PhoneShell({
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
  State<PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<PhoneShell> {
  int _index = 0;
  final Set<int> _opened = {0};

  bool get _isAdmin => widget.role == 'admin';

  void _select(int index) {
    setState(() {
      _index = index;
      _opened.add(index);
    });
  }

  Widget _tab(int index) {
    return switch (index) {
      0 => HostelDashboardScreen(
        groupId: widget.groupId,
        groupName: widget.groupName,
        inviteCode: widget.inviteCode,
        memberName: widget.memberName,
        role: widget.role,
        isHome: true,
      ),
      // One page: the member's own meals are picked out in it.
      1 => Scaffold(
        appBar: AppBar(title: const Text('Meals')),
        body: MealLedgerScreen(
          groupId: widget.groupId,
          isAdmin: _isAdmin,
          embedded: true,
        ),
      ),
      // One page: the member's own expenses are picked out in it.
      2 => Scaffold(
        appBar: AppBar(title: const Text('Expenses')),
        body: TotalExpensesScreen(
          groupId: widget.groupId,
          isAdmin: _isAdmin,
          embedded: true,
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Balance')),
        body: MonthlySummaryScreen(
          groupId: widget.groupId,
          isAdmin: _isAdmin,
          embedded: true,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Back on another tab returns to Home before leaving the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var index = 0; index < 4; index++)
              _opened.contains(index) ? _tab(index) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Meals',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Expenses',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Balance',
            ),
          ],
        ),
      ),
    );
  }
}
