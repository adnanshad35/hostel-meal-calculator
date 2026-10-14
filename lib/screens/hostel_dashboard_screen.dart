import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/dashboard_summary.dart';
import '../services/duty_roster.dart';
import '../services/group_member_service.dart';
import '../services/hostel_settings.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/monthly_calculator.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_bell.dart';
import 'expense_screen.dart';
import 'hostel_activation_screen.dart';
import 'hostel_details_screen.dart';
import 'meal_ledger_screen.dart';
import 'meal_screen.dart';
import 'monthly_summary_screen.dart';
import 'profile_screen.dart';

class HostelDashboardScreen extends StatefulWidget {
  const HostelDashboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
    required this.memberName,
    required this.role,
    this.isHome = false,
  });

  final String groupId;
  final String groupName;
  final String inviteCode;
  final String? memberName;
  final String role;

  /// True when this is the first screen a member sees. The app bar
  /// then also carries app notices and the profile.
  final bool isHome;

  @override
  State<HostelDashboardScreen> createState() => _HostelDashboardScreenState();
}

class _HostelDashboardScreenState extends State<HostelDashboardScreen> {
  late final Stream<HostelSettings> _settings = HostelSettingsService.watch(
    widget.groupId,
  );
  late final Stream<DutyRoster> _roster = DutyRosterService.watch(
    widget.groupId,
  );

