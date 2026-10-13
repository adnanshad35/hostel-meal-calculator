import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/subscription_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_bell.dart';
import 'hostel_activation_screen.dart';
import 'expense_screen.dart';
import 'hostel_details_screen.dart';
import 'meal_screen.dart';
import 'monthly_summary_screen.dart';
import 'profile_screen.dart';

class HostelDashboardScreen extends StatelessWidget {
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

  Future<void> _copyInviteCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invitation code copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isHome ? 'HostelMate' : 'Hostel Dashboard'),
        actions: [
          if (isHome) const NotificationBell(),
          NotificationBell(groupId: groupId, isAdmin: isAdmin),
          if (isHome)
            IconButton(
              tooltip: 'Profile',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              icon: const Icon(Icons.account_circle_outlined, size: 28),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _HostelHeader(
              groupName: groupName,
              inviteCode: inviteCode,
              isAdmin: isAdmin,
              onCopyCode: () {
                _copyInviteCode(context);
              },
            ),
            _SubscriptionBanner(
              groupId: groupId,
              groupName: groupName,
              isAdmin: isAdmin,
              // Hidden while the hostel is suspended.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _DashboardTile(
                        icon: Icons.restaurant_outlined,
                        title: 'Meals',
                        subtitle: _TodayMealText(groupId: groupId),
                        color: AppTheme.primary,
                        backgroundColor: const Color(0xFFE4F3EB),
                        addTooltip: 'Add meal',
                        onAdd: () => showMealForm(
                          context,
                          groupId: groupId,
                          isAdmin: isAdmin,
                        ),
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
                      _DashboardTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Expenses',
                        color: const Color(0xFFD78116),
                        backgroundColor: const Color(0xFFFFF1DB),
                        addTooltip: 'Add expense',
                        onAdd: () => showExpenseForm(
                          context,
                          groupId: groupId,
                          isAdmin: isAdmin,
                        ),
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
                      _DashboardTile(
                        icon: Icons.calculate_outlined,
                        title: 'Monthly\nCalculation',
                        color: const Color(0xFF4869A4),
                        backgroundColor: const Color(0xFFE8EEF8),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MonthlySummaryScreen(
                                groupId: groupId,
                                isAdmin: isAdmin,
                              ),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Hostel\nDetails',
                        color: const Color(0xFF7956A8),
                        backgroundColor: const Color(0xFFF0E9F8),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HostelDetailsScreen(
                                groupId: groupId,
                                groupName: groupName,
                                isAdmin: isAdmin,
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
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin ? 'Administrator' : 'Member',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Invitation code: tap to copy.
          Material(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onCopyCode,
              child: Tooltip(
                message: 'Copy invitation code',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CODE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.66),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            inviteCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.copy_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
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
    this.subtitle,
    this.onAdd,
    this.addTooltip,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  /// A single line under the title.
  final Widget? subtitle;

  /// When set, a + button in the corner adds a record directly, while
  /// tapping the rest of the card opens the full screen.
  final VoidCallback? onAdd;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 23),
                  ),
                  const Spacer(),
                  if (onAdd != null)
                    IconButton.filled(
                      tooltip: addTooltip,
                      onPressed: onAdd,
                      style: IconButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(40, 40),
                      ),
                      icon: const Icon(Icons.add, size: 22),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                        ?subtitle,
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: AppTheme.textSecondary,
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

/// The signed-in member's meals for today, in one short line.
class _TodayMealText extends StatefulWidget {
  const _TodayMealText({required this.groupId});

  final String groupId;

  @override
  State<_TodayMealText> createState() => _TodayMealTextState();
}

class _TodayMealTextState extends State<_TodayMealText> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _todayEntry;
  late final Stream<MemberMealPlan> _plan;
  late final String _todayKey;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _todayKey = MealPlans.dateKey(now);
    _plan = MealPlanService.watch(widget.groupId, uid);

    // A single document: this member's own entry for today.
    _todayEntry = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('meals')
        .doc('${uid}_${now.year}-$month-$day')
        .snapshots();
  }

  static String _quantity(num? value) {
    final number = (value ?? 0).toDouble();
    return number % 1 == 0
        ? number.toInt().toString()
        : number.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MemberMealPlan>(
      stream: _plan,
      builder: (context, planSnapshot) {
        final rules = planSnapshot.data?.rules ?? const <MealPlanRule>[];
        return _buildText(MealPlans.forDay(rules, _todayKey));
      },
    );
  }

  /// [planned] is what the member's meal plan counts today when they
  /// have added no entry.
  Widget _buildText(PlannedMeals? planned) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _todayEntry,
      builder: (context, snapshot) {
        final entry = snapshot.data?.data();

        final String text;
        if (!snapshot.hasData) {
          text = '';
        } else if (entry == null && planned != null) {
          text = 'Today: ${_quantity(planned.total)} (plan)';
        } else if (entry == null) {
          text = 'Today: not entered';
        } else {
          final total =
              ((entry['lunch'] as num?) ?? 0) +
              ((entry['dinner'] as num?) ?? 0);
          text = 'Today: ${_quantity(total)}';
        }

        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: entry == null && planned == null
                ? AppTheme.warning
                : AppTheme.success,
          ),
        );
      },
    );
  }
}
