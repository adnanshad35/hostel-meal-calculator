import 'monthly_calculator.dart';

/// A monthly bill shared equally by the members, such as Wi-Fi,
/// electricity, or the chef's salary.
class SharedBill {
  const SharedBill({required this.name, required this.amount});

  final String name;
  final double amount;

  Map<String, dynamic> toData() => {'name': name, 'amount': amount};
}

/// What one member finally pays or receives for the month, once rent
/// and shared bills are added to their meal balance.
class MemberSettlement {
  const MemberSettlement({
    required this.id,
    required this.name,
    required this.mealBalance,
    required this.rent,
    required this.billShare,
  });

  final String id;
  final String name;

  /// Meal balance from the monthly calculation. Positive when the
  /// member should receive money, negative when they owe.
  final double mealBalance;

  final double rent;
  final double billShare;

  /// Positive when the member should receive, negative when they owe.
  double get exactTotal => mealBalance - rent - billShare;

  /// [exactTotal] rounded to a whole taka.
  int get finalTotal => exactTotal.round();
}

/// The rent and shared bills that apply to a month, and the month
/// they were saved in.
class FixedCosts {
  const FixedCosts({
    required this.monthKey,
    required this.rents,
    required this.bills,
  });

  /// The month these figures were entered for (`YYYY-MM`).
  final String monthKey;
  final Map<String, double> rents;
  final List<SharedBill> bills;

  bool get isEmpty => rents.isEmpty && bills.isEmpty;
}

/// Adds rent and equally shared bills to the monthly meal calculation.
///
/// Rent is entered per member. Shared bills are divided equally among
/// the current members; former members are not charged a share.
class FixedCostsCalculator {
  FixedCostsCalculator._();

  static double totalBills(List<SharedBill> bills) {
    return bills.fold<double>(0, (total, bill) => total + bill.amount);
  }

  /// Each current member's equal share of the shared bills.
  static double billShare({
    required List<MemberCalculation> members,
    required List<SharedBill> bills,
  }) {
    final payers = members.where((member) => !member.isFormer).length;
    if (payers == 0) return 0;

    return totalBills(bills) / payers;
  }

  static List<MemberSettlement> settle({
    required List<MemberCalculation> members,
    required Map<String, double> rents,
    required List<SharedBill> bills,
  }) {
    final share = billShare(members: members, bills: bills);

    return [
      for (final member in members)
        MemberSettlement(
          id: member.id,
          name: member.name,
          mealBalance: member.exactBalance,
          rent: rents[member.id] ?? 0,
          billShare: member.isFormer ? 0 : share,
        ),
    ];
  }

  /// The fixed costs that apply to [monthKey]: the ones saved for that
  /// month, or else the most recent ones saved before it. Fixed costs
  /// therefore carry forward until an admin changes or resets them,
  /// and editing a later month never changes an earlier one.
  ///
  /// [settingsByMonth] maps `YYYY-MM` keys to saved monthly settings.
  /// Returns null when nothing has been saved up to that month.
  static FixedCosts? resolve(
    Map<String, Map<String, dynamic>> settingsByMonth,
    String monthKey,
  ) {
    final candidates = settingsByMonth.keys
        .where((key) => key.compareTo(monthKey) <= 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    for (final key in candidates) {
      final data = settingsByMonth[key]!;

      // A month without these fields never had fixed costs saved.
      if (!data.containsKey('rents') && !data.containsKey('sharedBills')) {
        continue;
      }

      return FixedCosts(
        monthKey: key,
        rents: readRents(data['rents']),
        bills: readBills(data['sharedBills']),
      );
    }

    return null;
  }

  /// Reads the saved `rents` map, ignoring anything that is not a
  /// positive number.
  static Map<String, double> readRents(Object? data) {
    if (data is! Map) return const {};

    return {
      for (final entry in data.entries)
        if (entry.key is String &&
            entry.value is num &&
            (entry.value as num) > 0)
          entry.key as String: (entry.value as num).toDouble(),
    };
  }

  /// Reads the saved `sharedBills` list, ignoring malformed entries.
  static List<SharedBill> readBills(Object? data) {
    if (data is! List) return const [];

    return [
      for (final item in data)
        if (item is Map &&
            item['name'] is String &&
            item['amount'] is num &&
            (item['amount'] as num) > 0)
          SharedBill(
            name: (item['name'] as String).trim(),
            amount: (item['amount'] as num).toDouble(),
          ),
    ];
  }
}
