import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/error_messages.dart';
import '../services/group_member_service.dart';
import '../services/initial_share.dart';
import '../services/month_records.dart';
import '../theme/app_theme.dart';

String _amountText(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

String _dateText(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// The month's Initial Shares, each with every member's contribution.
/// Admins add and delete them while the month is open.
class InitialShareScreen extends StatefulWidget {
  const InitialShareScreen({
    super.key,
    required this.groupId,
    required this.month,
    required this.monthName,
    required this.canAdd,
    required this.canDelete,
  });

  final String groupId;
  final DateTime month;
  final String monthName;

  /// Admins, while the month is open and Initial Share is on.
  final bool canAdd;

  /// Admins, while the month is open, even with Initial Share off.
  final bool canDelete;

  @override
  State<InitialShareScreen> createState() => _InitialShareScreenState();
}

class _InitialShareScreenState extends State<InitialShareScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _expenses =
      MonthRecords.expenses(widget.groupId, widget.month).snapshots();

  bool _isDeleting = false;

  void _add() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _InitialShareForm(groupId: widget.groupId, month: widget.month),
      ),
    );
  }

  Future<void> _delete(InitialShare share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Initial Share?'),
        content: Text(
          '৳${_amountText(share.total)} from '
          '${share.contributions.length} members, '
          '${_dateText(share.date)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (!await ensureHostelEditable(context, widget.groupId)) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    try {
      await InitialShareService.delete(groupId: widget.groupId, share: share);
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saveErrorMessage(error, fallback: 'Unable to delete the share.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initial Share')),
      floatingActionButton: widget.canAdd
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add Initial Share'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _expenses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load the shares.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final shares = InitialShare.fromExpenses(snapshot.data!.docs);
          final total = shares.fold<double>(
            0,
            (running, share) => running + share.total,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.savings_outlined,
                    color: AppTheme.primary,
                  ),
                  title: Text(
                    widget.monthName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    '৳${_amountText(total)}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (shares.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'No Initial Share This Month',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              for (final share in shares)
                _ShareCard(
                  share: share,
                  onDelete: widget.canDelete && !_isDeleting
                      ? () => _delete(share)
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.share, required this.onDelete});

  final InitialShare share;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateText(share.date),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '৳${_amountText(share.total)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.danger,
                    ),
                  )
                else
                  const SizedBox(width: 10, height: 48),
              ],
            ),
            const Divider(height: 8),
            for (final contribution in share.contributions)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        contribution.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '৳${_amountText(contribution.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

/// Adds an Initial Share: the total, and each contributor's part. Every
/// member starts ticked with an equal part, so an admin only changes
/// the exceptions.
class _InitialShareForm extends StatefulWidget {
  const _InitialShareForm({required this.groupId, required this.month});

  final String groupId;
  final DateTime month;

  @override
  State<_InitialShareForm> createState() => _InitialShareFormState();
}

class _Contributor {
  _Contributor(this.member);

  final GroupMember member;
  bool isIncluded = true;
  final TextEditingController amount = TextEditingController();

  double get value => double.tryParse(amount.text.trim()) ?? 0;
}

class _InitialShareFormState extends State<_InitialShareForm> {
  final _total = TextEditingController();
  List<_Contributor>? _contributors;
  late DateTime _date = _defaultDate();
  bool _isSaving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _total.dispose();
    for (final contributor in _contributors ?? const <_Contributor>[]) {
      contributor.amount.dispose();
    }
    super.dispose();
  }

  /// Today in the current month, or the last day of an earlier one.
  DateTime _defaultDate() {
    final now = DateTime.now();
    final lastDay = DateTime(widget.month.year, widget.month.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);
    return today.isBefore(lastDay) ? today : lastDay;
  }

  Future<void> _loadMembers() async {
    try {
      final members = await GroupMemberService.fetchActive(widget.groupId);
      if (!mounted) return;
      setState(() {
        _contributors = [for (final member in members) _Contributor(member)];
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  double get _totalValue => double.tryParse(_total.text.trim()) ?? 0;

  List<_Contributor> get _included => [
    for (final contributor in _contributors ?? const <_Contributor>[])
      if (contributor.isIncluded) contributor,
  ];

  double get _contributed =>
      _included.fold(0, (running, contributor) => running + contributor.value);

  /// Divides the total equally among the ticked members.
  void _splitEqually() {
    final included = _included;
    final parts = InitialShare.splitEqually(_totalValue, included.length);

    for (var index = 0; index < included.length; index++) {
      included[index].amount.text = parts[index] > 0
          ? _amountText(parts[index])
          : '';
    }
    for (final contributor in _contributors ?? const <_Contributor>[]) {
      if (!contributor.isIncluded) contributor.amount.text = '';
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(widget.month.year, widget.month.month);
    final monthEnd = DateTime(widget.month.year, widget.month.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);
    final last = monthEnd.isBefore(today) ? monthEnd : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(message)));

    final total = _totalValue;
    final included = _included.where((c) => c.value > 0).toList();

    if (total <= 0) return say('Enter the total amount.');
    if (included.isEmpty) return say('Choose at least one contributor.');
    if ((_contributed - total).abs() > 0.009) {
      return say(
        'The contributions add up to ৳${_amountText(_contributed)}, '
        'not ৳${_amountText(total)}.',
      );
    }

    if (!await ensureHostelEditable(context, widget.groupId)) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      await InitialShareService.add(
        groupId: widget.groupId,
        date: _date,
        contributions: [
          for (final contributor in included)
            ShareContribution(
              memberId: contributor.member.id,
              memberName: contributor.member.name,
              amount: contributor.value,
            ),
        ],
      );
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      say(saveErrorMessage(error, fallback: 'Unable to save the share.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contributors = _contributors;
    final difference = _contributed - _totalValue;
    final adds = difference.abs() <= 0.009;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Initial Share')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _isSaving || contributors == null ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ),
      body: _loadError != null
          ? const Center(child: Text('Unable to load the members.'))
          : contributors == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                TextField(
                  controller: _total,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total Amount',
                    prefixText: '৳ ',
                  ),
                  onChanged: (_) => _splitEqually(),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Date'),
                  trailing: Text(
                    _dateText(_date),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: _pickDate,
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Contributors',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _splitEqually,
                      icon: const Icon(Icons.balance_outlined, size: 18),
                      label: const Text('Split Equally'),
                    ),
                  ],
                ),
                for (final contributor in contributors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: contributor.isIncluded,
                          onChanged: (isOn) {
                            contributor.isIncluded = isOn ?? false;
                            _splitEqually();
                          },
                        ),
                        Expanded(
                          child: Text(
                            contributor.member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: contributor.isIncluded
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: contributor.amount,
                            enabled: contributor.isIncluded,
                            textAlign: TextAlign.end,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixText: '৳ ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Contributions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '৳${_amountText(_contributed)} / '
                      '৳${_amountText(_totalValue)}',
                      style: TextStyle(
                        color: adds ? AppTheme.primary : AppTheme.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
