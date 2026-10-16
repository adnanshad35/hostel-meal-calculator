import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/duty_roster.dart';
import '../services/group_member_service.dart';
import '../services/meal_plan.dart';
import '../theme/app_theme.dart';

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

/// A turn's days in words, such as "1 – 5 Oct" or "28 Oct – 2 Nov".
String dutyDatesText(DutyTurn turn) {
  final from = MealPlans.dateOf(turn.fromDate);
  final to = MealPlans.dateOf(turn.toDate);
  final end = '${to.day} ${_months[to.month - 1]}';

  if (turn.fromDate == turn.toDate) return end;
  if (from.month == to.month && from.year == to.year) {
    return '${from.day} – $end';
  }
  return '${from.day} ${_months[from.month - 1]} – $end';
}

/// Where an admin sets which member is responsible for the hostel on
/// which days.
class DutyRosterScreen extends StatefulWidget {
  const DutyRosterScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<DutyRosterScreen> createState() => _DutyRosterScreenState();
}

class _DutyRosterScreenState extends State<DutyRosterScreen> {
  late final Stream<DutyRoster> _roster = DutyRosterService.watch(
    widget.groupId,
  );

  bool _isSaving = false;

  Future<void> _save(List<DutyTurn> turns, String message) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);

    try {
      await DutyRosterService.save(widget.groupId, turns);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an admin can change this.'
                : error.message ?? 'Unable to save.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _add(DutyRoster roster) async {
    final turn = await showDialog<DutyTurn>(
      context: context,
      builder: (_) => _TurnDialog(groupId: widget.groupId, roster: roster),
    );

    if (turn == null || !mounted) return;

    await _save([
      ...roster.turns,
      turn,
    ], '${turn.memberName} is responsible ${dutyDatesText(turn)}.');
  }

  Future<void> _remove(DutyRoster roster, DutyTurn turn) {
    return _save([
      for (final existing in roster.turns)
        if (!identical(existing, turn)) existing,
    ], 'Removed.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DutyRoster>(
      stream: _roster,
      builder: (context, snapshot) {
        final roster = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Responsible Member')),
          floatingActionButton: roster == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: _isSaving ? null : () => _add(roster),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
          body: snapshot.hasError
              ? const Center(child: Text('Unable to load.'))
              : roster == null
              ? const Center(child: CircularProgressIndicator())
              : _buildList(roster),
        );
      },
    );
  }

  /// Moves the member of one running or coming turn to another
  /// place. The days stay where they are; the members trade places, so
  /// someone with an emergency can swap their period with another.
  Future<void> _reorder(
    DutyRoster roster,
    List<DutyTurn> movable,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) return Future.value();

    final members = [
      for (final turn in movable) (id: turn.memberId, name: turn.memberName),
    ];
    final moved = members.removeAt(oldIndex);
    members.insert(newIndex, moved);

    final reordered = [
      for (var index = 0; index < movable.length; index++)
        DutyTurn(
          memberId: members[index].id,
          memberName: members[index].name,
          fromDate: movable[index].fromDate,
          toDate: movable[index].toDate,
        ),
    ];

    return _save([
      for (final turn in roster.turns)
        if (!movable.any((other) => identical(other, turn))) turn,
      ...reordered,
    ], 'Duty order updated.');
  }

  Widget _turnCard(
    DutyRoster roster,
    DutyTurn turn, {
    required bool isToday,
    required bool isPast,
    Widget? handle,
  }) {
    return Card(
      // The turn running today stands out.
      color: isToday ? AppTheme.surfaceSoft : null,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
        title: Text(
          turn.memberName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isPast ? AppTheme.textSecondary : AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(dutyDatesText(turn)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Remove',
              onPressed: _isSaving ? null : () => _remove(roster, turn),
              icon: const Icon(Icons.delete_outline),
            ),
            ?handle,
          ],
        ),
      ),
    );
  }

  Widget _buildList(DutyRoster roster) {
    final now = DateTime.now();
    final today = MealPlans.dateKey(now);
    // Turns still running or yet to come, and this month's earlier ones.
    final turns = roster.from(DateTime(now.year, now.month));

    if (turns.isEmpty) {
      return const Center(child: Text('Nobody is set yet.'));
    }

    final past = [
      for (final turn in turns)
        if (turn.toDate.compareTo(today) < 0) turn,
    ];
    final movable = [
      for (final turn in turns)
        if (turn.toDate.compareTo(today) >= 0) turn,
    ];

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      buildDefaultDragHandles: false,
      header: Column(
        children: [
          for (final turn in past)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _turnCard(roster, turn, isToday: false, isPast: true),
            ),
        ],
      ),
      itemCount: movable.length,
      onReorderItem: (oldIndex, newIndex) {
        if (_isSaving) return;
        _reorder(roster, movable, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final turn = movable[index];

        return Padding(
          key: ValueKey('${turn.memberId}_${turn.fromDate}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _turnCard(
            roster,
            turn,
            isToday: turn.covers(today),
            isPast: false,
            handle: movable.length < 2
                ? null
                : ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(4, 8, 8, 8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Picks a member and the first and last day of their turn.
class _TurnDialog extends StatefulWidget {
  const _TurnDialog({required this.groupId, required this.roster});

  final String groupId;
  final DutyRoster roster;

  @override
  State<_TurnDialog> createState() => _TurnDialogState();
}

class _TurnDialogState extends State<_TurnDialog> {
  List<GroupMember>? _members;
  String? _memberId;
  late DateTime _from;
  late DateTime _to;
  String? _error;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = _from;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await GroupMemberService.watch(widget.groupId).first;
      if (mounted) setState(() => _members = members);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _members = const [];
        _error = 'Unable to load members.';
      });
    }
  }

  Future<DateTime?> _pick(DateTime initial, DateTime first) {
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(first.year + 1, first.month, first.day),
    );
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await _pick(_from, DateTime(now.year, now.month));

    if (picked == null || !mounted) return;

    setState(() {
      _from = picked;
      if (_to.isBefore(picked)) _to = picked;
    });
  }

  Future<void> _pickTo() async {
    final picked = await _pick(_to, _from);
    if (picked != null && mounted) setState(() => _to = picked);
  }

  void _submit() {
    final member = _members
        ?.where((member) => member.id == _memberId)
        .firstOrNull;

    if (member == null) {
      setState(() => _error = 'Please select a member.');
      return;
    }

    final turn = DutyTurn(
      memberId: member.id,
      memberName: member.name,
      fromDate: MealPlans.dateKey(_from),
      toDate: MealPlans.dateKey(_to),
    );

    final clash = widget.roster.clashWith(turn);
    if (clash != null) {
      setState(() {
        _error =
            '${clash.memberName} already has ${dutyDatesText(clash)}. '
            'Remove that first, or pick other days.';
      });
      return;
    }

    Navigator.of(context).pop(turn);
  }

  Widget _dateLine(String label, DateTime date, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onTap,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      trailing: Text(
        '${date.day} ${_months[date.month - 1]} ${date.year}',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;

    return AlertDialog(
      title: const Text('Responsible Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (members == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _memberId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Member',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  for (final member in members)
                    DropdownMenuItem<String>(
                      value: member.id,
                      child: Text(member.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _memberId = value;
                  _error = null;
                }),
              ),
            const SizedBox(height: 8),
            _dateLine('From', _from, _pickFrom),
            _dateLine('Until', _to, _pickTo),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger),
                ),
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
          onPressed: members == null ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
