import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/fixed_costs.dart';
import '../services/monthly_calculator.dart';
import '../theme/app_theme.dart';

/// Lets an admin enter each member's rent and the month's shared bills.
class FixedCostsScreen extends StatefulWidget {
  const FixedCostsScreen({
    super.key,
    required this.groupId,
    required this.month,
    required this.monthName,
    required this.members,
    required this.rents,
    required this.bills,
    required this.minimumMeals,
    required this.shopDue,
  });

  final String groupId;
  final DateTime month;
  final String monthName;
  final List<CalcMember> members;
  final Map<String, double> rents;
  final List<SharedBill> bills;

  /// Saved alongside the costs because the monthly settings document
  /// must always carry them.
  final double minimumMeals;
  final double shopDue;

  @override
  State<FixedCostsScreen> createState() => _FixedCostsScreenState();
}

class _BillRow {
  _BillRow({String name = '', String amount = ''})
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);

  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _FixedCostsScreenState extends State<FixedCostsScreen> {
  static const _suggestedBills = ['Wi-Fi', 'Electricity', 'Chef'];

  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _rentControllers;
  final List<_BillRow> _billRows = [];

  bool _isSaving = false;
  bool _isCopying = false;

  CollectionReference<Map<String, dynamic>> get _monthlySettings =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('monthlySettings');

  @override
  void initState() {
    super.initState();

    _rentControllers = {
      for (final member in widget.members)
        member.id: TextEditingController(
          text: _numberText(widget.rents[member.id]),
        ),
    };

    if (widget.bills.isEmpty) {
      for (final name in _suggestedBills) {
        _billRows.add(_BillRow(name: name));
      }
    } else {
      for (final bill in widget.bills) {
        _billRows.add(
          _BillRow(name: bill.name, amount: _numberText(bill.amount)),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _rentControllers.values) {
      controller.dispose();
    }
    for (final row in _billRows) {
      row.dispose();
    }
    super.dispose();
  }

  static String _numberText(double? value) {
    if (value == null || value <= 0) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  /// Empty means zero; anything else must be a number that is not
  /// negative.
  static String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final amount = double.tryParse(text);
    if (amount == null || amount < 0) return 'Enter a valid amount.';
    return null;
  }

  static double _amount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  void _addBillRow() {
    setState(() => _billRows.add(_BillRow()));
  }

  void _removeBillRow(_BillRow row) {
    setState(() => _billRows.remove(row));
    // Disposed after the frame so the field is gone before its
    // controller is.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  Future<void> _copyFromLastMonth() async {
    setState(() => _isCopying = true);

    try {
      final previousMonth =
          DateTime(widget.month.year, widget.month.month - 1);
      final snapshot = await _monthlySettings
          .doc(MonthlyCalculator.monthKey(previousMonth))
          .get();

      if (!mounted) return;

      final data = snapshot.data();
      final rents = FixedCostsCalculator.readRents(data?['rents']);
      final bills = FixedCostsCalculator.readBills(data?['sharedBills']);

      if (rents.isEmpty && bills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing was saved for last month.'),
          ),
        );
        return;
      }

      final oldRows = List<_BillRow>.of(_billRows);

      setState(() {
        for (final entry in _rentControllers.entries) {
          entry.value.text = _numberText(rents[entry.key]);
        }

        if (bills.isNotEmpty) {
          _billRows
            ..clear()
            ..addAll([
              for (final bill in bills)
                _BillRow(
                  name: bill.name,
                  amount: _numberText(bill.amount),
                ),
            ]);
        }
      });

      if (bills.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final row in oldRows) {
            row.dispose();
          }
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied from last month. Review and save.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to load last month.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final rents = <String, double>{
      for (final entry in _rentControllers.entries)
        if (_amount(entry.value) > 0) entry.key: _amount(entry.value),
    };

    // Rows without an amount are left out.
    final bills = [
      for (final row in _billRows)
        if (_amount(row.amount) > 0)
          SharedBill(
            name: row.name.text.trim(),
            amount: _amount(row.amount),
          ).toData(),
    ];

    setState(() => _isSaving = true);

    try {
      final monthKey = MonthlyCalculator.monthKey(widget.month);

      await _monthlySettings.doc(monthKey).set({
        'rents': rents,
        'sharedBills': bills,
        'minimumMeals': widget.minimumMeals,
        'shopDue': widget.shopDue,
        'monthKey': monthKey,
        'updatedBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an administrator can change rent and bills.'
                : error.message ?? 'Unable to save rent and bills.',
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
    final textTheme = Theme.of(context).textTheme;
    final isBusy = _isSaving || _isCopying;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent & Bills'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.monthName,
                    style: textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: isBusy ? null : _copyFromLastMonth,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Copy last month'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Rent ───
            Text('Rent', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Enter what each member pays. Leave empty for none.'),
            const SizedBox(height: 12),
            if (widget.members.isEmpty)
              const Text('No members were found.')
            else
              for (final member in widget.members) ...[
                TextFormField(
                  controller: _rentControllers[member.id],
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: member.name,
                    prefixText: '৳ ',
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),

            // ─── Shared bills ───
            Text('Shared bills', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Divided equally among all members. Rows without an '
              'amount are ignored.',
            ),
            const SizedBox(height: 12),
            for (final row in _billRows) ...[
              Row(
                key: ObjectKey(row),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: row.name,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Bill',
                      ),
                      validator: (value) {
                        final hasAmount = _amount(row.amount) > 0;
                        if (hasAmount &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Enter a name.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: row.amount,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '৳ ',
                      ),
                      validator: _validateAmount,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove bill',
                    onPressed:
                        _isSaving ? null : () => _removeBillRow(row),
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _addBillRow,
                icon: const Icon(Icons.add),
                label: const Text('Add another bill'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isBusy ? null : _save,
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
      ),
    );
  }
}
