import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/month_archive.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  final october = DateTime(2026, 10);
  final september = DateTime(2026, 9);

  group('MonthLock', () {
    test('a month is open while it runs', () {
      expect(MonthLock.canEdit(october, DateTime(2026, 10, 23)), isTrue);
      expect(MonthLock.isFinal(october, DateTime(2026, 10, 23)), isFalse);
    });

    test('last month stays open for the first week', () {
      expect(MonthLock.canEdit(october, DateTime(2026, 11, 7)), isTrue);
      expect(MonthLock.canEdit(october, DateTime(2026, 11, 8)), isFalse);
      expect(MonthLock.isFinal(october, DateTime(2026, 11, 8)), isTrue);
    });

    test('earlier months are never open', () {
      expect(MonthLock.canEdit(september, DateTime(2026, 11, 1)), isFalse);
    });

    test('the first open day moves with the first week', () {
      expect(
        MonthLock.firstEditableDay(DateTime(2026, 11, 3)),
        DateTime(2026, 10),
      );
      expect(
        MonthLock.firstEditableDay(DateTime(2026, 11, 8)),
        DateTime(2026, 11),
      );
    });

    test('works across the new year', () {
      final december = DateTime(2026, 12);

      expect(MonthLock.canEdit(december, DateTime(2027, 1, 5)), isTrue);
      expect(
        MonthLock.firstEditableDay(DateTime(2027, 1, 5)),
        DateTime(2026, 12),
      );
    });

    test('keeps last month in full and older months as a summary', () {
      final now = DateTime(2026, 11, 20);

      expect(MonthLock.isSummaryOnly(october, now), isFalse);
      expect(MonthLock.isSummaryOnly(september, now), isTrue);
    });
  });

  group('MonthSummary', () {
    test('reads back the calculation it saved', () {
      final result = MonthlyCalculator.calculate(
        month: october,
        members: const [
          CalcMember(id: 'a', name: 'Adnan'),
          CalcMember(id: 'b', name: 'Bashir'),
        ],
        meals: const [
          MealRecord(id: '1', userId: 'a', dateKey: '2026-10-01', lunch: 1),
          MealRecord(id: '2', userId: 'b', dateKey: '2026-10-01', dinner: 1),
        ],
        expenses: [
          ExpenseRecord(
            paidById: 'a',
            date: DateTime(2026, 10, 2),
            amount: 300,
          ),
        ],
        minimumMeals: 0,
        shopDue: 100,
      );

      final saved = MonthSummary.fromSettings({
        'summary': MonthSummary.toMap(result, isFinal: true),
      })!;

      expect(saved.mealRate, result.mealRate);
      expect(saved.totalExpense, 400);
      expect(saved.totalActualMeals, 2);
      expect(saved.members.map((member) => member.name), ['Adnan', 'Bashir']);
      expect(saved.members.first.finalBalance, 100);
      expect(saved.members.last.finalBalance, -200);
    });

    test('knows when a summary is final', () {
      expect(MonthSummary.isFinal(null), isFalse);
      expect(
        MonthSummary.isFinal({
          'summary': {'isFinal': false},
        }),
        isFalse,
      );
      expect(
        MonthSummary.isFinal({
          'summary': {'isFinal': true},
        }),
        isTrue,
      );
      expect(MonthSummary.fromSettings({'minimumMeals': 0}), isNull);
    });
  });
}
