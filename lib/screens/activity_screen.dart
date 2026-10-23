import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/activity_log.dart';
import '../theme/app_theme.dart';

/// Which records the page shows.
enum _Filter {
  meals('Meals'),
  expenses('Expenses'),
  admin('Admin'),
  all('All');

  const _Filter(this.label);

  final String label;

  bool shows(ActivityKind kind) => switch (this) {
    _Filter.all => true,
    _Filter.meals =>
      kind == ActivityKind.mealAdded ||
          kind == ActivityKind.mealChanged ||
          kind == ActivityKind.mealPlanChanged,
    _Filter.expenses =>
      kind == ActivityKind.expenseAdded ||
          kind == ActivityKind.expenseChanged ||
          kind == ActivityKind.expenseDeleted,
    // Everything only an admin, or HostelMate, can do.
    _Filter.admin =>
      !_Filter.meals.shows(kind) && !_Filter.expenses.shows(kind),
  };
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Accountability: every change to the hostel's meals, expenses and
/// everything admins do, newest first, so every member can see who
/// did what.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _pageSize = 50;

  int _limit = _pageSize;
  _Filter _filter = _Filter.all;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _watch();

  @override
  void initState() {
    super.initState();
    // Opening the history clears its dot in Hostel Details.
    ActivityLog.markSeen(widget.groupId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watch() =>
      ActivityLog.newest(widget.groupId, limit: _limit).snapshots();

  void _loadMore() {
    setState(() {
      _limit += _pageSize;
      _stream = _watch();
    });
  }

  /// "Today", "Yesterday" or "20 Oct".
  static String _dayHeading(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    return '${date.day} ${_months[date.month - 1]}'
        '${date.year == now.year ? '' : ' ${date.year}'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accountability')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              children: [
                for (final filter in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load the history.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final activities = [
                  for (final doc in docs)
                    if (Activity.fromData(doc.data()) case final activity?)
                      if (_filter.shows(activity.kind)) activity,
                ];
                final hasMore = docs.length >= _limit;

                if (activities.isEmpty && !hasMore) {
                  return const Center(
                    child: Text(
                      'No Activity Yet',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final rows = <Widget>[];
                String? heading;
                for (final activity in activities) {
                  final day = _dayHeading(activity.at ?? DateTime.now());
                  if (day != heading) {
                    heading = day;
                    rows.add(_DayHeading(day));
                  }
                  rows.add(_ActivityRow(activity: activity));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    ...rows,
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: _loadMore,
                            child: const Text('Load More'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.accentDeep,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// One change: what happened, the figures, the day it was for and the
/// time it was made.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final Activity activity;

  IconData get _icon => switch (activity.kind) {
    ActivityKind.mealAdded ||
    ActivityKind.mealChanged => Icons.restaurant_outlined,
    ActivityKind.mealPlanChanged => Icons.event_repeat_outlined,
    ActivityKind.expenseAdded ||
    ActivityKind.expenseChanged => Icons.receipt_long_outlined,
    ActivityKind.expenseDeleted => Icons.delete_outline,
    ActivityKind.minMealsSet || ActivityKind.shopDueSet => Icons.tune_rounded,
    ActivityKind.monthReset => Icons.restart_alt,
    ActivityKind.memberRemoved => Icons.person_remove_outlined,
    ActivityKind.adminMade ||
    ActivityKind.adminRemoved => Icons.admin_panel_settings_outlined,
    ActivityKind.hostelActivated ||
    ActivityKind.activationSet => Icons.verified_outlined,
    ActivityKind.paymentSent => Icons.payments_outlined,
  };

  /// The day the change was for, such as "For 20 Oct", when it was for
  /// a day.
  String? get _forDay {
    final parts = activity.day.split('-');
    if (parts.length != 3) return null;

    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) return null;
    return 'For $day ${_months[month - 1]}';
  }

  String get _time {
    final at = activity.at;
    if (at == null) return 'Saving…';

    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    // Green for added, gold for changed, red for deleted or removed.
    final color = switch (activity.tone) {
      ActivityTone.added => AppTheme.primary,
      ActivityTone.changed => AppTheme.accentDeep,
      ActivityTone.removed => AppTheme.danger,
    };
    final (who, verb, what) = activity.parts;
    final meta = [?_forDay, _time].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$who '),
                        TextSpan(
                          text: verb,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: ' $what'),
                      ],
                    ),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (activity.details.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      activity.details,
                      style: TextStyle(
                        color: activity.tone == ActivityTone.removed
                            ? AppTheme.danger
                            : AppTheme.primaryDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
