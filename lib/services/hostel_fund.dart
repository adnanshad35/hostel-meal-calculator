import 'fixed_costs.dart';
import 'monthly_calculator.dart';

/// Money a member handed to the hostel fund, recorded by an admin.
class FundDeposit {
  const FundDeposit({
    this.id = '',
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.date,
  });

  final String id;
  final String memberId;
  final String memberName;
  final double amount;
  final DateTime? date;
}

/// The hostel fund for one month: what was collected, what was spent
/// from it, and what each member put in or paid for shared bills.
class FundSummary {
  const FundSummary({
    required this.deposits,
    required this.depositsByMember,
    required this.billsPaidByMember,
    required this.memberBills,
    this.upcomingBills = const [],
    required this.collected,
    required this.spent,
  });

  /// This month's deposits, newest first.
  final List<FundDeposit> deposits;

  final Map<String, double> depositsByMember;

  /// What each member paid from their own pocket for the share costs
  /// in [memberBills].
  final Map<String, double> billsPaidByMember;

  /// The share costs counted in this month: the ones members entered
  /// as expenses during the month before. They are divided among the
  /// members together with the bills the admin set.
  final List<SharedBill> memberBills;

  /// The share costs entered during this month. They are not counted
  /// yet; they go into next month's calculation.
  final List<SharedBill> upcomingBills;

  final double collected;

  /// Paid out of the fund for the expenses entered this month.
  final double spent;

  double get balance => collected - spent;

  /// False for a hostel that does not collect money in advance.
  bool get isUsed => collected > 0 || spent > 0;
}

class FundCalculator {
  FundCalculator._();

  static bool _inMonth(DateTime? date, DateTime month) {
    if (date == null) return false;

    final firstDay = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);

    return !date.isBefore(firstDay) && date.isBefore(nextMonth);
  }

  static FundSummary summarize({
    required DateTime month,
    required Iterable<FundDeposit> deposits,
    required Iterable<ExpenseRecord> expenses,
  }) {
    final monthDeposits = [
      for (final deposit in deposits)
        if (_inMonth(deposit.date, month) && deposit.amount > 0) deposit,
    ]..sort((a, b) => b.date!.compareTo(a.date!));

    final depositsByMember = <String, double>{};
    double collected = 0;

    for (final deposit in monthDeposits) {
      depositsByMember[deposit.memberId] =
          (depositsByMember[deposit.memberId] ?? 0) + deposit.amount;
      collected += deposit.amount;
    }

    final billsPaidByMember = <String, double>{};
    final memberBills = <SharedBill>[];
    final upcomingBills = <SharedBill>[];
    double spent = 0;

    // A share cost is settled a month late: one entered in September
    // is divided among the members in October's calculation.
    final previousMonth = DateTime(month.year, month.month - 1);

    SharedBill asBill(ExpenseRecord expense) {
      final name = expense.name?.trim() ?? '';
      final payer = expense.pocketPart <= 0
          ? 'from fund'
          : 'paid by ${expense.paidByName?.trim() ?? 'a member'}';

      return SharedBill(
        name: '${name.isEmpty ? 'Bill' : name} ($payer)',
        amount: expense.amount,
      );
    }

    for (final expense in expenses) {
      if (expense.amount <= 0) continue;

      // The cash left the fund in the month the expense was made.
      if (_inMonth(expense.date, month)) {
        spent += expense.fundPart;
        if (expense.isBill) upcomingBills.add(asBill(expense));
      }

      if (!expense.isBill || !_inMonth(expense.date, previousMonth)) continue;

      // The member who paid is credited in the same month the share
      // cost is charged.
      final payerId = expense.paidById;
      if (payerId != null && expense.pocketPart > 0) {
        billsPaidByMember[payerId] =
            (billsPaidByMember[payerId] ?? 0) + expense.pocketPart;
      }

      memberBills.add(asBill(expense));
    }

    return FundSummary(
      deposits: monthDeposits,
      depositsByMember: depositsByMember,
      billsPaidByMember: billsPaidByMember,
      memberBills: memberBills,
      upcomingBills: upcomingBills,
      collected: collected,
      spent: spent,
    );
  }
}

/// What the expense form saves for one entry.
///
/// A meal cost and a share cost are counted differently, so they are
/// saved as separate records: the meal cost as a meal expense, which
/// goes into the meal rate, and each share cost as a shared bill,
/// which is divided with the fixed costs.
class ExpenseEntry {
  const ExpenseEntry._({required this.meal, required this.bills});

  /// The meal expense. Saved only when its amount is above zero.
  final Map<String, dynamic> meal;

  /// One record per share cost.
  final List<Map<String, dynamic>> bills;

  static String _short(String text, int length) {
    return text.length > length ? text.substring(0, length) : text;
  }

  /// [fromFund] is how much of the whole entry the hostel fund paid.
  /// It is counted against the meal cost first, and only what is left
  /// of it against the share costs.
  static ExpenseEntry split({
    required String name,
    String details = '',
    required double mealCost,
    List<({String name, double amount})> shareCosts = const [],
    required double fromFund,
  }) {
    var fundLeft = fromFund < 0 ? 0.0 : fromFund;

    double takeFromFund(double amount) {
      final used = fundLeft < amount ? fundLeft : amount;
      fundLeft -= used;
      return used;
    }

    return ExpenseEntry._(
      meal: {
        'name': _short(name, 60),
        'amount': mealCost,
        'fromFund': takeFromFund(mealCost),
        'category': 'meal',
        'fundNote': '',
        'pocketNote': _short(details, 500),
      },
      bills: [
        for (final share in shareCosts)
          {
            'name': _short(share.name, 60),
            'amount': share.amount,
            'fromFund': takeFromFund(share.amount),
            'category': 'bill',
            'fundNote': '',
            'pocketNote': '',
          },
      ],
    );
  }
}
