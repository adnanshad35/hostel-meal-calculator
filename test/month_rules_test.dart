import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/month_rules.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

const _adnan = CalcMember(id: 'adnan', name: 'Adnan');

final _november = DateTime(2026, 11);

MealRecord _meal(
  String userId,
  String dateKey, {
  double lunch = 1,
  double dinner = 1,
}) {
  return MealRecord(
    id: '${userId}_$dateKey',
    userId: userId,
    userName: userId == 'rahim' ? 'Rahim' : null,
    dateKey: dateKey,
    lunch: lunch,
    dinner: dinner,
  );
}

MonthRules _leaver(LeavingChoice choice, {String leftOn = '2026-11-10'}) {
  return MonthRules.fromSettings({
    MonthLeavers.field: {
      'rahim': {'choice': choice.name, 'leftOn': leftOn},
    },
  });
}

/// Adnan stays; Rahim left on 10 Nov. Each ate two meals a day on
/// 2 Nov, and Rahim paid 400.
MonthlyCalculation _calculate(MonthRules rules, {double minimumMeals = 10}) {
  return MonthlyCalculator.calculate(
    month: _november,
    members: const [_adnan],
    meals: [
      _meal('adnan', '2026-11-02'),
      _meal('adnan', '2026-11-03'),
      _meal('rahim', '2026-11-02'),
    ],
    expenses: [
      ExpenseRecord(
        paidById: 'adnan',
        date: DateTime(2026, 11, 3),
        amount: 600,
      ),
      ExpenseRecord(
        paidById: 'rahim',
        paidByName: 'Rahim',
        date: DateTime(2026, 11, 2),
        amount: 400,
      ),
    ],
    minimumMeals: minimumMeals,
    shopDue: 0,
    rules: rules,
  );
}

MemberCalculation? _rahim(MonthlyCalculation result) =>
    result.members.where((member) => member.id == 'rahim').firstOrNull;

void main() {
  group('MonthLeavers', () {
    test('reads saved choices and ignores malformed ones', () {
      final leavers = MonthLeavers.fromSettings({
        MonthLeavers.field: {
          'a': {'choice': 'removeAll', 'leftOn': '2026-11-10'},
          'b': {'choice': 'unknown', 'leftOn': '2026-11-10'},
          'c': {'choice': 'actualOnly'},
          'd': 'x',
        },
      });

      expect(leavers.ruleOf('a')!.choice, LeavingChoice.removeAll);
      expect(leavers.ruleOf('b'), isNull);
      expect(leavers.ruleOf('c'), isNull);
      expect(leavers.ruleOf('d'), isNull);
      expect(MonthLeavers.fromSettings(null).isEmpty, isTrue);
    });

    test('Remove All leaves out records up to the day they left', () {
      final leavers = _leaver(LeavingChoice.removeAll).leavers;

      expect(leavers.counts('rahim', '2026-11-09'), isFalse);
      expect(leavers.counts('rahim', '2026-11-10'), isFalse);
      // After rejoining, their records count again.
      expect(leavers.counts('rahim', '2026-11-11'), isTrue);
      expect(leavers.counts('adnan', '2026-11-09'), isTrue);
    });
  });

  group('MonthlyCalculator with members who left', () {
    test('no choice saved counts exactly as before', () {
      final before = _calculate(MonthRules.none);
      final normal = _calculate(_leaver(LeavingChoice.normal));

      expect(_rahim(before)!.mealNumber, 10);
      expect(normal.mealRate, before.mealRate);
      expect(_rahim(normal)!.finalBalance, _rahim(before)!.finalBalance);
    });

    test('Keep Actual Records Only skips the minimum meals', () {
      final result = _calculate(_leaver(LeavingChoice.actualOnly));
      final rahim = _rahim(result)!;

      expect(rahim.actualMeals, 2);
      expect(rahim.mealNumber, 2);
      expect(rahim.spending, 400);
      // Adnan is still charged the minimum.
      expect(result.totalMealNumber, 12);
      expect(result.mealRate, closeTo(1000 / 12, 0.0001));
    });

    test('Remove All leaves their meals and expenses out', () {
      final result = _calculate(_leaver(LeavingChoice.removeAll));

      expect(_rahim(result), isNull);
      expect(result.totalMealNumber, 10);
      expect(result.memberPaidExpenses, 600);
    });

    test('a member who rejoined is charged the minimum again', () {
      final result = MonthlyCalculator.calculate(
        month: _november,
        members: const [
          _adnan,
          CalcMember(id: 'rahim', name: 'Rahim'),
        ],
        meals: [_meal('rahim', '2026-11-02'), _meal('rahim', '2026-11-20')],
        expenses: const [],
        minimumMeals: 10,
        shopDue: 0,
        rules: _leaver(LeavingChoice.actualOnly),
      );

      expect(_rahim(result)!.mealNumber, 10);
    });

    test('Remove All keeps what a rejoined member ate afterwards', () {
      final result = MonthlyCalculator.calculate(
        month: _november,
        members: const [
          _adnan,
          CalcMember(id: 'rahim', name: 'Rahim'),
        ],
        meals: [_meal('rahim', '2026-11-02'), _meal('rahim', '2026-11-20')],
        expenses: const [],
        minimumMeals: 0,
        shopDue: 0,
        rules: _leaver(LeavingChoice.removeAll),
      );

      expect(_rahim(result)!.actualMeals, 2);
    });
  });

  group('RemoveAllLimits', () {
    test('allows Remove All only below both limits', () {
      const limits = RemoveAllLimits();

      expect(limits.allows(meals: 4, spending: 199), isTrue);
      expect(limits.allows(meals: 0, spending: 0), isTrue);
      expect(limits.allows(meals: 5, spending: 0), isFalse);
      expect(limits.allows(meals: 0, spending: 200), isFalse);
    });
  });
}
