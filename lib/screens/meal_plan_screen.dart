import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meal_counter.dart';

/// Where a member chooses what to count on days they add no meal
/// entry: their everyday meals, and periods that differ, such as a
/// trip. Admins can set this for any member.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    this.embedded = false,
  });

  final String groupId;
  final bool isAdmin;

  /// True when shown inside another page, which has the title.
  final bool embedded;

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  Stream<List<GroupMember>>? _membersStream;
  late Stream<MemberMealPlan> _planStream;
  late String _memberId;

  /// Names from the member list, for plans saved by an admin.
  Map<String, String> _memberNames = const {};

  bool _isSaving = false;

  User get _user => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _memberId = _user.uid;
    _planStream = MealPlanService.watch(widget.groupId, _memberId);

    if (widget.isAdmin) {
      _membersStream = GroupMemberService.watch(widget.groupId);
    }
  }

  void _selectMember(String? memberId) {
    if (memberId == null || memberId == _memberId) return;

    setState(() {
      _memberId = memberId;
      _planStream = MealPlanService.watch(widget.groupId, memberId);
    });
  }

  String get _memberName {
    final listed = _memberNames[_memberId];
    if (listed != null) return listed;

    final ownName = _user.displayName?.trim() ?? '';
    return ownName.isEmpty ? 'Member' : ownName;
  }

  /// Returns true once the plan is saved.
  Future<bool> _save(List<MealPlanRule> rules, String message) async {
    if (!await ensureHostelEditable(context, widget.groupId)) return false;
    if (!mounted) return false;
    // A meal plan is a way of entering meals, so the same setting
    // decides whether a member may change one.
    if (!await ensureMemberMayAdd(context, widget.groupId, meals: true)) {
      return false;
    }
    if (!mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);

    try {
      await MealPlanService.save(
        groupId: widget.groupId,
        memberId: _memberId,
        memberName: _memberName,
        rules: rules,
      );

      messenger.showSnackBar(SnackBar(content: Text(message)));
      return true;
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save the meal plan.'),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Members plan from today on. Admins may also correct earlier days
  /// of the current month.
  DateTime get _earliestDate {
    final now = DateTime.now();

    return widget.isAdmin
        ? DateTime(now.year, now.month)
        : DateTime(now.year, now.month, now.day);
  }

  Future<void> _changeEveryday(MemberMealPlan plan) async {
    final today = MealPlans.dateKey(DateTime.now());
    final current = MealPlans.standingOn(plan.rules, today);

    final rule = await showDialog<MealPlanRule>(
      context: context,
      builder: (_) => _EverydayDialog(
        lunch: current?.lunch ?? 1,
        dinner: current?.dinner ?? 1,
        earliestDate: _earliestDate,
      ),
    );

    if (rule == null || !mounted) return;

    await _save(
      MealPlans.withStanding(
        plan.rules,
        lunch: rule.lunch,
        dinner: rule.dinner,
        fromDate: rule.fromDate,
      ),
      'Everyday meals saved.',
    );
  }

  Future<void> _addPeriod(MemberMealPlan plan) async {
    final result = await showDialog<({MealPlanRule rule, bool announce})>(
      context: context,
      builder: (_) => _PeriodDialog(earliestDate: _earliestDate),
    );

    if (result == null || !mounted) return;

    final rule = result.rule;
    final name = _memberName;
    final saved = await _save([...plan.rules, rule], 'Period saved.');

    if (saved && result.announce) {
      await NotificationService.notifyGroup(
        groupId: widget.groupId,
        type: 'mealPlan',
        title: 'Meal Plan of $name',
        message:
            '${_periodText(rule)}: '
            '${rule.lunch == 0 && rule.dinner == 0 ? 'Away' : '${_describeMeals(rule.lunch, rule.dinner)} each day'}',
      );
    }
  }

  /// Removes a period that has not started, or stops one that has.
  Future<bool> _removePeriod(MemberMealPlan plan, MealPlanRule rule) {
    final now = DateTime.now();
    final today = MealPlans.dateKey(now);
    final hasStarted = rule.fromDate.compareTo(today) < 0;

    if (!hasStarted || widget.isAdmin) {
      return _save([
        for (final existing in plan.rules)
          if (!identical(existing, rule)) existing,
      ], 'Period removed.');
    }

    final yesterday = MealPlans.dateKey(
      DateTime(now.year, now.month, now.day - 1),
    );

    return _save(
      MealPlans.withRuleEnded(plan.rules, rule, yesterday),
      'Period ended. Today is counted from your everyday meals.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<List<GroupMember>>(
      stream: _membersStream,
      builder: (context, membersSnapshot) {
        final members = membersSnapshot.data ?? const <GroupMember>[];
        _memberNames = {for (final member in members) member.id: member.name};

        return StreamBuilder<MemberMealPlan>(
          stream: _planStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Unable to load the meal plan.')),
              );
            }

            final plan = snapshot.data;
            if (plan == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return _buildPlan(context, plan, members);
          },
        );
      },
    );

    // Inside another page, only the content: it takes the height it
    // needs and scrolls with that page.
    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Plan')),
      body: SafeArea(child: content),
    );
  }

  Widget _buildPlan(
    BuildContext context,
    MemberMealPlan plan,
    List<GroupMember> members,
  ) {
    final now = DateTime.now();
    final today = MealPlans.dateKey(now);
    final monthStart = MealPlans.dateKey(DateTime(now.year, now.month));

    final current = MealPlans.standingOn(plan.rules, today);
    final upcoming = plan.rules
        .where(
          (rule) =>
              rule.isStanding &&
              rule.toDate == null &&
              rule.fromDate.compareTo(today) > 0,
        )
        .firstOrNull;

    final periods = plan.rules.where((rule) {
      return !rule.isStanding &&
          (rule.toDate ?? today).compareTo(
                widget.isAdmin ? monthStart : today,
              ) >=
              0;
    }).toList()..sort((a, b) => a.fromDate.compareTo(b.fromDate));

    final children = <Widget>[
      if (widget.isAdmin && members.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          key: ValueKey(members.map((member) => member.id).join(',')),
          initialValue: members.any((member) => member.id == _memberId)
              ? _memberId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Member',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: [
            for (final member in members)
              DropdownMenuItem<String>(
                value: member.id,
                child: Text(
                  member.id == _user.uid ? '${member.name} (You)' : member.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _isSaving ? null : _selectMember,
        ),
        const SizedBox(height: 12),
      ],
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(
                icon: Icons.event_repeat_outlined,
                text: 'Every Day',
              ),
              const SizedBox(height: 10),
              Text(
                current == null
                    ? 'Not set'
                    : _describeMeals(current.lunch, current.dinner),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (current != null) ...[
                const SizedBox(height: 2),
                Text('Since ${_dateLabel(current.fromDate)}'),
              ],
              if (upcoming != null) ...[
                const SizedBox(height: 6),
                Text(
                  'From ${_dateLabel(upcoming.fromDate)}: '
                  '${_describeMeals(upcoming.lunch, upcoming.dinner)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _isSaving ? null : () => _changeEveryday(plan),
                  child: Text(current == null ? 'Set' : 'Change'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(
                icon: Icons.luggage_outlined,
                text: 'Away or Different Days',
              ),
              const SizedBox(height: 6),
              if (periods.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Nothing planned.'),
                )
              else
                for (final period in periods)
                  _PeriodRow(
                    rule: period,
                    hasStarted: period.fromDate.compareTo(today) < 0,
                    canRemoveOutright: widget.isAdmin,
                    onRemove: _isSaving
                        ? null
                        : () => _removePeriod(plan, period),
                  ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : () => _addPeriod(plan),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Period'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: children,
    );
  }
}

String _describeMeals(double lunch, double dinner) {
  if (lunch == 0 && dinner == 0) return 'No meals';

  return '${MealCounter.format(lunch)} lunch · '
      '${MealCounter.format(dinner)} dinner';
}

/// A period's first and last meal, such as "16 Oct lunch → 18 Oct
/// dinner".
String _periodText(MealPlanRule rule) {
  final end = rule.toDate ?? rule.fromDate;

  return '${_dateLabel(rule.fromDate)} '
      '${rule.startsAtDinner ? 'dinner' : 'lunch'} → '
      '${_dateLabel(end)} '
      '${rule.endsAfterLunch ? 'lunch' : 'dinner'}';
}

String _dateLabel(String dateKey) {
  const months = [
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

  final date = MealPlans.dateOf(dateKey);
  final label = '${date.day} ${months[date.month - 1]}';

  return date.year == DateTime.now().year ? label : '$label ${date.year}';
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.rule,
    required this.hasStarted,
    required this.canRemoveOutright,
    required this.onRemove,
  });

  final MealPlanRule rule;
  final bool hasStarted;
  final bool canRemoveOutright;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ends = !hasStarted || canRemoveOutright;

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodText(rule),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  rule.lunch == 0 && rule.dinner == 0
                      ? 'No meals counted'
                      : '${_describeMeals(rule.lunch, rule.dinner)} each day',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        if (ends)
          IconButton(
            tooltip: 'Remove this period',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          )
        else
          TextButton(onPressed: onRemove, child: const Text('End Now')),
      ],
    );
  }
}

/// A date line with a Change button, used by both dialogs.
class _DateLine extends StatelessWidget {
  const _DateLine({
    required this.label,
    required this.date,
    required this.onChange,
  });

  final String label;
  final DateTime date;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(_dateLabel(MealPlans.dateKey(date))),
      trailing: TextButton(onPressed: onChange, child: const Text('Change')),
    );
  }
}

