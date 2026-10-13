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
    required this.collected,
    required this.spent,
  });

  /// This month's deposits, newest first.
  final List<FundDeposit> deposits;

  final Map<String, double> depositsByMember;

  /// What each member paid from their own pocket for shared bills
  /// they entered as expenses.
  final Map<String, double> billsPaidByMember;

  /// Shared bills entered as expenses, to be divided among the
  /// members together with the bills the admin set.
  final List<SharedBill> memberBills;

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
    double spent = 0;

    for (final expense in expenses) {
      if (!_inMonth(expense.date, month) || expense.amount <= 0) continue;

      spent += expense.fundPart;

      if (!expense.isBill) continue;

      final payerId = expense.paidById;
      if (payerId != null && expense.pocketPart > 0) {
        billsPaidByMember[payerId] =
            (billsPaidByMember[payerId] ?? 0) + expense.pocketPart;
      }

      final name = expense.name?.trim() ?? '';
      final payer = expense.pocketPart <= 0
          ? 'from fund'
          : 'paid by ${expense.paidByName?.trim() ?? 'a member'}';

      memberBills.add(
        SharedBill(
          name: '${name.isEmpty ? 'Bill' : name} ($payer)',
          amount: expense.amount,
        ),
      );
    }

    return FundSummary(
      deposits: monthDeposits,
      depositsByMember: depositsByMember,
      billsPaidByMember: billsPaidByMember,
      memberBills: memberBills,
      collected: collected,
      spent: spent,
    );
  }
}
