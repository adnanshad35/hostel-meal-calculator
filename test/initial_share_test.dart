import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/hostel_settings.dart';
import 'package:hostel_meal_calculator/services/initial_share.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  group('InitialShare.splitEqually', () {
    test('divides evenly', () {
      expect(InitialShare.splitEqually(3000, 6), List.filled(6, 500.0));
    });

    test('gives the first members a taka more when it does not divide', () {
      final parts = InitialShare.splitEqually(3000, 7);
      expect(parts.take(4), everyElement(429.0));
      expect(parts.skip(4), everyElement(428.0));
      expect(parts.reduce((a, b) => a + b), 3000);
    });

    test('keeps paisa with the first member', () {
      final parts = InitialShare.splitEqually(100.5, 3);
      expect(parts.reduce((a, b) => a + b), closeTo(100.5, 0.001));
    });

    test('is empty without members or an amount', () {
      expect(InitialShare.splitEqually(500, 0), isEmpty);
      expect(InitialShare.splitEqually(0, 2), [0, 0]);
    });
  });

  test('a share counts as each member paying their part', () {
    // Rice and oil for the month, ৳3000 from three members.
    final month = DateTime(2026, 11);
    final result = MonthlyCalculator.calculate(
      month: month,
      members: const [
        CalcMember(id: 'a', name: 'A'),
        CalcMember(id: 'b', name: 'B'),
        CalcMember(id: 'c', name: 'C'),
      ],
      meals: const [
        MealRecord(
          id: 'a_2026-11-01',
          userId: 'a',
          dateKey: '2026-11-01',
          lunch: 10,
          dinner: 10,
        ),
        MealRecord(
          id: 'b_2026-11-01',
          userId: 'b',
          dateKey: '2026-11-01',
          lunch: 5,
          dinner: 5,
        ),
        MealRecord(
          id: 'c_2026-11-01',
          userId: 'c',
          dateKey: '2026-11-01',
          lunch: 5,
          dinner: 5,
        ),
      ],
      expenses: [
        for (final id in ['a', 'b', 'c'])
          ExpenseRecord(
            paidById: id,
            date: DateTime(2026, 11, 1),
            amount: 1000,
          ),
      ],
      minimumMeals: 0,
      shopDue: 0,
    );

    expect(result.totalExpense, 3000);
    expect(result.mealRate, 75);
    final byId = {for (final member in result.members) member.id: member};
    // Who eats more pays more.
    expect(byId['a']!.finalBalance, -500);
    expect(byId['b']!.finalBalance, 250);
    expect(byId['c']!.finalBalance, 250);
  });

  group('BalanceOptions', () {
    const settings = {'minimumMeals': 20, 'shopDue': 1500};

    test('counts everything when nothing is switched off', () {
      const options = BalanceOptions();
      expect(options.minimumMealsOf(settings, '2026-11'), 20);
      expect(options.shopDueOf(settings, '2026-11'), 1500);
    });

    test('a switch changes its month and later ones, never earlier', () {
      final options = const BalanceOptions().withMinimumMeals(false, '2026-11');
      expect(options.minimumMealsOf(settings, '2026-10'), 20);
      expect(options.minimumMealsOf(settings, '2026-11'), 0);
      expect(options.minimumMealsOf(settings, '2027-01'), 0);
      expect(options.shopDueOf(settings, '2026-11'), 1500);
    });

    test('switched back on next month, the month before stays off', () {
      // Off on 20 November, on again on 3 December, while November is
      // still open.
      final options = const BalanceOptions()
          .withMinimumMeals(false, '2026-11')
          .withMinimumMeals(true, '2026-12');
      expect(options.usesMinimumMeals('2026-10'), isTrue);
      expect(options.usesMinimumMeals('2026-11'), isFalse);
      expect(options.usesMinimumMeals('2026-12'), isTrue);
    });

    test('off and on again in the same month leaves nothing behind', () {
      final options = const BalanceOptions()
          .withShopDue(false, '2026-11')
          .withShopDue(true, '2026-11');
      expect(options.shopDueChanges, isEmpty);
      expect(options.usesShopDue('2026-11'), isTrue);
    });

    test('Initial Share and Best Manager switches keep the others', () {
      final options = const BalanceOptions()
          .withMinimumMeals(false, '2026-11')
          .withInitialShare(true)
          .withBestManager(true);
      expect(options.usesMinimumMeals('2026-11'), isFalse);
      expect(options.initialShare, isTrue);
      expect(options.bestManager, isTrue);
    });

    test('saved under options, which earlier versions never rewrite', () {
      final settings = const HostelSettings().copyWith(
        balanceOptions: const BalanceOptions()
            .withMinimumMeals(false, '2026-11')
            .withInitialShare(true),
      );
      expect(settings.toMap().keys, isNot(contains('initialShareEnabled')));

      // An earlier version saved `settings` as a whole; `options` stays.
      final read = HostelSettings.fromGroupData({
        'settings': {'membersCanAddMeals': false},
        'options': settings.optionsMap(),
      });
      expect(read.membersCanAddMeals, isFalse);
      expect(read.balanceOptions.usesMinimumMeals('2026-11'), isFalse);
      expect(read.balanceOptions.initialShare, isTrue);
    });

    test('reads what test builds saved under settings', () {
      final read = HostelSettings.fromGroupData({
        'settings': {
          'minimumMealsOffFrom': '2026-11',
          'shopDueOffFrom': 'not a month',
          'initialShareEnabled': true,
          'removeAllMaxMeals': 8,
        },
      });
      expect(read.balanceOptions.usesMinimumMeals('2026-11'), isFalse);
      expect(read.balanceOptions.usesShopDue('2026-11'), isTrue);
      expect(read.balanceOptions.initialShare, isTrue);
      expect(read.removeAllLimits.maxMeals, 8);
    });

    test('a hostel that never set them uses Min Meals and Shop Due only', () {
      final read = HostelSettings.fromGroupData({'settings': {}});
      expect(read.balanceOptions.usesMinimumMeals('2026-11'), isTrue);
      expect(read.balanceOptions.usesShopDue('2026-11'), isTrue);
      expect(read.balanceOptions.initialShare, isFalse);
      expect(read.balanceOptions.bestManager, isFalse);
    });
  });
}
