import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../services/monthly_calculator.dart';
import '../theme/app_theme.dart';

/// Shows the month's balance as a picture, ready to share to WhatsApp,
/// Messenger and the like. Made on the phone; nothing is saved.
Future<void> showBalanceShare(
  BuildContext context, {
  required String hostelName,
  required String monthName,
  required MonthlyCalculation result,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BalanceShareDialog(
      hostelName: hostelName,
      monthName: monthName,
      result: result,
    ),
  );
}

class _BalanceShareDialog extends StatefulWidget {
  const _BalanceShareDialog({
    required this.hostelName,
    required this.monthName,
    required this.result,
  });

  final String hostelName;
  final String monthName;
  final MonthlyCalculation result;

  @override
  State<_BalanceShareDialog> createState() => _BalanceShareDialogState();
}

class _BalanceShareDialogState extends State<_BalanceShareDialog> {
  final _pictureKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    setState(() => _isSharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary =
          _pictureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('No picture');

      final fileName = 'HostelMate ${widget.monthName}.png'.replaceAll(
        ' ',
        '_',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to share the picture.')),
      );
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      title: const Text('Share Balance'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RepaintBoundary(
              key: _pictureKey,
              child: _BalancePicture(
                hostelName: widget.hostelName,
                monthName: widget.monthName,
                result: widget.result,
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSharing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSharing ? null : _share,
          icon: _isSharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_outlined),
          label: const Text('Share'),
        ),
      ],
    );
  }
}

/// The picture itself: a fixed width, so it looks the same on every
/// phone.
class _BalancePicture extends StatelessWidget {
  const _BalancePicture({
    required this.hostelName,
    required this.monthName,
    required this.result,
  });

  final String hostelName;
  final String monthName;
  final MonthlyCalculation result;

  static const double _width = 390;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Material(
        color: AppTheme.surface,
        child: SizedBox(
          width: _width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: const BoxDecoration(
                  gradient: AppTheme.heroGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hostelName.isNotEmpty)
                      Text(
                        hostelName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '$monthName Balance',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Stat(
                          label: 'Meal Rate',
                          value: '৳${result.mealRate.toStringAsFixed(2)}',
                        ),
                        _Stat(
                          label: 'Total Meals',
                          value: _number(result.totalMealNumber),
                        ),
                        _Stat(
                          label: 'Total Cost',
                          value: '৳${_number(result.totalExpense)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _Row(
                name: 'Member',
                meals: 'Meals',
                cost: 'Meal Cost',
                paid: 'Paid',
                balance: 'Balance',
                isHeader: true,
              ),
              for (final (index, member) in result.members.indexed)
                _Row(
                  name: member.name,
                  meals: _number(member.mealNumber),
                  // Taken from the rounded figures, so each row adds up.
                  cost: '৳${member.spending.round() - member.finalBalance}',
                  paid: '৳${member.spending.round()}',
                  balance: member.finalBalance < 0
                      ? 'Pay ৳${-member.finalBalance}'
                      : member.finalBalance > 0
                      ? 'Get ৳${member.finalBalance}'
                      : 'Settled',
                  balanceColor: member.finalBalance < 0
                      ? AppTheme.danger
                      : member.finalBalance > 0
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  isShaded: index.isOdd,
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Text(
                  'Made with HostelMate',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _number(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.meals,
    required this.cost,
    required this.paid,
    required this.balance,
    this.balanceColor = AppTheme.textPrimary,
    this.isHeader = false,
    this.isShaded = false,
  });

  final String name;
  final String meals;
  final String cost;
  final String paid;
  final String balance;
  final Color balanceColor;
  final bool isHeader;
  final bool isShaded;

  @override
  Widget build(BuildContext context) {
    TextStyle style([Color color = AppTheme.textPrimary]) => TextStyle(
      color: isHeader ? AppTheme.textSecondary : color,
      fontSize: isHeader ? 11.5 : 13,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
    );

    return Container(
      color: isHeader || isShaded ? AppTheme.surfaceSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(meals, textAlign: TextAlign.right, style: style()),
          ),
          Expanded(
            flex: 3,
            child: Text(cost, textAlign: TextAlign.right, style: style()),
          ),
          Expanded(
            flex: 3,
            child: Text(paid, textAlign: TextAlign.right, style: style()),
          ),
          Expanded(
            flex: 4,
            child: Text(
              balance,
              textAlign: TextAlign.right,
              style: style(balanceColor).copyWith(
                fontWeight: isHeader ? FontWeight.w700 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
