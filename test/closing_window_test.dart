import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/hostel_settings.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  group('closing window for minimum meals and shop due', () {
    final october = DateTime(2026, 10);

    bool openOn(DateTime now) {
      return MonthlyCalculator.isClosingWindowOpen(october, now);
    }

    test('is closed for most of the month', () {
      expect(openOn(DateTime(2026, 10, 1)), isFalse);
      expect(openOn(DateTime(2026, 10, 14, 12)), isFalse);
      expect(openOn(DateTime(2026, 10, 24, 23, 59)), isFalse);
    });

    test('opens on the 25th and stays open through the 5th', () {
      expect(openOn(DateTime(2026, 10, 25)), isTrue);
      expect(openOn(DateTime(2026, 10, 31, 20)), isTrue);
      expect(openOn(DateTime(2026, 11, 1)), isTrue);
      expect(openOn(DateTime(2026, 11, 5, 23, 59)), isTrue);
    });

    test('closes again on the 6th', () {
      expect(openOn(DateTime(2026, 11, 6)), isFalse);
      expect(openOn(DateTime(2026, 11, 26)), isFalse);
    });

    test('each month has its own window', () {
      // On 3 November, October can still be closed out, but it is too
      // early for November.
      final now = DateTime(2026, 11, 3);

      expect(MonthlyCalculator.isClosingWindowOpen(october, now), isTrue);
      expect(
        MonthlyCalculator.isClosingWindowOpen(DateTime(2026, 11), now),
        isFalse,
      );
    });

    test('works across the end of the year', () {
      final december = DateTime(2026, 12);

      expect(
        MonthlyCalculator.isClosingWindowOpen(december, DateTime(2027, 1, 4)),
        isTrue,
      );
      expect(
        MonthlyCalculator.isClosingWindowOpen(december, DateTime(2027, 1, 6)),
        isFalse,
      );
    });
  });

  test('special permission is off unless an admin turns it on', () {
    expect(HostelSettings.fromGroupData(null).specialPermission, isFalse);
    expect(
      HostelSettings.fromGroupData({
        'settings': {'fixedCostsEnabled': false},
      }).specialPermission,
      isFalse,
    );

    final turnedOn = const HostelSettings().copyWith(specialPermission: true);
    expect(
      HostelSettings.fromGroupData({'settings': turnedOn.toMap()})
          .specialPermission,
      isTrue,
    );
  });

  test('total meals is what was eaten; the minimum only raises the charge', () {
    final result = MonthlyCalculator.calculate(
      month: DateTime(2026, 10),
      members: const [
        CalcMember(id: 'a', name: 'Asif'),
        CalcMember(id: 'b', name: 'Babu'),
      ],
      meals: const [
        MealRecord(
          id: 'a_2026-10-01',
          userId: 'a',
          dateKey: '2026-10-01',
          lunch: 15,
          dinner: 15,
        ),
        MealRecord(
          id: 'b_2026-10-01',
          userId: 'b',
          dateKey: '2026-10-01',
          lunch: 5,
          dinner: 5,
        ),
      ],
      expenses: [
        ExpenseRecord(paidById: 'a', date: DateTime(2026, 10, 2), amount: 2500),
      ],
      minimumMeals: 20,
      shopDue: 0,
    );

    // 30 and 10 were eaten. Babu is charged the minimum of 20.
    expect(result.totalActualMeals, 40);
    expect(result.totalMealNumber, 50);
    // The rate is spread over the charged meals.
    expect(result.mealRate, 50);
  });

  test('without a minimum the two totals are the same', () {
    final result = MonthlyCalculator.calculate(
      month: DateTime(2026, 10),
      members: const [CalcMember(id: 'a', name: 'Asif')],
      meals: const [
        MealRecord(
          id: 'a_2026-10-01',
          userId: 'a',
          dateKey: '2026-10-01',
          lunch: 3,
          dinner: 4,
        ),
      ],
      expenses: const [],
      minimumMeals: 0,
      shopDue: 0,
    );

    expect(result.totalActualMeals, 7);
    expect(result.totalMealNumber, 7);
  });
}