Future<DateTime?> _pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime earliest,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(earliest) ? earliest : initial,
    firstDate: earliest,
    lastDate: DateTime(earliest.year + 1, earliest.month, earliest.day),
  );
}

// ─────────────────────────────────────────────────────────────
// Everyday meals
// ─────────────────────────────────────────────────────────────
class _EverydayDialog extends StatefulWidget {
  const _EverydayDialog({
    required this.lunch,
    required this.dinner,
    required this.earliestDate,
  });

  final double lunch;
  final double dinner;
  final DateTime earliestDate;

  @override
  State<_EverydayDialog> createState() => _EverydayDialogState();
}

class _EverydayDialogState extends State<_EverydayDialog> {
  late double _lunch = widget.lunch;
  late double _dinner = widget.dinner;
  late DateTime _from;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
  }

  Future<void> _changeDate() async {
    final picked = await _pickDate(
      context,
      initial: _from,
      earliest: widget.earliestDate,
    );

    if (picked != null && mounted) setState(() => _from = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Everyday Meals'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MealCounter(
              title: 'Lunch',
              icon: Icons.lunch_dining_outlined,
              value: _lunch,
              onChanged: (value) => setState(() => _lunch = value),
            ),
            const SizedBox(height: 8),
            MealCounter(
              title: 'Dinner',
              icon: Icons.dinner_dining_outlined,
              value: _dinner,
              onChanged: (value) => setState(() => _dinner = value),
            ),
            _DateLine(label: 'Starting', date: _from, onChange: _changeDate),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              MealPlanRule(
                lunch: _lunch,
                dinner: _dinner,
                fromDate: MealPlans.dateKey(_from),
                isStanding: true,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// A period that differs from the everyday meals
// ─────────────────────────────────────────────────────────────
class _PeriodDialog extends StatefulWidget {
  const _PeriodDialog({required this.earliestDate});

  final DateTime earliestDate;

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late DateTime _from;
  late DateTime _to;
  bool _startsAtDinner = false;
  bool _endsAfterLunch = false;
  double _lunch = 0;
  double _dinner = 0;
  bool _announce = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = _from;
  }

  /// A period that starts at dinner and ends after lunch on the same
  /// day would cover nothing.
  bool get _isEmpty {
    return _to.isBefore(_from) ||
        (_to == _from && _startsAtDinner && _endsAfterLunch);
  }

  Future<void> _changeFrom() async {
    final picked = await _pickDate(
      context,
      initial: _from,
      earliest: widget.earliestDate,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _from = picked;
      if (_to.isBefore(picked)) _to = picked;
    });
  }

  Future<void> _changeTo() async {
    final picked = await _pickDate(context, initial: _to, earliest: _from);

    if (picked != null && mounted) setState(() => _to = picked);
  }

  /// One end of the period: a calendar icon, the label and date, and
  /// which meal of that day it starts or ends with.
  Widget _end({
    required String label,
    required DateTime date,
    required VoidCallback onPickDate,
    required bool isDinner,
    required ValueChanged<bool> onMealChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 22,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _dateLabel(MealPlans.dateKey(date)),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          segments: const [
            ButtonSegment(value: false, label: Text('Lunch')),
            ButtonSegment(value: true, label: Text('Dinner')),
          ],
          selected: {isDinner},
          onSelectionChanged: (selection) => onMealChanged(selection.first),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Period'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _end(
              label: 'From',
              date: _from,
              onPickDate: _changeFrom,
              isDinner: _startsAtDinner,
              onMealChanged: (value) => setState(() => _startsAtDinner = value),
            ),
            const SizedBox(height: 4),
            _end(
              label: 'Until',
              date: _to,
              onPickDate: _changeTo,
              isDinner: !_endsAfterLunch,
              onMealChanged: (value) =>
                  setState(() => _endsAfterLunch = !value),
            ),
            const SizedBox(height: 14),
            MealCounter(
              title: 'Lunch',
              icon: Icons.lunch_dining_outlined,
              value: _lunch,
              onChanged: (value) => setState(() => _lunch = value),
            ),
            const SizedBox(height: 8),
            MealCounter(
              title: 'Dinner',
              icon: Icons.dinner_dining_outlined,
              value: _dinner,
              onChanged: (value) => setState(() => _dinner = value),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.campaign_outlined,
                color: AppTheme.primary,
              ),
              title: const Text(
                'Set an Announcement',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              value: _announce,
              onChanged: (value) => setState(() => _announce = value),
            ),
            if (_isEmpty)
              const Text(
                'The period must end after it starts.',
                style: TextStyle(color: AppTheme.danger),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isEmpty
              ? null
              : () {
                  Navigator.of(context).pop((
                    rule: MealPlanRule(
                      lunch: _lunch,
                      dinner: _dinner,
                      fromDate: MealPlans.dateKey(_from),
                      startsAtDinner: _startsAtDinner,
                      toDate: MealPlans.dateKey(_to),
                      endsAfterLunch: _endsAfterLunch,
                    ),
                    announce: _announce,
                  ));
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
