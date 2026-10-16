import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

String formatSubscriptionDate(DateTime date) {
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

/// Where a hostel admin activates or extends the hostel with a
/// voucher. Paying with bKash is on its way.
class HostelActivationScreen extends StatefulWidget {
  const HostelActivationScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<HostelActivationScreen> createState() => _HostelActivationScreenState();
}

class _HostelActivationScreenState extends State<HostelActivationScreen> {
  final _voucherController = TextEditingController();

  late final Stream<HostelSubscription> _subscription =
      SubscriptionService.watch(widget.groupId);

  bool _isRedeeming = false;

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _redeemVoucher() async {
    final code = _voucherController.text;

    if (SubscriptionService.normalizeCode(code).isEmpty) {
      _showMessage('Please enter a voucher code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isRedeeming = true);

    try {
      final days = await SubscriptionService.redeemVoucher(
        groupId: widget.groupId,
        code: code,
      );

      _voucherController.clear();
      _showMessage('Voucher accepted. $days days were added.');
    } on SubscriptionException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activate Hostel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          StreamBuilder<HostelSubscription>(
            stream: _subscription,
            builder: (context, snapshot) {
              return SubscriptionStatusCard(
                subscription: snapshot.data ?? const HostelSubscription.none(),
                isLoading: !snapshot.hasData && !snapshot.hasError,
                hostelName: widget.groupName,
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _OptionTitle(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Voucher',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _voucherController,
                    enabled: !_isRedeeming,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Voucher Code',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    onSubmitted: (_) => _redeemVoucher(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isRedeeming ? null : _redeemVoucher,
                    child: _isRedeeming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Apply Voucher'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Not ready yet: shown so admins know it is on the way.
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: _OptionTitle(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Pay with bKash',
                      isMuted: true,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Next Update',
                      style: TextStyle(
                        color: AppTheme.accentDeep,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon in a soft square and the name of a way to activate.
class _OptionTitle extends StatelessWidget {
  const _OptionTitle({
    required this.icon,
    required this.title,
    this.isMuted = false,
  });

  final IconData icon;
  final String title;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 21,
            color: isMuted ? AppTheme.textSecondary : AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: isMuted ? AppTheme.textSecondary : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Whether a hostel is active, and until when.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({
    super.key,
    required this.subscription,
    this.hostelName,
    this.isLoading = false,
    this.action,
  });

  final HostelSubscription subscription;
  final String? hostelName;
  final bool isLoading;

  /// Optional button shown on the right, such as "Activate".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = subscription.isActive(now);
    final until = subscription.activeUntil;

    final String title;
    final String subtitle;

    if (isLoading) {
      title = 'Checking…';
      subtitle = hostelName ?? '';
    } else if (subscription.accessDisabled) {
      title = 'Suspended';
      subtitle = 'Contact HostelMate support.';
    } else if (subscription.editingDisabled) {
      title = 'Read-only';
      subtitle = 'Editing is switched off by HostelMate.';
    } else if (isActive) {
      title = until == null
          ? 'Active'
          : 'Active · ${subscription.timeLeftText(now)}';
      subtitle = until == null
          ? 'Activating…'
          : 'Until ${formatSubscriptionDate(until)}';
    } else {
      title = until == null ? 'Not Activated' : 'Expired';
      subtitle = until == null
          ? ''
          : 'Ended on ${formatSubscriptionDate(until)}';
    }

    final canEdit = subscription.canEdit(now);
    final color = isLoading
        ? AppTheme.textSecondary
        : subscription.accessDisabled
        ? AppTheme.danger
        : canEdit
        ? AppTheme.success
        : AppTheme.warning;

    return Card(
      color: isLoading || canEdit
          ? AppTheme.surfaceSoft
          : subscription.accessDisabled
          ? const Color(0xFFFCE8E8)
          : const Color(0xFFFFF2DA),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(
              subscription.accessDisabled
                  ? Icons.block
                  : canEdit
                  ? Icons.verified_outlined
                  : Icons.lock_outline,
              color: color,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// One reported payment and what became of it.
class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.payment, this.actions});

  final PaymentRequest payment;

  /// Shown under the details, for example Approve and Reject.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (payment.status) {
      PaymentStatus.pending => ('Waiting for review', AppTheme.warning),
      PaymentStatus.approved => (
        payment.daysGranted > 0
            ? 'Approved · ${payment.daysGranted} days added'
            : 'Approved',
        AppTheme.success,
      ),
      PaymentStatus.rejected => ('Rejected', AppTheme.danger),
    };

    final amount = payment.amount % 1 == 0
        ? payment.amount.toInt().toString()
        : payment.amount.toStringAsFixed(2);
    final date = payment.createdAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payment.trxId,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '৳$amount',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (payment.status == PaymentStatus.rejected &&
                payment.note.isNotEmpty)
              Text(payment.note),
            if (date != null)
              Text(
                'Submitted ${formatSubscriptionDate(date)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (actions != null) ...[const SizedBox(height: 8), actions!],
          ],
        ),
      ),
    );
  }
}
