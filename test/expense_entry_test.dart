import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/fixed_costs.dart';
import 'package:hostel_meal_calculator/services/fund_service.dart';
import 'package:hostel_meal_calculator/services/hostel_fund.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

/// Follows an entry from the expense form all the way into the monthly
/// calculation: what the form saves, read back the way the app reads
/// it, then calculated.
void main() {
  final month = DateTime(2026, 10);

  // A share cost is settled in the month after it was entered.
  final nextMonth = DateTime(2026, 11);

  const members = [
    CalcMember(id: 'a', name: 'Asif'),
    CalcMember(id: 'b', name: 'Babu'),
  ];

  // Five meals each.
  final meals = [
    for (final member in members)
      MealRecord(
        id: '${member.id}_2026-10-05',
        userId: member.id,
        dateKey: '2026-10-05',
        lunch: 5,
      ),
  ];

  /// The saved records of [entry], as the app reads them back.
  List<ExpenseRecord> saved(ExpenseEntry entry) {
    final common = <String, dynamic>{
      'date': Timestamp.fromDate(DateTime(2026, 10, 5)),
      'paidById': 'a',
      'paidByName': 'Asif',
    };

    return [
      if ((entry.meal['amount'] as double) > 0)
        FundService.expenseRecord({...entry.meal, ...common}),
      for (final bill in entry.bills)
        FundService.expenseRecord({...bill, ...common}),
    ];
  }

  MonthlyCalculation calculate(List<ExpenseRecord> expenses) {
    return MonthlyCalculator.calculate(
      month: month,
      members: members,
      meals: meals,
      expenses: expenses,
      minimumMeals: 0,
      shopDue: 0,
    );
  }

  FundSummary fundOf(List<ExpenseRecord> expenses, {DateTime? at}) {
    return FundCalculator.summarize(
      month: at ?? month,
      deposits: const [],
      expenses: expenses,
    );
  }

  test('a meal cost is saved as a meal expense', () {
    final entry = ExpenseEntry.split(
      name: 'Bazar',
      details: 'Onion 2kg 80tk',
      mealCost: 1000,
      fromFund: 0,
    );

    expect(entry.meal['category'], 'meal');
    expect(entry.meal['name'], 'Bazar');
    expect(entry.meal['pocketNote'], 'Onion 2kg 80tk');
    expect(entry.bills, isEmpty);

    final expenses = saved(entry);
    final result = calculate(expenses);

    // All of it is meal cost, and none of it is a shared bill.
    expect(result.totalExpense, 1000);
    expect(result.mealRate, 100);
    expect(fundOf(expenses).memberBills, isEmpty);
  });

  test('a share cost is saved as a shared bill, not a meal expense', () {
    final entry = ExpenseEntry.split(
      name: '',
      mealCost: 0,
      shareCosts: [(name: 'Water bill', amount: 200)],
      fromFund: 0,
    );

    expect(entry.bills.single['category'], 'bill');
    expect(entry.bills.single['name'], 'Water bill');

    final expenses = saved(entry);
    expect(expenses.single.isBill, isTrue);

    final result = calculate(expenses);

    // Nothing reaches the meal rate.
    expect(result.totalExpense, 0);
    expect(result.mealRate, 0);
    expect(result.members.every((member) => member.spending == 0), isTrue);

    // In its own month it is only waiting.
    final now = fundOf(expenses);
    expect(now.memberBills, isEmpty);
    expect(now.billsPaidByMember, isEmpty);
    expect(FixedCostsCalculator.totalBills(now.upcomingBills), 200);

    // Next month it is a shared bill, credited to the member who paid.
    final fund = fundOf(expenses, at: nextMonth);
    expect(FixedCostsCalculator.totalBills(fund.memberBills), 200);
    expect(fund.billsPaidByMember, {'a': 200.0});
    expect(fund.upcomingBills, isEmpty);
  });

  test('one entry with both goes to both places, never mixed', () {
    // 2,500 of meals and a 200 water bill; 2,000 came from the fund.
    final entry = ExpenseEntry.split(
      name: 'Bazar',
      mealCost: 2500,
      shareCosts: [(name: 'Water bill', amount: 200)],
      fromFund: 2000,
    );

    // The fund's money is counted against the meal cost first.
    expect(entry.meal['fromFund'], 2000);
    expect(entry.bills.single['fromFund'], 0);

    final expenses = saved(entry);
    expect(expenses.length, 2);

    final result = calculate(expenses);
    final fund = fundOf(expenses, at: nextMonth);

    // Meal side: 2,500 only.
    expect(result.totalExpense, 2500);
    expect(result.fundPaidExpenses, 2000);
    expect(result.memberPaidExpenses, 500);
    expect(result.mealRate, 250);

    // Fixed side: 200 only, split between the two members.
    expect(FixedCostsCalculator.totalBills(fund.memberBills), 200);
    expect(
      FixedCostsCalculator.billShare(
        members: result.members,
        bills: fund.memberBills,
      ),
      100,
    );
    expect(fund.billsPaidByMember, {'a': 200.0});
    // The cash left the fund in the month it was spent.
    expect(fundOf(expenses).spent, 2000);

    // Together they are the 2,700 that was spent.
    expect(
      result.totalExpense + FixedCostsCalculator.totalBills(fund.memberBills),
      2700,
    );
  });

  test('fund money left after the meal cost goes to the share cost', () {
    final entry = ExpenseEntry.split(
      name: 'Bazar',
      mealCost: 500,
      shareCosts: [(name: 'Gas', amount: 900)],
      fromFund: 800,
    );

    expect(entry.meal['fromFund'], 500);
    expect(entry.bills.single['fromFund'], 300);

    final expenses = saved(entry);

    expect(fundOf(expenses).spent, 800);
    // Asif paid the other 600 of the gas himself.
    expect(fundOf(expenses, at: nextMonth).billsPaidByMember, {'a': 600.0});
    expect(calculate(expenses).memberPaidExpenses, 0);
  });

  test('long text is cut to what can be saved', () {
    final entry = ExpenseEntry.split(
      name: 'n' * 80,
      details: 'd' * 700,
      mealCost: 10,
      shareCosts: [(name: 's' * 80, amount: 5)],
      fromFund: 0,
    );

    expect((entry.meal['name'] as String).length, 60);
    expect((entry.meal['pocketNote'] as String).length, 500);
    expect((entry.bills.single['name'] as String).length, 60);
  });
}
