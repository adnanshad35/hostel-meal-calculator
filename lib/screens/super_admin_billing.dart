import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/subscription_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'hostel_activation_screen.dart';

/// Activation data for the super admin panel, loaded in one go.
class AdminBilling {
  const AdminBilling({
    required this.subscriptions,
    required this.vouchers,
    required this.payments,
    required this.paymentInfo,
    this.appConfig = const AppConfig(),
  });

  static Future<AdminBilling> load() async {
    return AdminBilling(
      subscriptions: await SubscriptionService.loadSubscriptions(),
      vouchers: await SubscriptionService.loadVouchers(),
      payments: await SubscriptionService.loadPayments(),
      paymentInfo: await SubscriptionService.loadPaymentInfo(),
      appConfig: await SubscriptionService.loadAppConfig(),
    );
  }

  /// Keyed by hostel id.
  final Map<String, HostelSubscription> subscriptions;
  final List<Voucher> vouchers;
  final List<PaymentRequest> payments;
  final PaymentInfo paymentInfo;
  final AppConfig appConfig;

  HostelSubscription subscriptionOf(String groupId) {
    return subscriptions[groupId] ?? const HostelSubscription.none();
  }

  int get pendingPayments => payments
      .where((payment) => payment.status == PaymentStatus.pending)
      .length;

  /// Hostels whose members can add and change records right now.
  int activeHostels(DateTime now) =>
      subscriptions.values.where((item) => item.canEdit(now)).length;

  /// Hostels whose latest voucher is [code].
  int hostelsUsing(String code) =>
      subscriptions.values.where((item) => item.voucherCode == code).length;
}

/// Runs a super admin action, reports the outcome, and reloads.
Future<void> runAdminAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successMessage,
  required Future<void> Function() onDone,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    await onDone();
  } on SubscriptionException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  } on FirebaseException catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error.code == 'permission-denied'
              ? 'Only the super admin can do this.'
              : error.message ?? 'Something went wrong.',
        ),
      ),
    );
  }
}

/// Asks how many days to add. Pops with the number, or null.
Future<int?> askForDays(
  BuildContext context, {
  required String title,
  required String message,
  int initialDays = 30,
  String label = 'Days to add',
  String confirmLabel = 'Add',
  bool allowZero = false,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _DaysDialog(
      title: title,
      message: message,
      initialDays: initialDays,
      label: label,
      confirmLabel: confirmLabel,
      allowZero: allowZero,
    ),
  );
}

class _DaysDialog extends StatefulWidget {
  const _DaysDialog({
    required this.title,
    required this.message,
    required this.initialDays,
    required this.label,
    required this.confirmLabel,
    required this.allowZero,
  });

  final String title;
  final String message;
  final int initialDays;
  final String label;
  final String confirmLabel;
  final bool allowZero;

  @override
  State<_DaysDialog> createState() => _DaysDialogState();
}

