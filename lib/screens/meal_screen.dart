import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/monthly_calculator.dart';
import '../widgets/meal_counter.dart';
import '../widgets/month_calendar.dart';
import 'meal_ledger_screen.dart';

/// Opens the Add Meal form, unless the hostel is read-only.
Future<void> showMealForm(
  BuildContext context, {
  required String groupId,
  required bool isAdmin,
  DateTime? date,
}) async {
  if (!await ensureHostelEditable(context, groupId)) return;
  if (!context.mounted) return;
  if (!await ensureMemberMayAdd(context, groupId, meals: true)) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) =>
        _MealFormDialog(groupId: groupId, isAdmin: isAdmin, date: date),
  );
}

class MealScreen extends StatefulWidget {
  const MealScreen({super.key, required this.groupId, required this.isAdmin});

  final String groupId;
  final bool isAdmin;

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _mealsStream;
  late final Stream<List<GroupMember>> _membersStream;
  late final Stream<List<MemberMealPlan>> _plansStream;

  User get _user => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _membersStream = GroupMemberService.watch(widget.groupId);
    _plansStream = MealPlanService.watchAll(widget.groupId);
    _mealsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('meals')
        .snapshots();
  }

  Future<void> _openMealForm() {
    return showMealForm(
      context,
      groupId: widget.groupId,
      isAdmin: widget.isAdmin,
    );
  }

  void _openLedger() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MealLedgerScreen(groupId: widget.groupId, isAdmin: widget.isAdmin),
      ),
    );
  }

  void _openMyMeals() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MyMealsScreen(groupId: widget.groupId, currentUserId: _user.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Update')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMealForm,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<GroupMember>>(
          stream: _membersStream,
          builder: (context, membersSnapshot) {
            return StreamBuilder<List<MemberMealPlan>>(
              stream: _plansStream,
              builder: (context, plansSnapshot) {
                return _buildMeals(
                  context,
                  now: now,
                  members: membersSnapshot.data ?? const [],
                  plans: plansSnapshot.data ?? const [],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMeals(
    BuildContext context, {
    required DateTime now,
    required List<GroupMember> members,
    required List<MemberMealPlan> plans,
  }) {
    final currentMonth = _monthKey(now);
    final todayKey = _dateKey(now);
    final myRules =
        plans.where((plan) => plan.memberId == _user.uid).firstOrNull?.rules ??
        const <MealPlanRule>[];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mealsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load meals.'));
        }

        double totalMealsMonthly = 0;
        double myMonthlyTotal = 0;
        Map<String, dynamic>? myEntryToday;

        // Days without an entry, counted from the meal plans.
        final planned = MealPlans.automaticMeals(
          plans: plans,
          meals: [
            for (final document in snapshot.data?.docs ?? [])
              MealRecord.fromData(document.id, document.data()),
          ],
          activeMemberIds: {_user.uid, for (final member in members) member.id},
          month: now,
          today: now,
        );

        for (final meal in planned) {
          totalMealsMonthly += meal.lunch + meal.dinner;
          if (meal.userId == _user.uid) {
            myMonthlyTotal += meal.lunch + meal.dinner;
          }
        }

        for (final document in snapshot.data?.docs ?? []) {
          final data = document.data();
          final dateKey = data['dateKey'] as String? ?? '';
          final userId = data['userId'] as String?;

          if (!dateKey.startsWith(currentMonth)) continue;

          final total = (data['total'] as num?)?.toDouble() ?? 0;

          totalMealsMonthly += total;

          if (userId == _user.uid) {
            myMonthlyTotal += total;
            if (dateKey == todayKey) {
              myEntryToday = data;
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    icon: Icons.groups_outlined,
                    title: 'Total Meals',
                    value: _displayQuantity(totalMealsMonthly),
                    subtitle: 'This month',
                    color: const Color(0xFF2E7D32),
                    onTap: _openLedger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    icon: Icons.person_outline,
                    title: 'My Meals',
                    value: _displayQuantity(myMonthlyTotal),
                    subtitle: 'This month',
                    color: const Color(0xFF2E7D32),
                    onTap: _openMyMeals,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TodayMealCard(
              entry: myEntryToday,
              planned: MealPlans.forDay(myRules, todayKey),
              onTap: _openMealForm,
            ),
          ],
        );
      },
    );
  }
}

String _dateKey(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

String _monthKey(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');

  return '$year-$month';
}

String _displayQuantity(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────
// Today's entry of the signed-in member
// ─────────────────────────────────────────────────────────────
class _TodayMealCard extends StatelessWidget {
  const _TodayMealCard({
    required this.entry,
    required this.planned,
    required this.onTap,
  });

  final Map<String, dynamic>? entry;

  /// What the member's meal plan counts today when there is no entry.
  final PlannedMeals? planned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final planned = this.planned;

    if (entry == null && planned != null) {
      return Card(
        color: const Color(0xFFE8F5E9),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: const Icon(
            Icons.event_repeat_outlined,
            color: Color(0xFF2E7D32),
          ),
          title: const Text(
            'Today is counted from your meal plan',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Lunch: ${_displayQuantity(planned.lunch)}   '
            'Dinner: ${_displayQuantity(planned.dinner)}',
          ),
          trailing: const Icon(Icons.edit_outlined),
        ),
      );
    }

    if (entry == null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.info_outline, color: Colors.orange),
          title: const Text(
            'Today\'s meals not entered',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Tap Add Meal to record them.'),
        ),
      );
    }

    final lunch = (entry['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (entry['dinner'] as num?)?.toDouble() ?? 0;

    return Card(
      color: const Color(0xFFE8F5E9),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF2E7D32),
        ),
        title: const Text(
          'Today\'s meals entered',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Lunch: ${_displayQuantity(lunch)}   '
          'Dinner: ${_displayQuantity(dinner)}',
        ),
        trailing: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Meal form dialog — members record their own meals, admins can
// pick any member of the hostel
// ─────────────────────────────────────────────────────────────
class _MealFormDialog extends StatefulWidget {
  const _MealFormDialog({
    required this.groupId,
    required this.isAdmin,
    this.date,
  });

  final String groupId;
  final bool isAdmin;

  /// The day to open on. Today when left out.
  final DateTime? date;

  @override
  State<_MealFormDialog> createState() => _MealFormDialogState();
}

class _MealFormDialogState extends State<_MealFormDialog> {
  StreamSubscription<List<GroupMember>>? _membersSubscription;

  List<GroupMember> _members = [];
  late String _selectedMemberId;
  late DateTime _selectedDate;

  double _lunch = 0;
  double _dinner = 0;

  bool _isLoadingMembers = false;
  bool _isLoadingEntry = true;
  bool _isSaving = false;
  bool _hasEntry = false;

  /// True when the counters show what the member's meal plan already
  /// counts for the day.
  bool _isFromPlan = false;

  /// What a new entry starts with, since most days are one lunch and
  /// one dinner. Nothing is recorded until the member taps Save.
  static const double _defaultMeals = 1;

  // Identifies the newest entry request, so a slow earlier one
  // cannot overwrite the counters.
  int _loadRequest = 0;

  User get _currentUser => FirebaseAuth.instance.currentUser!;

  bool get _isOwnEntry => _selectedMemberId == _currentUser.uid;

  CollectionReference<Map<String, dynamic>> get _mealCollection =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('meals');

  String get _entryId => '${_selectedMemberId}_${_dateKey(_selectedDate)}';

  @override
  void initState() {
    super.initState();
    _selectedMemberId = _currentUser.uid;
    _selectedDate = widget.date ?? DateTime.now();

    if (widget.isAdmin) {
      _watchMembers();
    }

    _loadEntry();
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    super.dispose();
  }

  void _watchMembers() {
    _isLoadingMembers = true;

    _membersSubscription = GroupMemberService.watch(widget.groupId).listen(
      (activeMembers) {
        final members = [...activeMembers];

        if (!members.any((member) => member.id == _currentUser.uid)) {
          members.add(
            GroupMember(
              id: _currentUser.uid,
              name: _currentUser.displayName?.trim().isNotEmpty == true
                  ? _currentUser.displayName!.trim()
                  : _currentUser.email ?? 'Administrator',
              isAppUser: true,
              userId: _currentUser.uid,
            ),
          );
          members.sort(GroupMember.compareByName);
        }

        if (!mounted) return;

        final selectionRemoved = !members.any(
          (member) => member.id == _selectedMemberId,
        );

        setState(() {
          _members = members;
          _isLoadingMembers = false;
          if (selectionRemoved) {
            _selectedMemberId = _currentUser.uid;
          }
        });

        if (selectionRemoved) {
          _loadEntry();
        }
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() => _isLoadingMembers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load members.')),
        );
      },
    );
  }

  Future<void> _loadEntry() async {
    final request = ++_loadRequest;

    setState(() {
      _isLoadingEntry = true;
      _hasEntry = false;
      _isFromPlan = false;
      _lunch = _defaultMeals;
      _dinner = _defaultMeals;
    });

    try {
      final snapshot = await _mealCollection.doc(_entryId).get();
      final data = snapshot.data();

      // Without an entry, the form starts from the member's meal plan
      // for that day, if they have one.
      PlannedMeals? planned;
      if (!snapshot.exists) {
        final plan = await MealPlanService.fetch(
          widget.groupId,
          _selectedMemberId,
        );
        planned = MealPlans.forDay(plan.rules, _dateKey(_selectedDate));
      }

      if (!mounted || request != _loadRequest) return;

      setState(() {
        _hasEntry = snapshot.exists;

        if (planned != null) {
          _isFromPlan = true;
          _lunch = planned.lunch;
          _dinner = planned.dinner;
        }

        // An existing entry shows what was saved. A new one starts at
        // the usual one lunch and one dinner, ready to save or adjust.
        if (snapshot.exists) {
          _lunch = (data?['lunch'] as num?)?.toDouble() ?? 0;
          _dinner = (data?['dinner'] as num?)?.toDouble() ?? 0;
        }
      });
    } on FirebaseException {
      if (!mounted || request != _loadRequest) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load the meal entry.')),
      );
    } finally {
      if (mounted && request == _loadRequest) {
        setState(() => _isLoadingEntry = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month),
      lastDate: DateTime(now.year, now.month + 1, 0),
      helpText: 'Select a meal date',
    );

    if (selected == null || selected == _selectedDate || !mounted) return;

    setState(() => _selectedDate = selected);
    await _loadEntry();
  }

  void _selectMember(String? memberId) {
    if (memberId == null || memberId == _selectedMemberId) return;

    setState(() => _selectedMemberId = memberId);
    _loadEntry();
  }

  String get _selectedMemberName {
    final member = _members
        .where((member) => member.id == _selectedMemberId)
        .firstOrNull;

    return member?.name ?? 'Member';
  }

  Future<bool> _confirmLargeQuantity() async {
    if (_lunch <= 5 && _dinner <= 5) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm large quantity'),
              content: Text(
                'You entered ${_displayQuantity(_lunch)} lunch and '
                '${_displayQuantity(_dinner)} dinner meals. '
                'Are these values correct?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Review'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _save() async {
    final confirmed = await _confirmLargeQuantity();

    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final displayedDate =
        '${_selectedDate.day}/${_selectedDate.month}/'
        '${_selectedDate.year}';

    try {
      final data = <String, dynamic>{
        'groupId': widget.groupId,
        'userId': _selectedMemberId,
        'userName': _isOwnEntry
            ? _currentUser.displayName ?? 'Member'
            : _selectedMemberName,
        'dateKey': _dateKey(_selectedDate),
        'date': Timestamp.fromDate(_selectedDate),
        'lunch': _lunch,
        'dinner': _dinner,
        'total': _lunch + _dinner,
        'submitted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_isOwnEntry) {
        data['updatedBy'] = _currentUser.uid;
        data['updatedByName'] = _currentUser.displayName ?? 'Administrator';
        data['adminEdited'] = true;
      }

      if (!_hasEntry) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _mealCollection.doc(_entryId).set(data, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isOwnEntry
                ? 'Meals saved for $displayedDate.'
                : 'Meals saved for $_selectedMemberName on '
                      '$displayedDate.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save the meal entry.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final formattedDate = '$day/$month/${_selectedDate.year}';
    final isBusy = _isSaving || _isLoadingEntry;

    return AlertDialog(
      title: Text(_hasEntry ? 'Update Meal' : 'Add Meal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isAdmin) ...[
              if (_isLoadingMembers)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                )
              else
                DropdownButtonFormField<String>(
                  // Rebuilt when the member list changes, so the
                  // selection can never point at a missing member.
                  key: ValueKey(_members.map((member) => member.id).join(',')),
                  initialValue: _selectedMemberId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Meal for',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: _members.map((member) {
                    return DropdownMenuItem<String>(
                      value: member.id,
                      child: Text(
                        member.id == _currentUser.uid
                            ? '${member.name} (You)'
                            : member.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _isSaving ? null : _selectMember,
                ),
              const SizedBox(height: 8),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(formattedDate),
              trailing: TextButton(
                onPressed: _isSaving ? null : _selectDate,
                child: const Text('Change'),
              ),
            ),
            if (_isLoadingEntry)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else ...[
              if (_hasEntry) ...[
                const Text(
                  'Already entered for this date. Saving will '
                  'update it.',
                ),
                const SizedBox(height: 8),
              ],
              if (_isFromPlan) ...[
                const Text(
                  'This is what the meal plan counts for this date. '
                  'Save to set something different.',
                ),
                const SizedBox(height: 8),
              ],
              MealCounter(
                title: 'Lunch',
                icon: Icons.lunch_dining_outlined,
                value: _lunch,
                enabled: !_isSaving,
                onChanged: (value) => setState(() => _lunch = value),
              ),
              const SizedBox(height: 8),
              MealCounter(
                title: 'Dinner',
                icon: Icons.dinner_dining_outlined,
                value: _dinner,
                enabled: !_isSaving,
                onChanged: (value) => setState(() => _dinner = value),
              ),
              const SizedBox(height: 4),
              Text(
                'Use − and +, or tap a number to type it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isBusy || (widget.isAdmin && _isLoadingMembers)
              ? null
              : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tappable summary tile
// ─────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// My Meals: the signed-in member's month, as a calendar
// ─────────────────────────────────────────────────────────────
class MyMealsScreen extends StatefulWidget {
  const MyMealsScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
    this.embedded = false,
  });

  final String groupId;
  final String currentUserId;

  /// True when shown as a tab of another page, which has the title.
  final bool embedded;

  @override
  State<MyMealsScreen> createState() => _MyMealsScreenState();
}

class _MyMealsScreenState extends State<MyMealsScreen> {
  late final DateTime _now = DateTime.now();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _meals;
  late final Stream<MemberMealPlan> _plan;

  @override
  void initState() {
    super.initState();

    // This month only. Filtered to this member afterwards, which
    // avoids needing a composite index.
    _meals = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('meals')
        .where(
          'dateKey',
          isGreaterThanOrEqualTo: _dateKey(DateTime(_now.year, _now.month)),
        )
        .where(
          'dateKey',
          isLessThan: _dateKey(DateTime(_now.year, _now.month + 1)),
        )
        .snapshots();
    _plan = MealPlanService.watch(widget.groupId, widget.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('My Meals')),
      body: StreamBuilder<MemberMealPlan>(
        stream: _plan,
        builder: (context, plan) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _meals,
            builder: (context, meals) {
              if (meals.hasError) {
                return const Center(child: Text('Unable to load your meals.'));
              }

              if (!meals.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return _buildCalendar(meals.data!.docs, plan.data);
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    MemberMealPlan? plan,
  ) {
    final saved = [
      for (final document in docs)
        if (document.data()['userId'] == widget.currentUserId)
          MealRecord.fromData(document.id, document.data()),
    ];

    // Days without an entry, counted from the meal plan.
    final records = [
      ...saved,
      if (plan != null)
        ...MealPlans.automaticMeals(
          plans: [plan],
          meals: saved,
          activeMemberIds: {widget.currentUserId},
          month: _now,
          today: _now,
        ),
    ];

    final byDay = <int, MealRecord>{};
    double total = 0;

    for (final record in records) {
      final day = int.tryParse((record.dateKey ?? '').split('-').last);
      if (day == null) continue;

      byDay[day] = record;
      total += record.lunch + record.dinner;
    }

    return MonthCalendarView(
      month: _now,
      label: 'My meals',
      total: _displayQuantity(total),
      markedDays: {
        for (final entry in byDay.entries)
          if (entry.value.lunch + entry.value.dinner > 0) entry.key,
      },
      linesOf: (day) {
        final record = byDay[day];
        // A day that has not come yet has nothing to enter.
        final canEdit = day <= _now.day;

        void edit() {
          showMealForm(
            context,
            groupId: widget.groupId,
            isAdmin: false,
            date: DateTime(_now.year, _now.month, day),
          );
        }

        if (record == null) {
          return [
            if (canEdit)
              CalendarLine(title: 'No entry', trailing: '', onTap: edit),
          ];
        }

        return [
          CalendarLine(
            title:
                'Lunch ${_displayQuantity(record.lunch)} · '
                'Dinner ${_displayQuantity(record.dinner)}',
            note: record.isAutomatic ? 'plan' : null,
            trailing: _displayQuantity(record.lunch + record.dinner),
            onTap: canEdit ? edit : null,
          ),
        ];
      },
    );
  }
}
