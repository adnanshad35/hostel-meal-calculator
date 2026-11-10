import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/best_manager.dart';
import 'package:hostel_meal_calculator/services/duty_roster.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

DutyTurn _turn(String id, String from, String to) =>
    DutyTurn(memberId: id, memberName: id, fromDate: from, toDate: to);

/// Ten meals a day, every day of November 2026.
final _meals = [
  for (var day = 1; day <= 30; day++)
    MealRecord(
      id: 'x_$day',
      userId: 'x',
      dateKey: '2026-11-${day.toString().padLeft(2, '0')}',
      lunch: 5,
      dinner: 5,
    ),
];

ExpenseRecord _spent(int day, double amount) =>
    ExpenseRecord(paidById: 'x', date: DateTime(2026, 11, day), amount: amount);

void main() {
  final month = DateTime(2026, 11);

  test('the cheapest finished turn is best, against the average', () {
    final report = BestManager.of(
      month: month,
      roster: DutyRoster([
        _turn('A', '2026-11-01', '2026-11-05'),
        _turn('B', '2026-11-06', '2026-11-10'),
      ]),
      meals: _meals,
      expenses: [_spent(2, 3000), _spent(7, 2000)],
      today: DateTime(2026, 11, 11),
    )!;

    // A: 3000 / 50 meals, B: 2000 / 50 meals; 5000 / 100 on average.
    expect(report.best!.memberName, 'B');
    expect(report.turns.map((turn) => turn.rate), [40, 60]);
    expect(report.averageRate, 50);
    expect(report.belowAverage(report.best!), 10);
    expect(report.belowAverage(report.turns.last), -10);
  });

  test('a turn still running or shorter than three days does not count', () {
    final report = BestManager.of(
      month: month,
      roster: DutyRoster([
        _turn('Short', '2026-11-01', '2026-11-02'),
        _turn('Running', '2026-11-03', '2026-11-12'),
      ]),
      meals: _meals,
      expenses: [_spent(1, 100)],
      today: DateTime(2026, 11, 11),
    );

    expect(report, isNull);
  });

  test('only the days of a turn inside the month count', () {
    final report = BestManager.of(
      month: month,
      roster: DutyRoster([_turn('A', '2026-10-28', '2026-11-04')]),
      meals: _meals,
      expenses: [_spent(3, 1200)],
      today: DateTime(2026, 12, 1),
    )!;

    expect(report.best!.fromDate, '2026-11-01');
    expect(report.best!.days, 4);
    expect(report.best!.rate, 30);
  });
}