class _DaysDialogState extends State<_DaysDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialDays}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(int.parse(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: const Icon(Icons.event_available_outlined),
              ),
              validator: (value) =>
                  _validateDays(value, allowZero: widget.allowZero),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

String? _validateDays(String? value, {bool allowZero = false}) {
  final days = int.tryParse(value?.trim() ?? '');
  final minimum = allowZero ? 0 : 1;

  if (days == null || days < minimum || days > 3650) {
    return 'Enter a number of days from $minimum to 3650.';
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// Payments tab
// ─────────────────────────────────────────────────────────────
class AdminPaymentsTab extends StatelessWidget {
  const AdminPaymentsTab({
    super.key,
    required this.billing,
    required this.onRefresh,
  });

  final AdminBilling billing;
  final Future<void> Function() onRefresh;

  Future<void> _editPaymentInfo(BuildContext context) async {
    final info = await showDialog<PaymentInfo>(
      context: context,
      builder: (_) => _PaymentInfoDialog(info: billing.paymentInfo),
    );

    if (info == null || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.savePaymentInfo(
        bkashNumber: info.bkashNumber,
        instructions: info.instructions,
      ),
      successMessage: 'Payment details saved.',
      onDone: onRefresh,
    );
  }

  Future<void> _approve(BuildContext context, PaymentRequest payment) async {
    final days = await askForDays(
      context,
      title: 'Approve Payment',
      message:
          'Confirm in bKash that ${payment.trxId} for '
          '৳${payment.amount.toStringAsFixed(0)} was received, then '
          'choose how many days to give ${payment.groupName}.',
    );

    if (days == null || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.grantDays(
        groupId: payment.groupId,
        days: days,
        source: 'payment',
        payment: payment,
      ),
      successMessage: '$days days were added to ${payment.groupName}.',
      onDone: onRefresh,
    );
  }

  Future<void> _reject(BuildContext context, PaymentRequest payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Payment?'),
          content: Text(
            'Mark ${payment.trxId} from ${payment.groupName} as '
            'rejected? The hostel will see that it was not accepted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.rejectPayment(
        payment,
        note: 'The transaction could not be confirmed.',
      ),
      successMessage: 'Payment rejected.',
      onDone: onRefresh,
    );
  }

  Future<void> _delete(BuildContext context, PaymentRequest payment) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete Payment?',
      message:
          'Remove ${payment.trxId} from ${payment.groupName} from the '
          'records? '
          '${payment.status == PaymentStatus.approved ? 'The days already given for it stay with the hostel. ' : ''}'
          'This cannot be undone.',
    );

    if (!confirmed || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.deletePayment(payment),
      successMessage: 'Payment ${payment.trxId} deleted.',
      onDone: onRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = billing.paymentInfo;
    final payments = billing.payments;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => _editPaymentInfo(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primary,
                size: 28,
              ),
              title: const Text(
                'Payment details shown to hostels',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                info.isEmpty
                    ? 'Not set. Hostels are told to use a voucher.'
                    : [
                        if (info.bkashNumber.isNotEmpty)
                          'bKash ${info.bkashNumber}',
                        if (info.instructions.isNotEmpty) info.instructions,
                      ].join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            payments.isEmpty
                ? 'No payments reported yet'
                : '${billing.pendingPayments} waiting · '
                      '${payments.length} in total',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          if (payments.isNotEmpty) ...[
            Text(
              'Press and hold a payment to delete it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          for (final payment in payments) ...[
            _ApprovalCard(
              key: ValueKey(payment.trxId),
              payment: payment,
              onApprove: () => _approve(context, payment),
              onReject: () => _reject(context, payment),
              onDelete: () => _delete(context, payment),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PaymentInfoDialog extends StatefulWidget {
  const _PaymentInfoDialog({required this.info});

  final PaymentInfo info;

  @override
  State<_PaymentInfoDialog> createState() => _PaymentInfoDialogState();
}

class _PaymentInfoDialogState extends State<_PaymentInfoDialog> {
  late final TextEditingController _numberController;
  late final TextEditingController _instructionsController;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.info.bkashNumber);
    _instructionsController = TextEditingController(
      text: widget.info.instructions,
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payment Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hostel admins see this when they activate a hostel. '
              'Leave both empty to hide bKash payment for now.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'bKash number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              maxLength: 400,
              decoration: const InputDecoration(
                labelText: 'Instructions and Prices',
                alignLabelWithHint: true,
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
          onPressed: () => Navigator.of(context).pop(
            PaymentInfo(
              bkashNumber: _numberController.text.trim(),
              instructions: _instructionsController.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Asks before something is deleted for good.
Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
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
      );
    },
  );

  return confirmed == true;
}

/// One reported payment, laid out for checking it against bKash: who
/// paid and how much on top, then the transaction ID and the sender's
/// number, each a tap away from the clipboard.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    super.key,
    required this.payment,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final PaymentRequest payment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  Future<void> _copy(BuildContext context, String label, String value) async {
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  /// A small label with its value, and a copy button when it is
  /// something to look up in bKash.
  Widget _detail(
    BuildContext context, {
    required String label,
    required String value,
    bool canCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canCopy)
            InkWell(
              onTap: () => _copy(context, label, value),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.copy_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = payment.status == PaymentStatus.pending;

    final (status, color) = switch (payment.status) {
      PaymentStatus.pending => ('Waiting', AppTheme.warning),
      PaymentStatus.approved => (
        payment.daysGranted > 0
            ? 'Approved · ${payment.daysGranted} days'
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
      clipBehavior: Clip.antiAlias,
      // A waiting payment is edged in its colour, so the ones that
      // need attention are found at a glance.
      shape: isPending
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.warning, width: 1.4),
            )
          : null,
      child: InkWell(
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (date != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  formatSubscriptionDate(date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '৳$amount',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _detail(
                context,
                label: 'TrxID',
                value: payment.trxId,
                canCopy: true,
              ),
              if (payment.senderNumber.isNotEmpty)
                _detail(
                  context,
                  label: 'From',
                  value: payment.senderNumber,
                  canCopy: true,
                ),
              if (payment.submittedByName.isNotEmpty)
                _detail(
                  context,
                  label: 'Sent By',
                  value: payment.submittedByName,
                ),
              if (payment.status == PaymentStatus.rejected &&
                  payment.note.isNotEmpty)
                _detail(context, label: 'Note', value: payment.note),
              if (isPending) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            foregroundColor: AppTheme.danger,
                          ),
                          onPressed: onReject,
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: onApprove,
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Vouchers tab
// ─────────────────────────────────────────────────────────────
class AdminVouchersTab extends StatelessWidget {
  const AdminVouchersTab({
    super.key,
    required this.billing,
    required this.onRefresh,
  });

  final AdminBilling billing;
  final Future<void> Function() onRefresh;

  Future<void> _createVoucher(BuildContext context) async {
    final voucher = await showDialog<Voucher>(
      context: context,
      builder: (_) => const _VoucherDialog(),
    );

    if (voucher == null || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.createVoucher(
        code: voucher.code,
        days: voucher.days,
        note: voucher.note,
      ),
      successMessage: 'Voucher ${voucher.code} created.',
      onDone: onRefresh,
    );
  }

  Future<void> _setActive(BuildContext context, Voucher voucher, bool active) {
    return runAdminAction(
      context,
      action: () => SubscriptionService.setVoucherActive(voucher, active),
      successMessage: active
          ? '${voucher.code} can be used again.'
          : '${voucher.code} is switched off.',
      onDone: onRefresh,
    );
  }

  Future<void> _delete(BuildContext context, Voucher voucher) async {
    final used = billing.hostelsUsing(voucher.code);

    final confirmed = await _confirmDelete(
      context,
      title: 'Delete Voucher?',
      message:
          'Delete ${voucher.code}? Nobody will be able to use it again. '
          '${used == 0 ? '' : 'The $used ${used == 1 ? 'hostel' : 'hostels'} on it now keep their days. '}'
          'This cannot be undone.',
    );

    if (!confirmed || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.deleteVoucher(voucher),
      successMessage: 'Voucher ${voucher.code} deleted.',
      onDone: onRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vouchers = billing.vouchers;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FilledButton.icon(
            onPressed: () => _createVoucher(context),
            icon: const Icon(Icons.add),
            label: const Text('New Voucher'),
          ),
          const SizedBox(height: 12),
          const Text(
            'A voucher adds days to a hostel. Each hostel can use a '
            'voucher once. Switch a voucher off to stop new use, or '
            'press and hold it to delete it.',
          ),
          const SizedBox(height: 16),
          if (vouchers.isEmpty)
            const Text('No vouchers yet.')
          else
            for (final voucher in vouchers) ...[
              Card(
                key: ValueKey(voucher.code),
                clipBehavior: Clip.antiAlias,
                // The switch still answers a tap; holding the card
                // anywhere offers to delete the voucher.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _delete(context, voucher),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    title: Text(
                      voucher.code,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    subtitle: Text(
                      [
                        '${voucher.days} days · on '
                            '${billing.hostelsUsing(voucher.code)} hostels',
                        if (voucher.note.isNotEmpty) voucher.note,
                      ].join('\n'),
                    ),
                    value: voucher.active,
                    onChanged: (active) => _setActive(context, voucher, active),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _VoucherDialog extends StatefulWidget {
  const _VoucherDialog();

  @override
  State<_VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<_VoucherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _daysController = TextEditingController(text: '30');
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _daysController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      Voucher(
        code: SubscriptionService.normalizeCode(_codeController.text),
        days: int.parse(_daysController.text.trim()),
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Voucher'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Code',
                  hintText: 'Example: WC100',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  final code = SubscriptionService.normalizeCode(value ?? '');
                  if (!SubscriptionService.isValidCode(code)) {
                    return 'Use 4 to 20 letters and numbers.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Days It Adds',
                  prefixIcon: Icon(Icons.event_available_outlined),
                ),
                validator: _validateDays,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Note for Yourself (Optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Maintenance mode card (Overview tab)
// ─────────────────────────────────────────────────────────────
class AdminMaintenanceCard extends StatelessWidget {
  const AdminMaintenanceCard({
    super.key,
    required this.config,
    required this.onRefresh,
  });

  final AppConfig config;
  final Future<void> Function() onRefresh;

  Future<void> _toggle(BuildContext context, bool turnOn) async {
    var message = config.maintenanceMessage;

    if (turnOn) {
      final entered = await showDialog<String>(
        context: context,
        builder: (_) => _MaintenanceDialog(message: message),
      );

      if (entered == null || !context.mounted) return;
      message = entered;
    }

    await runAdminAction(
      context,
      action: () => SubscriptionService.saveAppConfig(
        maintenance: turnOn,
        message: message,
      ),
      successMessage: turnOn
          ? 'Maintenance mode is on. Users now see the maintenance '
                'screen.'
          : 'Maintenance mode is off. The app is open again.',
      onDone: onRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: config.maintenance ? const Color(0xFFFFF2DA) : null,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: Icon(
          Icons.build_circle_outlined,
          color: config.maintenance ? AppTheme.warning : AppTheme.textSecondary,
          size: 30,
        ),
        title: const Text(
          'Maintenance Mode',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(config.maintenance ? 'On' : 'Off'),
        value: config.maintenance,
        onChanged: (value) => _toggle(context, value),
      ),
    );
  }
}

class _MaintenanceDialog extends StatefulWidget {
  const _MaintenanceDialog({required this.message});

  final String message;

  @override
  State<_MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<_MaintenanceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Turn On Maintenance?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Every user will see a maintenance screen instead of the '
              'app until you turn this off. You keep full access.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Message to Users (Optional)',
                hintText: 'Example: Back at 9 PM tonight.',
                alignLabelWithHint: true,
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
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Turn On'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// App update card (Overview tab)
// ─────────────────────────────────────────────────────────────

/// The newest app version every user is offered, and the oldest one
/// still allowed.
class AdminUpdateCard extends StatelessWidget {
  const AdminUpdateCard({super.key});

  Future<void> _edit(BuildContext context, UpdateConfig? config) async {
    final entered = await showDialog<UpdateConfig>(
      context: context,
      builder: (_) => _UpdateConfigDialog(config: config),
    );
    if (entered == null || !context.mounted) return;

    await runAdminAction(
      context,
      action: () => UpdateService.saveConfig(entered),
      successMessage: 'Version ${entered.version} is now offered to users.',
      onDone: () async {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UpdateConfig?>(
      stream: UpdateService.watchConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => _edit(context, config),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const Icon(
              Icons.system_update_outlined,
              color: AppTheme.primary,
              size: 30,
            ),
            title: const Text(
              'App Update',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              config == null
                  ? 'Not set. Users are checked against GitHub.'
                  : 'Latest ${config.version}'
                        '${config.minVersion.isEmpty ? '' : ' · Minimum ${config.minVersion}'}',
            ),
            trailing: const Icon(Icons.edit_outlined),
          ),
        );
      },
    );
  }
}

class _UpdateConfigDialog extends StatefulWidget {
  const _UpdateConfigDialog({required this.config});

  final UpdateConfig? config;

  @override
  State<_UpdateConfigDialog> createState() => _UpdateConfigDialogState();
}

class _UpdateConfigDialogState extends State<_UpdateConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _version = TextEditingController(text: widget.config?.version);
  late final _minVersion = TextEditingController(
    text: widget.config?.minVersion,
  );
  late final _notes = TextEditingController(text: widget.config?.notes);
  late final _downloadUrl = TextEditingController(
    text: widget.config?.downloadUrl,
  );

  @override
  void dispose() {
    _version.dispose();
    _minVersion.dispose();
    _notes.dispose();
    _downloadUrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      UpdateConfig(
        version: _version.text.trim(),
        minVersion: _minVersion.text.trim(),
        notes: _notes.text.trim(),
        downloadUrl: _downloadUrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('App Update'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _version,
                  decoration: const InputDecoration(
                    labelText: 'Latest Version',
                    hintText: '1.7.0',
                  ),
                  validator: (value) =>
                      UpdateService.isValidVersion(value ?? '')
                      ? null
                      : 'Use a version such as 1.7.0.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minVersion,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Version (Optional)',
                    hintText: 'Older versions must update',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    if (!UpdateService.isValidVersion(text)) {
                      return 'Use a version such as 1.6.0.';
                    }
                    if (UpdateService.isNewer(text, _version.text)) {
                      return 'It cannot be above the latest version.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What\'s New',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _downloadUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'APK Link (Optional)',
                    hintText: 'Newest GitHub release',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty || text.startsWith('https://')) {
                      return null;
                    }
                    return 'Use an https:// link.';
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