  String get groupId => widget.groupId;
  bool get isAdmin => widget.role == 'admin';

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openCalculation() {
    _open(MonthlySummaryScreen(groupId: groupId, isAdmin: isAdmin));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHome ? 'HostelMate' : 'Hostel Dashboard'),
        actions: [
          if (widget.isHome) const NotificationBell(),
          NotificationBell(groupId: groupId, isAdmin: isAdmin),
          if (widget.isHome)
            IconButton(
              tooltip: 'Profile',
              onPressed: () => _open(const ProfileScreen()),
              icon: const Icon(Icons.account_circle_outlined, size: 28),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<HostelSettings>(
          stream: _settings,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? const HostelSettings();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _SubscriptionBanner(
                  groupId: groupId,
                  groupName: widget.groupName,
                  isAdmin: isAdmin,
                  // Hidden while the hostel is suspended.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      // Whoever is looking after the hostel today is
                      // named on the top card.
                      StreamBuilder<DutyRoster>(
                        stream: _roster,
                        builder: (context, roster) => _HostelOverview(
                          groupId: groupId,
                          groupName: widget.groupName,
                          isAdmin: isAdmin,
                          responsible: roster.data
                              ?.responsibleOn(DateTime.now())
                              ?.memberName,
                          onOpenCalculation: _openCalculation,
                          onOpenExpenses: () => _open(
                            MyRecordsScreen(groupId: groupId, initialTab: 1),
                          ),
                          onOpenMeals: () =>
                              _open(MyRecordsScreen(groupId: groupId)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _tiles(context, settings),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tiles(BuildContext context, HostelSettings settings) {
    // The + buttons are for whoever may add: always an admin, and a
    // member unless the admins keep that to themselves.
    final canAddMeals = isAdmin || settings.membersCanAddMeals;
    final canAddExpenses = isAdmin || settings.membersCanAddExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A member who may not add meals or expenses does not get
        // that tile at all; an admin always gets both.
        if (canAddMeals || canAddExpenses)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text(
                      'Update',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (canAddMeals)
                        Expanded(
                          child: _AddTile(
                            icon: Icons.restaurant_outlined,
                            title: 'Meals',
                            color: AppTheme.primary,
                            background: AppTheme.surfaceSoft,
                            addTooltip: 'Add meal',
                            onAdd: () => showMealForm(
                              context,
                              groupId: groupId,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                      if (canAddMeals && canAddExpenses)
                        const SizedBox(width: 10),
                      if (canAddExpenses)
                        Expanded(
                          child: _AddTile(
                            icon: Icons.receipt_long_outlined,
                            title: 'Expenses',
                            color: AppTheme.primary,
                            background: AppTheme.surfaceSoft,
                            addTooltip: 'Add expense',
                            onAdd: () => showExpenseForm(
                              context,
                              groupId: groupId,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (canAddMeals || canAddExpenses) const SizedBox(height: 12),
        _LinkRow(
          icon: Icons.groups_outlined,
          title: 'Total Meals & Expenses',
          color: AppTheme.primary,
          backgroundColor: AppTheme.surfaceSoft,
          onTap: () =>
              _open(HostelRecordsScreen(groupId: groupId, isAdmin: isAdmin)),
        ),
        const SizedBox(height: 12),
        _LinkRow(
          icon: Icons.info_outline_rounded,
          title: 'About Hostel',
          color: AppTheme.primary,
          backgroundColor: AppTheme.surfaceSoft,
          onTap: () => _open(
            HostelDetailsScreen(
              groupId: groupId,
              groupName: widget.groupName,
              isAdmin: isAdmin,
            ),
          ),
        ),
      ],
    );
  }
}

/// The signed-in member's own meals and expenses this month, on two
/// tabs.
class MyRecordsScreen extends StatelessWidget {
  const MyRecordsScreen({
    super.key,
    required this.groupId,
    this.initialTab = 0,
  });

  final String groupId;

  /// 0 opens on Meals, 1 on Expenses.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Meals & Expenses'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Meals'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MyMealsScreen(groupId: groupId, currentUserId: uid, embedded: true),
            MyExpensesScreen(
              groupId: groupId,
              currentUserId: uid,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole hostel's meals and expenses this month, on two tabs.
class HostelRecordsScreen extends StatelessWidget {
  const HostelRecordsScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.initialTab = 0,
  });

  final String groupId;
  final bool isAdmin;

  /// 0 opens on the meals, 1 on the expenses.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Total Meals & Expenses'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Meals'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MealLedgerScreen(
              groupId: groupId,
              isAdmin: isAdmin,
              embedded: true,
            ),
            TotalExpensesScreen(
              groupId: groupId,
              isAdmin: isAdmin,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// A short tile for adding an entry. Tapping anywhere on it opens the
/// form; the + only shows what the tile does.
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.background,
    required this.onAdd,
    required this.addTooltip,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color background;
  final VoidCallback onAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                // Shrinks a little on a narrow phone instead of cutting
                // the word short.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: addTooltip,
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(38, 38),
                ),
                icon: const Icon(Icons.add, size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width row that opens a page.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
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
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(
          Icons.arrow_forward_rounded,
          size: 19,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

String _money(double value) {
  final whole = value.round().abs().toString();
  final grouped = StringBuffer();

  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
    grouped.write(whole[index]);
  }

  return '${value < 0 ? '−' : ''}৳$grouped';
}

String _count(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The top of the dashboard: this month's meal rate, cost and meals in
/// one card, and today's lunches and dinners in another.
///
/// It listens only to the current month's meals and expenses, so
/// opening the app does not read the hostel's whole history.
class _HostelOverview extends StatefulWidget {
  const _HostelOverview({
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.responsible,
    required this.onOpenCalculation,
    required this.onOpenExpenses,
    required this.onOpenMeals,
  });

  final String groupId;
  final String groupName;
  final bool isAdmin;

  /// The member responsible for the hostel today, if one is set.
  final String? responsible;
  final VoidCallback onOpenCalculation;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenMeals;

  @override
  State<_HostelOverview> createState() => _HostelOverviewState();
}

class _HostelOverviewState extends State<_HostelOverview> {
  late final DateTime _now = DateTime.now();

  late final Stream<List<GroupMember>> _members;
  late final Stream<List<MemberMealPlan>> _plans;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _meals;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _expenses;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _monthSettings;

  @override
  void initState() {
    super.initState();

    final group = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId);
    final firstDay = DateTime(_now.year, _now.month);
    final nextMonth = DateTime(_now.year, _now.month + 1);

    _members = GroupMemberService.watch(widget.groupId);
    _plans = MealPlanService.watchAll(widget.groupId);
    _meals = group
        .collection('meals')
        .where('dateKey', isGreaterThanOrEqualTo: MealPlans.dateKey(firstDay))
        .where('dateKey', isLessThan: MealPlans.dateKey(nextMonth))
        .snapshots();
    _expenses = group
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThan: Timestamp.fromDate(nextMonth))
        .snapshots();
    _monthSettings = group
        .collection('monthlySettings')
        .doc(MonthlyCalculator.monthKey(_now))
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // Each part is read as it arrives; the figures appear once the
    // meals, expenses and members are all in.
    return StreamBuilder<List<GroupMember>>(
      stream: _members,
      builder: (context, members) {
        return StreamBuilder<List<MemberMealPlan>>(
          stream: _plans,
          builder: (context, plans) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _meals,
              builder: (context, meals) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _expenses,
                  builder: (context, expenses) {
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: _monthSettings,
                      builder: (context, monthSettings) {
                        final isReady =
                            members.hasData &&
                            meals.hasData &&
                            expenses.hasData;
                        final hasError =
                            members.hasError ||
                            meals.hasError ||
                            expenses.hasError;

                        return _cards(
                          isReady && !hasError
                              ? _summarize(
                                  members.data!,
                                  plans.data ?? const [],
                                  meals.data!,
                                  expenses.data!,
                                  monthSettings.data?.data(),
                                )
                              : null,
                          hasError: hasError,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  DashboardSummary _summarize(
    List<GroupMember> members,
    List<MemberMealPlan> plans,
    QuerySnapshot<Map<String, dynamic>> meals,
    QuerySnapshot<Map<String, dynamic>> expenses,
    Map<String, dynamic>? monthSettings,
  ) {
    return DashboardSummary.build(
      now: _now,
      members: [
        for (final member in members)
          CalcMember(id: member.id, name: member.name),
      ],
      meals: [
        for (final meal in meals.docs)
          MealRecord.fromData(meal.id, meal.data()),
      ],
      plans: plans,
      expenses: [
        for (final expense in expenses.docs)
          ExpenseRecord(
            paidById: expense.data()['paidById'] as String?,
            paidByName: expense.data()['paidByName'] as String?,
            date: (expense.data()['date'] as Timestamp?)?.toDate(),
            amount: (expense.data()['amount'] as num?)?.toDouble() ?? 0,
          ),
      ],
      minimumMeals: (monthSettings?['minimumMeals'] as num?)?.toDouble() ?? 0,
      shopDue: (monthSettings?['shopDue'] as num?)?.toDouble() ?? 0,
      memberId: FirebaseAuth.instance.currentUser?.uid,
    );
  }

  /// [summary] is null while loading, or when it could not be loaded.
  Widget _cards(DashboardSummary? summary, {required bool hasError}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(
          groupName: widget.groupName,
          summary: summary,
          hasError: hasError,
          onOpenCalculation: widget.onOpenCalculation,
          onOpenExpenses: widget.onOpenExpenses,
          onOpenMeals: widget.onOpenMeals,
        ),
        const SizedBox(height: 12),
        _TodayCard(now: _now, summary: summary, onDuty: widget.responsible),
      ],
    );
  }
}

/// The large card: the hostel, its meal rate, and the member's own
/// expense and meals. Only the Details button and the two figures
/// open anything; the card itself does not.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.groupName,
    required this.summary,
    required this.hasError,
    required this.onOpenCalculation,
    required this.onOpenExpenses,
    required this.onOpenMeals,
  });

  final String groupName;
  final DashboardSummary? summary;
  final bool hasError;
  final VoidCallback onOpenCalculation;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenMeals;

  /// One figure in its own box. Tapping it opens the list behind it.
  Widget _figure(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final rate = summary == null
        ? '—'
        : '৳${summary.mealRate.toStringAsFixed(2)}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppTheme.heroGradient,
        boxShadow: AppTheme.heroShadow,
      ),
      child: Stack(
        children: [
          // Soft shapes that give the card some depth.
          const Positioned(
            top: -46,
            right: -30,
            child: _Glow(size: 170, opacity: 0.08),
          ),
          const Positioned(
            bottom: -70,
            left: -40,
            child: _Glow(size: 190, opacity: 0.06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'MEAL RATE',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: onOpenCalculation,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(14, 7, 8, 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: AppTheme.ink,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'This month could not be loaded.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _figure(
                      'My expense',
                      summary == null ? '—' : _money(summary.myExpense),
                      Icons.payments_outlined,
                      onOpenExpenses,
                    ),
                    const SizedBox(width: 10),
                    _figure(
                      'My meals',
                      summary == null ? '—' : _count(summary.myMeals),
                      Icons.restaurant_outlined,
                      onOpenMeals,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Today at a glance: how many lunches and dinners the hostel needs,
/// and which member is on duty.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.now,
    required this.summary,
    required this.onDuty,
  });

  final DateTime now;
  final DashboardSummary? summary;

  /// The member responsible for the hostel today, if one is set.
  final String? onDuty;

  /// Lists who is having lunch (or dinner) today, and how many each.
  void _showWho(
    BuildContext context, {
    required String label,
    required bool isDinner,
  }) {
    final eating = [
      for (final member in summary?.todayMembers ?? const <TodayMeal>[])
        if ((isDinner ? member.dinner : member.lunch) > 0) member,
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  'Today\'s $label',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (eating.isEmpty)
                  const Text('Nobody yet.')
                else
                  for (final member in eating)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _count(isDinner ? member.dinner : member.lunch),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Lunch or dinner: its icon and name, with the count on the right.
  Widget _meal({
    required String label,
    required double? count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                count == null ? '—' : _count(count),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = '${now.day} ${_monthNames[now.month - 1].substring(0, 3)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'For today',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Meals on the left, whoever is on duty on the right, the
            // same height.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _meal(
                          label: 'Lunch',
                          count: summary?.todayLunch,
                          icon: Icons.lunch_dining_outlined,
                          onTap: () => _showWho(
                            context,
                            label: 'Lunch',
                            isDinner: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _meal(
                          label: 'Dinner',
                          count: summary?.todayDinner,
                          icon: Icons.dinner_dining_outlined,
                          onTap: () => _showWho(
                            context,
                            label: 'Dinner',
                            isDinner: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.assignment_ind_outlined,
                            color: AppTheme.accentDeep,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'On duty',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            onDuty ?? '—',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Shows whether the hostel is active, and lets an admin activate or
/// extend it.
class _SubscriptionBanner extends StatefulWidget {
  const _SubscriptionBanner({
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.child,
  });

  final String groupId;
  final String groupName;
  final bool isAdmin;

  /// The hostel's content, shown below the status card.
  final Widget child;

  @override
  State<_SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends State<_SubscriptionBanner> {
  late final Stream<HostelSubscription> _stream;

  @override
  void initState() {
    super.initState();
    _stream = SubscriptionService.watch(widget.groupId);
  }

  void _openActivation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostelActivationScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HostelSubscription>(
      stream: _stream,
      builder: (context, snapshot) {
        final subscription = snapshot.data ?? const HostelSubscription.none();
        final isLoading = !snapshot.hasData && !snapshot.hasError;
        final isActive = subscription.isActive(DateTime.now());
        final isSuspended = subscription.accessDisabled;

        final canEdit = subscription.canEdit(DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // While the hostel can be edited there is nothing to say
            // here; its remaining days are shown in Hostel Details.
            if (!isLoading && !canEdit) ...[
              const SizedBox(height: 12),
              SubscriptionStatusCard(
                subscription: subscription,
                action: widget.isAdmin && !isSuspended
                    ? FilledButton(
                        onPressed: _openActivation,
                        child: Text(isActive ? 'Extend' : 'Activate'),
                      )
                    : null,
              ),
            ],
            if (!isLoading && !isActive && !isSuspended && !widget.isAdmin)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Ask your hostel admin to activate it.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (!isSuspended) widget.child,
          ],
        );
      },
    );
  }
}
