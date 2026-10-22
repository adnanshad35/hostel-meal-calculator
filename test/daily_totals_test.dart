import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/daily_totals.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  final october = DateTime(2026, 10);

  test('meals add lunch and dinner per day of the month', () {
    final totals = DailyTotals.meals(october, const [
      MealRecord(id: 'a', dateKey: '2026-10-01', lunch: 1, dinner: 1),
      MealRecord(id: 'b', dateKey: '2026-10-01', lunch: 1, dinner: 0),
      MealRecord(id: 'c', dateKey: '2026-10-31', lunch: 0.5, dinner: 1),
    ]);

    expect(totals, hasLength(31));
    expect(totals.first, 3);
    expect(totals.last, 1.5);
    expect(totals[14], 0);
  });

  test('meals of another month or without a date are left out', () {
    final totals = DailyTotals.meals(october, const [
      MealRecord(id: 'a', dateKey: '2026-09-30', lunch: 1, dinner: 1),
      MealRecord(id: 'b', lunch: 1, dinner: 1),
    ]);

    expect(totals.every((total) => total == 0), isTrue);
  });

  test('expenses add up per day and skip other months', () {
    final totals = DailyTotals.expenses(october, [
      ExpenseRecord(date: DateTime(2026, 10, 5, 9), amount: 400),
      ExpenseRecord(date: DateTime(2026, 10, 5, 18), amount: 250),
      ExpenseRecord(date: DateTime(2026, 11, 1), amount: 999),
      const ExpenseRecord(amount: 50),
    ]);

    expect(totals, hasLength(31));
    expect(totals[4], 650);
    expect(totals.fold<double>(0, (a, b) => a + b), 650);
  });
}
