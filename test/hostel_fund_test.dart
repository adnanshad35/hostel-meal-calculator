import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/fixed_costs.dart';
import 'package:hostel_meal_calculator/services/hostel_fund.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  final month = DateTime(2026, 10);
  final day = DateTime(2026, 10, 5);

  const members = [
    CalcMember(id: 'a', name: 'Asif'),
    CalcMember(id: 'b', name: 'Babu'),
    CalcMember(id: 'c', name: 'Chand'),
    CalcMember(id: 'd', name: 'Dipu'),
  ];

  // Everyone gives 3,000 to the fund. Asif then shops for 2,500, using
  // 2,000 from the fund and 500 of his own, and pays a 200 water bill.
  final deposits = [
    for (final member in members)
      FundDeposit(
        memberId: member.id,
        memberName: member.name,
        amount: 3000,
        date: DateTime(2026, 10, 1),
      ),
  ];

  final expenses = [
    ExpenseRecord(
      name: 'Market',
      paidById: 'a',
      paidByName: 'Asif',
      date: day,
      amount: 2500,
      fromFund: 2000,
    ),
    ExpenseRecord(
      name: 'Water',
      paidById: 'a',
      paidByName: 'Asif',
      date: day,
      amount: 200,
      isBill: true,
    ),
  ];

  // Ten meals each, so the meal rate is 2,500 / 40.
  final meals = [
    for (final member in members)
      MealRecord(
        id: '${member.id}_2026-10-05',
        userId: member.id,
        dateKey: '2026-10-05',
        lunch: 5,
        dinner: 5,
      ),
  ];

  MonthlyCalculation calculate() {
    return MonthlyCalculator.calculate(
      month: month,
      members: members,
      meals: meals,
      expenses: expenses,
      minimumMeals: 0,
      shopDue: 0,
    );
  }

  test('an expense splits into fund money and pocket money', () {
    const partly = ExpenseRecord(amount: 2500, fromFund: 2000);
    expect(partly.fundPart, 2000);
    expect(partly.pocketPart, 500);

    const fully = ExpenseRecord(amount: 300, fromFund: 300);
    expect(fully.pocketPart, 0);

    // Bad data never credits more than the expense.
    const tooMuch = ExpenseRecord(amount: 300, fromFund: 900);
    expect(tooMuch.fundPart, 300);
    expect(tooMuch.pocketPart, 0);

    const negative = ExpenseRecord(amount: 300, fromFund: -50);
    expect(negative.fundPart, 0);
    expect(negative.pocketPart, 300);
  });

  test('fund money raises the meal rate but credits nobody', () {
    final result = calculate();

    expect(result.totalExpense, 2500);
    expect(result.memberPaidExpenses, 500);
    expect(result.fundPaidExpenses, 2000);
    expect(result.mealRate, 62.5);

    final asif = result.members.firstWhere((member) => member.id == 'a');
    expect(asif.spending, 500);
    expect(asif.exactBalance, 500 - 625);
  });

  test('a shared bill stays out of the meal rate', () {
    // 2,700 was spent, but only the 2,500 of food is meal cost.
    expect(calculate().totalExpense, 2500);
  });

  test('the fund keeps what was collected minus what was spent', () {
    final fund = FundCalculator.summarize(
      month: month,
      deposits: deposits,
      expenses: expenses,
    );

    expect(fund.collected, 12000);
    expect(fund.spent, 2000);
    expect(fund.balance, 10000);
    expect(fund.isUsed, isTrue);
    expect(fund.depositsByMember['b'], 3000);

    // The water bill waits for next month.
    expect(fund.memberBills, isEmpty);
    expect(fund.billsPaidByMember, isEmpty);
    expect(fund.upcomingBills.single.amount, 200);
    expect(fund.upcomingBills.single.name, 'Water (paid by Asif)');
  });

  test('a share cost is settled in the month after it was entered', () {
    final november = FundCalculator.summarize(
      month: DateTime(2026, 11),
      deposits: deposits,
      expenses: expenses,
    );

    expect(november.memberBills.single.amount, 200);
    expect(november.memberBills.single.name, 'Water (paid by Asif)');
    expect(november.billsPaidByMember, {'a': 200.0});
    expect(november.upcomingBills, isEmpty);
    // October's deposits and spending are not November's.
    expect(november.collected, 0);
    expect(november.spent, 0);

    // And it is gone again the month after.
    final december = FundCalculator.summarize(
      month: DateTime(2026, 12),
      deposits: deposits,
      expenses: expenses,
    );
    expect(december.memberBills, isEmpty);
    expect(december.billsPaidByMember, isEmpty);
  });

  test('the month closes: balances add up to the money left in the fund', () {
    final result = calculate();
    final fund = FundCalculator.summarize(
      month: month,
      deposits: deposits,
      expenses: expenses,
    );

    final settlements = FixedCostsCalculator.settle(
      members: result.members,
      rents: const {},
      bills: fund.memberBills,
      billsPaid: fund.billsPaidByMember,
      deposits: fund.depositsByMember,
    );

    final asif = settlements.firstWhere((item) => item.id == 'a');
    final babu = settlements.firstWhere((item) => item.id == 'b');

    // The water bill is settled next month, so October is meals only.
    // Asif: 3,000 + 500 paid, 625 of meals owed.
    expect(asif.exactTotal, 3500 - 625);
    // Babu: 3,000 paid, the same meals.
    expect(babu.exactTotal, 3000 - 625);

    final owedToMembers = settlements.fold<double>(
      0,
      (total, item) => total + item.exactTotal,
    );
    expect(owedToMembers, fund.balance);
  });

  test('a bill paid from the fund credits nobody', () {
    final fund = FundCalculator.summarize(
      month: month,
      deposits: const [],
      expenses: [
        ExpenseRecord(
          name: 'Gas',
          paidById: 'a',
          paidByName: 'Asif',
          date: day,
          amount: 900,
          fromFund: 900,
          isBill: true,
        ),
      ],
    );

    expect(fund.billsPaidByMember, isEmpty);
    expect(fund.spent, 900);
    expect(fund.upcomingBills.single.name, 'Gas (from fund)');
  });

  test('other months and undated records are ignored', () {
    final fund = FundCalculator.summarize(
      month: month,
      deposits: [
        FundDeposit(
          memberId: 'a',
          memberName: 'Asif',
          amount: 500,
          date: DateTime(2026, 9, 30),
        ),
        const FundDeposit(
          memberId: 'a',
          memberName: 'Asif',
          amount: 500,
          date: null,
        ),
        FundDeposit(
          memberId: 'a',
          memberName: 'Asif',
          amount: 700,
          date: DateTime(2026, 10, 31, 23),
        ),
      ],
      expenses: [
        ExpenseRecord(
          paidById: 'a',
          date: DateTime(2026, 11, 1),
          amount: 400,
          fromFund: 400,
        ),
      ],
    );

    expect(fund.collected, 700);
    expect(fund.spent, 0);
  });

  test('a hostel without a fund is calculated as before', () {
    final plain = [
      ExpenseRecord(paidById: 'a', date: day, amount: 2000),
      ExpenseRecord(paidById: 'b', date: day, amount: 400),
    ];

    final result = MonthlyCalculator.calculate(
      month: month,
      members: members,
      meals: meals,
      expenses: plain,
      minimumMeals: 0,
      shopDue: 0,
    );
    final fund = FundCalculator.summarize(
      month: month,
      deposits: const [],
      expenses: plain,
    );

    expect(fund.isUsed, isFalse);
    expect(fund.memberBills, isEmpty);
    expect(result.fundPaidExpenses, 0);
    expect(result.memberPaidExpenses, 2400);
    expect(result.totalExpense, 2400);

    final settlements = FixedCostsCalculator.settle(
      members: result.members,
      rents: const {},
      bills: const [],
    );
    expect(settlements.first.exactTotal, result.members.first.exactBalance);
  });
}
