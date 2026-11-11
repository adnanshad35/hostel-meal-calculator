import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/rent_calculator.dart';
import '../theme/app_theme.dart';

/// A member's own calculator for rent and shared bills, with their
/// meal balance added in. Only this phone remembers what is typed;
/// nothing is saved to the hostel.
class RentCalculatorScreen extends StatefulWidget {
  const RentCalculatorScreen({super.key, this.mealBalance, this.memberCount});

  /// The member's meal balance so far this month; null if unknown.
  final int? mealBalance;

  /// The hostel's members, to start Shared By with.
  final int? memberCount;

  @override
  State<RentCalculatorScreen> createState() => _RentCalculatorScreenState();
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

class _RentCalculatorScreenState extends State<RentCalculatorScreen> {
  final _rent = TextEditingController();
  final List<_BillRow> _bills = [];
  int _people = 1;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _people = (widget.memberCount ?? 1).clamp(1, 999);
    _rent.addListener(_changed);
    _addBill();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _save();
    _rent.dispose();
    for (final bill in _bills) {
      bill.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = RentCalculatorMemory.decode(
        prefs.getString(RentCalculatorMemory.key),
      );
      if (saved == null || !mounted) return;
      setState(() {
        _rent.text = saved.rent;
        final people = int.tryParse(saved.people);
        if (people != null && people > 0) _people = people;
        if (saved.bills.isNotEmpty) {
          for (final bill in _bills) {
            bill.dispose();
          }
          _bills
            ..clear()
            ..addAll(
              saved.bills.map(
                (bill) =>
                    _listen(_BillRow(name: bill.name, amount: bill.amount)),
              ),
            );
        }
      });
    } catch (_) {
      // Starts empty.
    }
  }

  void _save() {
    final text = RentCalculatorMemory.encode(
      rent: _rent.text.trim(),
      people: '$_people',
      bills: [
        for (final bill in _bills)
          (name: bill.name.text.trim(), amount: bill.amount.text.trim()),
      ],
    );
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(RentCalculatorMemory.key, text))
        .catchError((Object _) => false);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  _BillRow _listen(_BillRow row) {
    row.name.addListener(_changed);
    row.amount.addListener(_changed);
    return row;
  }

  void _addBill() {
    setState(() => _bills.add(_listen(_BillRow())));
  }

  void _removeBill(_BillRow row) {
    setState(() => _bills.remove(row));
    row.dispose();
    if (_bills.isEmpty) _addBill();
    _changed();
  }

  void _setPeople(int people) {
    if (people < 1) return;
    _people = people;
    _changed();
  }

  void _clear() {
    setState(() {
      _rent.clear();
      for (final bill in _bills) {
        bill.dispose();
      }
      _bills.clear();
      _people = (widget.memberCount ?? 1).clamp(1, 999);
    });
    _addBill();
    _changed();
  }

  RentCalculation get _calculation => RentCalculation(
    rent: _amount(_rent.text),
    bills: [
      for (final bill in _bills)
        if (_amount(bill.amount.text) > 0)
          (name: bill.name.text.trim(), amount: _amount(bill.amount.text)),
    ],
    people: _people,
    mealBalance: widget.mealBalance,
  );

  static String _monthName(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static double _amount(String text) {
    final value = double.tryParse(text.trim());
    return value == null || value < 0 ? 0 : value;
  }

  static String _taka(double value) =>
      '৳${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final calculation = _calculation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Calculator'),
        actions: [
          TextButton(onPressed: _clear, child: const Text('Clear')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _section('Rent', [
              TextField(
                controller: _rent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'My Rent',
                  prefixText: '৳ ',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _section('Shared Bills', [
              for (final row in _bills)
                Padding(
                  key: ObjectKey(row),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: row.name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Bill',
                            hintText: 'Wi-Fi',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: row.amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '৳',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove bill',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeBill(row),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addBill,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Bill'),
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.groups_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Shared By',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fewer people',
                    onPressed: _people > 1
                        ? () => _setPeople(_people - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$_people',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More people',
                    onPressed: () => _setPeople(_people + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 14),
            _ResultCard(
              monthName: _monthName(DateTime.now()),
              calculation: calculation,
              taka: _taka,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.monthName,
    required this.calculation,
    required this.taka,
  });

  final String monthName;
  final RentCalculation calculation;
  final String Function(double) taka;

  @override
  Widget build(BuildContext context) {
    final mealBalance = calculation.mealBalance;
    final toPay = calculation.toPay;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            monthName,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _line('Rent', taka(calculation.rent)),
          _line(
            calculation.people > 1
                ? 'Bills ${taka(calculation.billsTotal)} ÷ ${calculation.people}'
                : 'Bills',
            taka(calculation.billShare),
          ),
          _line('Fixed Cost', taka(calculation.fixedCost), isBold: true),
          if (mealBalance != null) ...[
            _line(
              mealBalance < 0 ? 'Meal Balance (Pay)' : 'Meal Balance (Get)',
              taka(mealBalance.abs().toDouble()),
            ),
            const Divider(color: Colors.white24, height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    toPay > 0
                        ? 'You Pay'
                        : toPay < 0
                        ? 'You Get'
                        : 'Settled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  taka(toPay.abs().toDouble()),
                  style: TextStyle(
                    color: toPay < 0 ? AppTheme.accent : Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool isBold = false}) {
    final style = TextStyle(
      color: isBold ? Colors.white : Colors.white70,
      fontSize: isBold ? 16 : 14,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
