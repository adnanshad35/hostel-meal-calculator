import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/activity_log.dart';
import '../services/error_messages.dart';
import '../services/group_member_service.dart';
import '../services/meal_cancellation.dart';
import '../services/meal_cancellation_service.dart';
import '../services/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/month_archive.dart';
import '../services/month_records.dart';
import '../services/month_rules.dart';
import '../services/month_rules_service.dart';
import '../services/monthly_calculator.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meal_counter.dart';
import '../widgets/month_calendar.dart';
import 'meal_ledger_screen.dart';
import 'meal_plan_screen.dart';

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
  late final Stream<MonthRules> _rulesStream;

  User get _user => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _membersStream = GroupMemberService.watch(widget.groupId);
    _plansStream = MealPlanService.watchAll(widget.groupId);
    _rulesStream = MonthRulesService.watch(widget.groupId, DateTime.now());
    // This month only: the page shows nothing older.
    _mealsStream = MonthRecords.meals(
      widget.groupId,
      DateTime.now(),
    ).snapshots();
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
                return StreamBuilder<MonthRules>(
                  stream: _rulesStream,
                  builder: (context, rulesSnapshot) {
                    return _buildMeals(
                      context,
                      now: now,
                      members: membersSnapshot.data ?? const [],
                      plans: plansSnapshot.data ?? const [],
                      rules: rulesSnapshot.data ?? MonthRules.none,
                    );
                  },
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
    required MonthRules rules,
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

        final saved = [
          for (final document in snapshot.data?.docs ?? [])
            if ((document.data()['dateKey'] as String? ?? '').startsWith(
              currentMonth,
            ))
              MealRecord.fromData(document.id, document.data()),
        ];

        // Days without an entry are counted from the meal plans, and
        // meals cancelled for everyone count as zero.
        final counted = rules.applyToMeals([
          ...saved,
          ...MealPlans.automaticMeals(
            plans: plans,
            meals: saved,
            activeMemberIds: {
              _user.uid,
              for (final member in members) member.id,
            },
            month: now,
            today: now,
          ),
        ]);

        for (final meal in counted) {
          totalMealsMonthly += meal.lunch + meal.dinner;
          if (meal.userId == _user.uid) {
            myMonthlyTotal += meal.lunch + meal.dinner;
          }
        }

        for (final document in snapshot.data?.docs ?? []) {
          final data = document.data();
          if (data['userId'] == _user.uid && data['dateKey'] == todayKey) {
            myEntryToday = data;
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
                    color: AppTheme.primary,
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
                    color: AppTheme.primary,
                    onTap: _openMyMeals,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TodayMealCard(
              entry: myEntryToday,
              planned: MealPlans.forDay(myRules, todayKey),
              cancelled: rules.cancellations.dayOf(todayKey),
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
    required this.cancelled,
    required this.onTap,
  });

  final Map<String, dynamic>? entry;

  /// What the member's meal plan counts today when there is no entry.
  final PlannedMeals? planned;

  /// Today's meals an admin cancelled for everyone, if any.
  final CancelledDay? cancelled;
  final VoidCallback onTap;

  /// "Lunch: 1   Dinner: Off", with Off for a cancelled meal.
  String _meals(double lunch, double dinner) {
    final cancelled = this.cancelled;
    final lunchText = cancelled?.lunch == true
        ? 'Off'
        : _displayQuantity(lunch);
    final dinnerText = cancelled?.dinner == true
        ? 'Off'
        : _displayQuantity(dinner);

    return 'Lunch: $lunchText   Dinner: $dinnerText';
  }

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final planned = this.planned;
    final cancelled = this.cancelled;

    if (cancelled != null && cancelled.lunch && cancelled.dinner) {
      return const Card(
        color: AppTheme.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(Icons.no_meals_outlined, color: AppTheme.accentDeep),
          title: Text(
            "Today's Meals Off",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (entry == null && planned != null) {
      return Card(
        color: AppTheme.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: const Icon(
            Icons.event_repeat_outlined,
            color: AppTheme.primary,
          ),
          title: const Text(
            'Today is counted from your meal plan',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(_meals(planned.lunch, planned.dinner)),
          trailing: const Icon(Icons.edit_outlined),
        ),
      );
    }

    if (entry == null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.info_outline, color: AppTheme.accentDeep),
          title: const Text(
            "Today's Meals Not Entered",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: cancelled == null ? null : Text('${cancelled.label}: Off'),
        ),
      );
    }

    final lunch = (entry['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (entry['dinner'] as num?)?.toDouble() ?? 0;

    return Card(
      color: AppTheme.surfaceSoft,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.check_circle_outline,
          color: AppTheme.primary,
        ),
        title: const Text(
          "Today's meals entered",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_meals(lunch, dinner)),
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

/// The two parts of the Add Meal dialog.
enum _FormTab { entry, plan, mealOff }

class _MealFormDialogState extends State<_MealFormDialog> {
  StreamSubscription<List<GroupMember>>? _membersSubscription;

  _FormTab _tab = _FormTab.entry;

  List<GroupMember> _members = [];
  late String _selectedMemberId;
  late DateTime _selectedDate;

  double _lunch = 0;
  double _dinner = 0;

  bool _isLoadingMembers = false;
  bool _isLoadingEntry = true;
  bool _isSaving = false;
  bool _hasEntry = false;

  /// True when an admin cancelled that meal of the selected day for
  /// everyone. It cannot be entered, and an entry keeps what it had.
  bool _isLunchCancelled = false;
  bool _isDinnerCancelled = false;

  /// What the entry held when it was opened, for the hostel's history.
  double? _savedLunch;
  double? _savedDinner;

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
      _lunch = _defaultMeals;
      _dinner = _defaultMeals;
    });

    try {
      final (snapshot, rules) = await (
        _mealCollection.doc(_entryId).get(),
        MonthRulesService.fetch(widget.groupId, _selectedDate),
      ).wait;
      final data = snapshot.data();
      final dateKey = _dateKey(_selectedDate);

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
        _isLunchCancelled = rules.cancellations.isLunchCancelled(dateKey);
        _isDinnerCancelled = rules.cancellations.isDinnerCancelled(dateKey);

        if (planned != null) {
          _lunch = planned.lunch;
          _dinner = planned.dinner;
        }

        // An existing entry shows what was saved. A new one starts at
        // the usual one lunch and one dinner, ready to save or adjust.
        if (snapshot.exists) {
          _lunch = (data?['lunch'] as num?)?.toDouble() ?? 0;
          _dinner = (data?['dinner'] as num?)?.toDouble() ?? 0;
        }
        _savedLunch = snapshot.exists ? _lunch : null;
        _savedDinner = snapshot.exists ? _dinner : null;
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

  /// The last day a meal can be entered, or turned off: a cook's
  /// leave can be entered up to the end of next month.
  DateTime _lastDate(DateTime now) => _tab == _FormTab.mealOff
      ? DateTime(now.year, now.month + 2, 0)
      : DateTime(now.year, now.month + 1, 0);

  void _showTab(_FormTab tab) {
    final now = DateTime.now();
    // A day next month, chosen for Meal Off, cannot have a meal
    // entry yet, so the entry goes back to today.
    final backToToday =
        tab != _FormTab.mealOff &&
        _selectedDate.isAfter(DateTime(now.year, now.month + 1, 0));

    setState(() {
      _tab = tab;
      if (backToToday) _selectedDate = now;
    });

    if (backToToday) _loadEntry();
  }

  /// Turns the selected day's lunch and dinner off for everyone, or on
  /// again. Each switch saves at once. Admins only.
  Future<void> _setMealOff({required bool lunch, required bool dinner}) async {
    if (!await ensureHostelEditable(context, widget.groupId)) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final day = _selectedDate;

    setState(() => _isSaving = true);
    try {
      await MealCancellationService.save(
        groupId: widget.groupId,
        day: DateTime(day.year, day.month, day.day),
        lunch: lunch,
        dinner: dinner,
      );
      if (mounted) {
        setState(() {
          _isLunchCancelled = lunch;
          _isDinnerCancelled = dinner;
        });
      }
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to save the change.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The Meal Off tab: one switch for lunch and one for dinner, for
  /// the day at the bottom.
  Widget _mealOffPanel() {
    if (_isLoadingEntry) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lunch_dining_outlined),
          title: const Text(
            'Lunch Off for Everyone',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          value: _isLunchCancelled,
          onChanged: _isSaving
              ? null
              : (isOff) =>
                    _setMealOff(lunch: isOff, dinner: _isDinnerCancelled),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.dinner_dining_outlined),
          title: const Text(
            'Dinner Off for Everyone',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          value: _isDinnerCancelled,
          onChanged: _isSaving
              ? null
              : (isOff) => _setMealOff(lunch: _isLunchCancelled, dinner: isOff),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: MonthLock.firstEditableDay(now),
      lastDate: _lastDate(now),
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

  /// What is saved: a cancelled meal keeps what the entry had, or
  /// nothing for a new entry.
  double get _lunchToSave => _isLunchCancelled ? _savedLunch ?? 0 : _lunch;
  double get _dinnerToSave => _isDinnerCancelled ? _savedDinner ?? 0 : _dinner;

  bool get _isDayCancelled => _isLunchCancelled && _isDinnerCancelled;

  Future<bool> _confirmLargeQuantity() async {
    // A cancelled meal cannot be entered, so it is never asked about.
    final lunch = _isLunchCancelled ? 0 : _lunch;
    final dinner = _isDinnerCancelled ? 0 : _dinner;
    if (lunch <= 5 && dinner <= 5) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Large Quantity'),
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
    // Saving what is already there changes nothing, so it is not
    // recorded, nor marked as edited.
    if (_hasEntry &&
        _lunchToSave == _savedLunch &&
        _dinnerToSave == _savedDinner) {
      Navigator.of(context).pop();
      return;
    }

    // A saved entry may be changed only while the admins allow it.
    if (_hasEntry && !await ensureMemberMayEdit(context, widget.groupId)) {
      return;
    }
    if (!mounted) return;

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
            ? ProfileService.memberName ?? _currentUser.displayName ?? 'Member'
            : _selectedMemberName,
        'dateKey': _dateKey(_selectedDate),
        'date': Timestamp.fromDate(_selectedDate),
        'lunch': _lunchToSave,
        'dinner': _dinnerToSave,
        'total': _lunchToSave + _dinnerToSave,
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

      final batch = FirebaseFirestore.instance.batch()
        ..set(_mealCollection.doc(_entryId), data, SetOptions(merge: true));
      ActivityLog.addTo(
        batch,
        widget.groupId,
        kind: _hasEntry ? ActivityKind.mealChanged : ActivityKind.mealAdded,
        memberId: _selectedMemberId,
        memberName: data['userName'] as String,
        day: _dateKey(_selectedDate),
        details: ActivityLog.mealDetails(
          lunch: _lunchToSave,
          dinner: _dinnerToSave,
          oldLunch: _savedLunch,
          oldDinner: _savedDinner,
        ),
      );
      await batch.commit();

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

    // A little wider than the default, so the meal plan has room; the
    // full screen width is used on a phone.
    final dialogWidth = (MediaQuery.sizeOf(context).width - 40)
        .clamp(0.0, 520.0)
        .toDouble();
    final isPlan = _tab == _FormTab.plan;
    final isMealOff = _tab == _FormTab.mealOff;
    // Three tabs fit a phone only without their icons.
    final showIcons = !widget.isAdmin;

    return AlertDialog(
      // Wider than the default, with room around each part, so the
      // form does not feel cramped.
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Text(
        isPlan
            ? 'Meal Plan'
            : isMealOff
            ? 'Meal Off'
            : (_hasEntry ? 'Update Meal' : 'Add Meal'),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_FormTab>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _FormTab.entry,
                    label: const Text('Meal Entry'),
                    icon: showIcons
                        ? const Icon(Icons.restaurant_outlined)
                        : null,
                  ),
                  ButtonSegment(
                    value: _FormTab.plan,
                    label: const Text('Meal Plan'),
                    icon: showIcons
                        ? const Icon(Icons.event_repeat_outlined)
                        : null,
                  ),
                  if (widget.isAdmin)
                    const ButtonSegment(
                      value: _FormTab.mealOff,
                      label: Text('Meal Off'),
                    ),
                ],
                selected: {_tab},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) => _showTab(selection.first),
              ),
              const SizedBox(height: 20),
              if (isPlan)
                MealPlanScreen(
                  groupId: widget.groupId,
                  isAdmin: widget.isAdmin,
                  embedded: true,
                )
              else if (isMealOff)
                _mealOffPanel()
              else ...[
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
                      key: ValueKey(
                        _members.map((member) => member.id).join(','),
                      ),
                      initialValue: _selectedMemberId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Meal For',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _members.map((member) {
                        return DropdownMenuItem<String>(
                          value: member.id,
                          // Green for a member who uses the app.
                          child: Text(
                            member.id == _currentUser.uid
                                ? '${member.name} (You)'
                                : member.name,
                            overflow: TextOverflow.ellipsis,
                            style: member.isAppUser
                                ? const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : _selectMember,
                    ),
                  const SizedBox(height: 24),
                ],
                if (_isLoadingEntry)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  MealCounter(
                    title: _isLunchCancelled ? 'Lunch Off' : 'Lunch',
                    icon: _isLunchCancelled
                        ? Icons.no_meals_outlined
                        : Icons.lunch_dining_outlined,
                    value: _isLunchCancelled ? 0 : _lunch,
                    enabled: !_isSaving && !_isLunchCancelled,
                    onChanged: (value) => setState(() => _lunch = value),
                  ),
                  const SizedBox(height: 20),
                  MealCounter(
                    title: _isDinnerCancelled ? 'Dinner Off' : 'Dinner',
                    icon: _isDinnerCancelled
                        ? Icons.no_meals_outlined
                        : Icons.dinner_dining_outlined,
                    value: _isDinnerCancelled ? 0 : _dinner,
                    enabled: !_isSaving && !_isDinnerCancelled,
                    onChanged: (value) => setState(() => _dinner = value),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      // The date sits at the bottom left; tapping it opens the
      // calendar. The meal plan has no date, so only Close shows.
      actionsAlignment: isPlan
          ? MainAxisAlignment.end
          : MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 24, 22),
      actions: isPlan
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ]
          : [
              InkWell(
                onTap: _isSaving ? null : _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: Color(0xFF176B4D),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMealOff)
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed:
                          isBusy ||
                              _isDayCancelled ||
                              (widget.isAdmin && _isLoadingMembers)
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
  /// The month on screen: this month, or an earlier one.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  late Stream<QuerySnapshot<Map<String, dynamic>>> _meals;
  late Stream<MonthRules> _rules;
  late final Stream<MemberMealPlan> _plan;

  @override
  void initState() {
    super.initState();

    // One month at a time. Filtered to this member afterwards, which
    // avoids needing a composite index.
    _meals = MonthRecords.meals(widget.groupId, _month).snapshots();
    _rules = MonthRulesService.watch(widget.groupId, _month);
    _plan = MealPlanService.watch(widget.groupId, widget.currentUserId);
  }

  void _showMonth(DateTime month) {
    setState(() {
      _month = month;
      _meals = MonthRecords.meals(widget.groupId, month).snapshots();
      _rules = MonthRulesService.watch(widget.groupId, month);
    });
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

              return StreamBuilder<MonthRules>(
                stream: _rules,
                builder: (context, rules) => _buildCalendar(
                  meals.data!.docs,
                  plan.data,
                  rules.data ?? MonthRules.none,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    MemberMealPlan? plan,
    MonthRules rules,
  ) {
    final saved = [
      for (final document in docs)
        if (document.data()['userId'] == widget.currentUserId)
          MealRecord.fromData(document.id, document.data()),
    ];

    // Days without an entry, counted from the meal plan. Meals
    // cancelled for everyone count as zero.
    final records = rules.applyToMeals([
      ...saved,
      if (plan != null)
        ...MealPlans.automaticMeals(
          plans: [plan],
          meals: saved,
          activeMemberIds: {widget.currentUserId},
          month: _month,
          today: DateTime.now(),
        ),
    ]);

    final byDay = <int, MealRecord>{};
    double total = 0;

    for (final record in records) {
      final day = int.tryParse((record.dateKey ?? '').split('-').last);
      if (day == null) continue;

      byDay[day] = record;
      total += record.lunch + record.dinner;
    }

    final previous = shiftMonth(_month, -1);
    final next = shiftMonth(_month, 1);
    final now = DateTime.now();

    String dateKeyOf(int day) =>
        _dateKey(DateTime(_month.year, _month.month, day));

    // "Lunch 1 · Dinner Off", with Off for a meal cancelled for
    // everyone.
    String mealsOf(int day, MealRecord record) {
      final dateKey = dateKeyOf(day);
      final lunch = rules.cancellations.isLunchCancelled(dateKey)
          ? 'Off'
          : _displayQuantity(record.lunch);
      final dinner = rules.cancellations.isDinnerCancelled(dateKey)
          ? 'Off'
          : _displayQuantity(record.dinner);
      return 'Lunch $lunch · Dinner $dinner';
    }

    return MonthCalendarView(
      // A new month starts on its own selected day and view.
      key: ValueKey(_month),
      month: _month,
      onPreviousMonth: previous == null ? null : () => _showMonth(previous),
      onNextMonth: next == null ? null : () => _showMonth(next),
      label: 'My Meals',
      total: _displayQuantity(total),
      showMonthOption: true,
      // The month view lists only the days with an entry, one line each.
      shortLinesOf: (day) {
        final record = byDay[day];
        if (record == null) return const [];

        return [
          CalendarLine(
            title: mealsOf(day, record),
            trailing: _displayQuantity(record.lunch + record.dinner),
          ),
        ];
      },
      markedDays: {
        for (final entry in byDay.entries)
          if (entry.value.lunch + entry.value.dinner > 0) entry.key,
      },
      linesOf: (day) {
        final record = byDay[day];
        // Only days that have come can be entered, while the month is
        // still open: last month stays open for the first week.
        final canEdit =
            isEditableMonth(_month) &&
            (!isCurrentMonth(_month) || day <= now.day);

        void edit() {
          showMealForm(
            context,
            groupId: widget.groupId,
            isAdmin: false,
            date: DateTime(_month.year, _month.month, day),
          );
        }

        final cancelled = rules.cancellations.dayOf(dateKeyOf(day));

        if (record == null) {
          return [
            if (cancelled != null)
              CalendarLine(title: '${cancelled.label} Off', trailing: '')
            else if (canEdit)
              CalendarLine(title: 'No Entry', trailing: '', onTap: edit),
          ];
        }

        return [
          CalendarLine(
            title: mealsOf(day, record),
            note: cancelled != null
                ? 'off'
                : record.isAutomatic
                ? 'plan'
                : null,
            trailing: _displayQuantity(record.lunch + record.dinner),
            onTap: canEdit ? edit : null,
          ),
        ];
      },
    );
  }
}
