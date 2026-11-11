import 'dart:convert';

/// A member's own month: rent, a share of the bills, and the meal
/// balance from the app. Worked out on the phone; nothing is saved to
/// the hostel.
class RentCalculation {
  const RentCalculation({
    required this.rent,
    required this.bills,
    required this.people,
    this.mealBalance,
  });

  final double rent;

  /// Bill name to its full amount, before it is shared.
  final List<({String name, double amount})> bills;

  /// How many share the bills; at least one.
  final int people;

  /// Positive when the member gets money back for meals, negative when
  /// they owe; null when it is not known.
  final int? mealBalance;

  double get billsTotal => bills.fold(0, (total, bill) => total + bill.amount);

  double get billShare => people > 0 ? billsTotal / people : billsTotal;

  /// Rent plus the member's share of the bills.
  double get fixedCost => rent + billShare;

  /// What the member hands over this month, in whole taka: positive to
  /// pay, negative to get back.
  int get toPay => (fixedCost - (mealBalance ?? 0)).round();
}

/// What the phone remembers between visits.
class RentCalculatorMemory {
  const RentCalculatorMemory._();

  static const key = 'rentCalculator';

  static String encode({
    required String rent,
    required String people,
    required List<({String name, String amount})> bills,
  }) => jsonEncode({
    'rent': rent,
    'people': people,
    'bills': [
      for (final bill in bills) {'name': bill.name, 'amount': bill.amount},
    ],
  });

  /// Null when nothing usable was saved.
  static ({
    String rent,
    String people,
    List<({String name, String amount})> bills,
  })?
  decode(String? saved) {
    if (saved == null || saved.isEmpty) return null;
    try {
      final data = jsonDecode(saved);
      if (data is! Map) return null;
      final bills = <({String name, String amount})>[];
      for (final bill in data['bills'] as List? ?? const []) {
        if (bill is! Map) continue;
        bills.add((
          name: bill['name'] as String? ?? '',
          amount: bill['amount'] as String? ?? '',
        ));
      }
      return (
        rent: data['rent'] as String? ?? '',
        people: data['people'] as String? ?? '',
        bills: bills,
      );
    } catch (_) {
      return null;
    }
  }
}
