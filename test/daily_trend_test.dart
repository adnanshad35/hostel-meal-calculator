import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/daily_trend.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  final october = DateTime(2026, 10);

  test('adds meals and cost up day by day', () {
    final trend = DailyTrend.build(
      month: october,
      days: 3,
      meals: const [
        MealRecord(id: '1', dateKey: '2026-10-01', lunch: 1, dinner: 1),
        MealRecord(id: '2', dateKey: '2026-10-03', lunch: 1),
      ],
      expenses: [
        ExpenseRecord(date: DateTime(2026, 10, 1), amount: 300),
        ExpenseRecord(date: DateTime(2026, 10, 2), amount: 150),
      ],
    );

    expect(trend.meals, [2, 2, 3]);
    expect(trend.cost, [300, 450, 450]);
    expect(trend.rateAt(0), 150);
    expect(trend.rateAt(2), 150);
  });

  test('leaves out other months and days after the last one', () {
    final trend = DailyTrend.build(
      month: october,
      days: 2,
      meals: const [
        MealRecord(id: '1', dateKey: '2026-09-30', lunch: 1),
        MealRecord(id: '2', dateKey: '2026-10-05', lunch: 1),
      ],
      expenses: [ExpenseRecord(date: DateTime(2026, 11, 1), amount: 100)],
    );

    expect(trend.meals, [0, 0]);
    expect(trend.isEmpty, isTrue);
  });

  test('the rate is zero before the first meal', () {
    final trend = DailyTrend.build(
      month: october,
      days: 1,
      meals: const [],
      expenses: [ExpenseRecord(date: DateTime(2026, 10, 1), amount: 100)],
    );

    expect(trend.rateAt(0), 0);
    expect(trend.isEmpty, isFalse);
  });
}
