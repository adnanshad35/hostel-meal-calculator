import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/dashboard_summary.dart';
import 'package:hostel_meal_calculator/services/meal_cancellation.dart';
import 'package:hostel_meal_calculator/services/meal_plan.dart';
import 'package:hostel_meal_calculator/services/month_rules.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

const _adnan = CalcMember(id: 'adnan', name: 'Adnan');
const _rahim = CalcMember(id: 'rahim', name: 'Rahim');

final _november = DateTime(2026, 11);

MealRecord _meal(
  String userId,
  String dateKey, {
  double lunch = 0,
  double dinner = 0,
}) {
  return MealRecord(
    id: '${userId}_$dateKey',
    userId: userId,
    dateKey: dateKey,
    lunch: lunch,
    dinner: dinner,
  );
}

MealCancellations _cancel(Map<String, Map<String, bool>> days) {
  return MealCancellations.fromSettings({MealCancellations.field: days});
}

void main() {
  group('MealCancellations', () {
    test('reads the saved days, earliest first', () {
      final cancellations = _cancel({
        '2026-11-20': {'dinner': true},
        '2026-11-12': {'lunch': true, 'dinner': true},
      });

      expect(cancellations.days.map((day) => day.dateKey), [
        '2026-11-12',
        '2026-11-20',
      ]);
      expect(cancellations.dayOf('2026-11-12')!.label, 'Lunch & Dinner');
      expect(cancellations.dayOf('2026-11-20')!.label, 'Dinner');
      expect(cancellations.isLunchCancelled('2026-11-20'), isFalse);
      expect(cancellations.isDinnerCancelled('2026-11-20'), isTrue);
    });

    test('ignores missing, malformed and empty entries', () {
      expect(MealCancellations.fromSettings(null).isEmpty, isTrue);
      expect(MealCancellations.fromSettings({}).isEmpty, isTrue);
      expect(
        MealCancellations.fromSettings({MealCancellations.field: 'x'}).isEmpty,
        isTrue,
      );
      expect(
        _cancel({
          '2026-11-12': {'lunch': false, 'dinner': false},
        }).isEmpty,
        isTrue,
      );
    });

    test('counts only the cancelled meal of that day as zero', () {
      final cancellations = _cancel({
        '2026-11-12': {'lunch': true},
      });

      final meals = cancellations.applyAll([
        _meal('adnan', '2026-11-12', lunch: 2, dinner: 1),
        _meal('adnan', '2026-11-13', lunch: 1, dinner: 1),
      ]);

      expect(meals[0].lunch, 0);
      expect(meals[0].dinner, 1);
      expect(meals[1].lunch, 1);
      expect(meals[1].dinner, 1);
    });

    test('finds the day of an entry saved without a dateKey', () {
      final cancellations = _cancel({
        '2026-11-12': {'dinner': true},
      });

      final meal = cancellations.apply(
        const MealRecord(id: 'adnan_2026-11-12', userId: 'adnan', dinner: 1),
      );

      expect(meal.dinner, 0);
    });
  });

  group('MonthlyCalculator with cancelled meals', () {
    test('leaves cancelled meals out of every member and the rate', () {
      final result = MonthlyCalculator.calculate(
        month: _november,
        members: const [_adnan, _rahim],
        meals: [
          _meal('adnan', '2026-11-12', lunch: 1, dinner: 1),
          _meal('rahim', '2026-11-12', lunch: 1, dinner: 1),
          _meal('adnan', '2026-11-13', lunch: 1, dinner: 1),
        ],
        expenses: [
          ExpenseRecord(
            paidById: 'adnan',
            date: DateTime(2026, 11, 12),
            amount: 300,
          ),
        ],
        minimumMeals: 0,
        shopDue: 0,
        rules: MonthRules(
          cancellations: _cancel({
            '2026-11-12': {'lunch': true},
          }),
        ),
      );

      final adnan = result.members.firstWhere((m) => m.id == 'adnan');
      final rahim = result.members.firstWhere((m) => m.id == 'rahim');

      expect(adnan.actualMeals, 3);
      expect(rahim.actualMeals, 1);
      expect(result.totalMealNumber, 4);
      expect(result.mealRate, 75);
    });

    test('changes nothing without cancellations', () {
      final meals = [_meal('adnan', '2026-11-12', lunch: 1, dinner: 1)];

      final result = MonthlyCalculator.calculate(
        month: _november,
        members: const [_adnan],
        meals: meals,
        expenses: const [],
        minimumMeals: 0,
        shopDue: 0,
      );

      expect(result.totalActualMeals, 2);
    });
  });

  group('DashboardSummary with cancelled meals', () {
    test('today shows no cancelled lunch, also from a meal plan', () {
      final now = DateTime(2026, 11, 12, 10);

      final summary = DashboardSummary.build(
        now: now,
        members: const [_adnan, _rahim],
        meals: [_meal('adnan', '2026-11-12', lunch: 1, dinner: 1)],
        plans: [
          MemberMealPlan(
            memberId: 'rahim',
            memberName: 'Rahim',
            rules: [
              MealPlanRule(
                fromDate: '2026-11-01',
                lunch: 1,
                dinner: 1,
                isStanding: true,
              ),
            ],
          ),
        ],
        expenses: const [],
        minimumMeals: 0,
        shopDue: 0,
        rules: MonthRules(
          cancellations: _cancel({
            '2026-11-12': {'lunch': true},
          }),
        ),
      );

      expect(summary.todayLunch, 0);
      expect(summary.todayDinner, 2);
      expect(summary.isLunchCancelled, isTrue);
      expect(summary.isDinnerCancelled, isFalse);
    });
  });
}
