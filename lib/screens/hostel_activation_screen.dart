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

/// Where a hostel admin activates or extends the hostel: with a
/// voucher, or by reporting a bKash payment for review.
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
  final _paymentFormKey = GlobalKey<FormState>();
  final _trxController = TextEditingController();
  final _amountController = TextEditingController();
  final _senderController = TextEditingController();

  late final Stream<HostelSubscription> _subscription;
  late final Stream<PaymentInfo> _paymentInfo;
  late final Stream<List<PaymentRequest>> _payments;

  bool _isRedeeming = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _subscription = SubscriptionService.watch(widget.groupId);
    _paymentInfo = SubscriptionService.watchPaymentInfo();
    _payments = SubscriptionService.watchGroupPayments(widget.groupId);
  }

  @override
  void dispose() {
    _voucherController.dispose();
    _trxController.dispose();
    _amountController.dispose();
    _senderController.dispose();
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

  Future<void> _submitPayment() async {
    if (!_paymentFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      await SubscriptionService.submitPayment(
        groupId: widget.groupId,
        groupName: widget.groupName,
        trxId: _trxController.text,
        amount: double.parse(_amountController.text.trim()),
        senderNumber: _senderController.text,
      );

      _trxController.clear();
      _amountController.clear();
      _senderController.clear();
      _showMessage(
        'Payment submitted. The hostel is activated once it is checked.',
      );
    } on SubscriptionException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          const SizedBox(height: 24),

          // ─── Voucher ───
          Text('Voucher', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Have a voucher code? Enter it to add days.'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  enabled: !_isRedeeming,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Voucher code',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  onSubmitted: (_) => _redeemVoucher(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _isRedeeming ? null : _redeemVoucher,
                child: _isRedeeming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ─── bKash payment ───
          Text('Pay with bKash', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<PaymentInfo>(
            stream: _paymentInfo,
            builder: (context, snapshot) {
              final info = snapshot.data ?? const PaymentInfo();

              if (info.isEmpty) {
                return const Text(
                  'Payment details have not been published yet. Use a '
                  'voucher for now.',
                );
              }

              return Card(
                color: AppTheme.surfaceSoft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (info.bkashNumber.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send money to',
                                    style: textTheme.bodySmall,
                                  ),
                                  Text(
                                    info.bkashNumber,
                                    style: textTheme.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy number',
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: info.bkashNumber),
                                );
                                _showMessage('Number copied.');
                              },
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          ],
                        ),
                      if (info.bkashNumber.isNotEmpty &&
                          info.instructions.isNotEmpty)
                        const SizedBox(height: 10),
                      if (info.instructions.isNotEmpty) Text(info.instructions),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'After paying, enter the details below. The hostel is '
            'activated once the payment has been checked.',
          ),
          const SizedBox(height: 12),
          Form(
            key: _paymentFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _trxController,
                  enabled: !_isSubmitting,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Transaction ID',
                    hintText: 'Example: 9HK3ABC1XY',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  validator: (value) {
                    final id = SubscriptionService.normalizeCode(value ?? '');
                    if (!SubscriptionService.isValidCode(id)) {
                      return 'Enter the ID exactly as bKash shows it.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Amount paid',
                    prefixText: '৳ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter the amount you paid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _senderController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'bKash number you paid from',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );
                    if (digits.length < 10) {
                      return 'Enter the number you paid from.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submitPayment,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Payment'),
                  ),
                ),
              ],
            ),
          ),

          // ─── This hostel's reported payments ───
          StreamBuilder<List<PaymentRequest>>(
            stream: _payments,
            builder: (context, snapshot) {
              final payments = snapshot.data ?? const <PaymentRequest>[];
              if (payments.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  Text('Your payments', style: textTheme.titleMedium),
                  const SizedBox(height: 10),
                  for (final payment in payments) ...[
                    PaymentCard(payment: payment),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
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
    final daysLeft = subscription.daysLeft(now);

    final String title;
    final String subtitle;

    if (isLoading) {
      title = 'Checking status…';
      subtitle = hostelName ?? '';
    } else if (subscription.accessDisabled) {
      title = 'Suspended';
      subtitle =
          'This hostel has been suspended by HostelMate. '
          'Please contact support.';
    } else if (subscription.editingDisabled) {
      title = 'Read-only';
      subtitle =
          'Editing has been switched off for this hostel by '
          'HostelMate. Records can be viewed but not changed.';
    } else if (isActive) {
      title = until == null
          ? 'Active'
          : daysLeft == 1
          ? 'Active · 1 day left'
          : 'Active · $daysLeft days left';
      subtitle = until == null
          ? 'Activating…'
          : 'Until ${formatSubscriptionDate(until)}';
    } else {
      title = 'Read-only';
      subtitle = until == null
          ? 'This hostel has not been activated yet.'
          : 'Ended on ${formatSubscriptionDate(until)}. Records can '
                'be viewed but not changed.';
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
