import 'package:flutter/material.dart';

import '../services/member_departure_service.dart';
import '../services/month_rules.dart';
import '../theme/app_theme.dart';

/// Shows a member's month and lets an admin choose how it counts now
/// that they are leaving. Remove All is offered only within [limits].
/// Returns null when the admin backs out.
Future<LeavingChoice?> showLeavingChoiceSheet(
  BuildContext context, {
  required String memberName,
  required DepartureSummary summary,
  required RemoveAllLimits limits,
  LeavingChoice? initial,
  String confirmLabel = 'Save',
}) {
  return showModalBottomSheet<LeavingChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LeavingChoiceSheet(
      memberName: memberName,
      summary: summary,
      limits: limits,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class _LeavingChoiceSheet extends StatefulWidget {
  const _LeavingChoiceSheet({
    required this.memberName,
    required this.summary,
    required this.limits,
    required this.initial,
    required this.confirmLabel,
  });

  final String memberName;
  final DepartureSummary summary;
  final RemoveAllLimits limits;
  final LeavingChoice? initial;
  final String confirmLabel;

  @override
  State<_LeavingChoiceSheet> createState() => _LeavingChoiceSheetState();
}

class _LeavingChoiceSheetState extends State<_LeavingChoiceSheet> {
  late LeavingChoice _choice;

  List<LeavingChoice> get _choices => [
    if (widget.limits.allows(
          meals: widget.summary.meals,
          spending: widget.summary.spending,
        ) ||
        widget.initial == LeavingChoice.removeAll)
      LeavingChoice.removeAll,
    LeavingChoice.actualOnly,
    LeavingChoice.normal,
  ];

  @override
  void initState() {
    super.initState();
    _choice = widget.initial ?? LeavingChoice.normal;
  }

  static String _quantity(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  /// "Gets ৳120", "Owes ৳80" or "Settled".
  static String _balance(int balance) {
    if (balance > 0) return 'Gets ৳$balance';
    if (balance < 0) return 'Owes ৳${-balance}';
    return 'Settled';
  }

  Widget _figure(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final balance = summary.balances[_choice] ?? 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.memberName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _figure('Meals', _quantity(summary.meals)),
                  _figure('Paid', '৳${summary.spending.round()}'),
                  _figure(
                    'Balance',
                    _choice == LeavingChoice.removeAll
                        ? '—'
                        : _balance(balance),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<LeavingChoice>(
              groupValue: _choice,
              onChanged: (choice) {
                if (choice != null) setState(() => _choice = choice);
              },
              child: Column(
                children: [
                  for (final choice in _choices)
                    RadioListTile<LeavingChoice>(
                      value: choice,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        choice.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_choice),
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}
