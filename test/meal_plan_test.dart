import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/meal_plan.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  const everyday = MealPlanRule(
    lunch: 1,
    dinner: 1,
    fromDate: '2026-10-05',
    isStanding: true,
  );

  // Away from lunch on the 14th until dinner on the 16th.
  const trip = MealPlanRule(
    lunch: 0,
    dinner: 0,
    fromDate: '2026-10-14',
    toDate: '2026-10-16',
  );

  group('forDay', () {
    test('counts nothing before a plan starts or without a plan', () {
      expect(MealPlans.forDay(const [], '2026-10-10'), isNull);
      expect(MealPlans.forDay(const [everyday], '2026-10-04'), isNull);
    });

    test('counts the everyday meals from the start date on', () {
      final day = MealPlans.forDay(const [everyday], '2026-10-05')!;

      expect(day.lunch, 1);
      expect(day.dinner, 1);
      expect(MealPlans.forDay(const [everyday], '2027-01-01')!.total, 2);
    });

    test('a period replaces the everyday meals while it lasts', () {
      const rules = [everyday, trip];

      expect(MealPlans.forDay(rules, '2026-10-13')!.total, 2);
      expect(MealPlans.forDay(rules, '2026-10-14')!.total, 0);
      expect(MealPlans.forDay(rules, '2026-10-16')!.total, 0);
      expect(MealPlans.forDay(rules, '2026-10-17')!.total, 2);
    });

    test('a period can start at dinner and end after lunch', () {
      const partTrip = MealPlanRule(
        lunch: 0,
        dinner: 0,
        fromDate: '2026-10-14',
        startsAtDinner: true,
        toDate: '2026-10-16',
        endsAfterLunch: true,
      );
      const rules = [everyday, partTrip];

      final first = MealPlans.forDay(rules, '2026-10-14')!;
      expect(first.lunch, 1);
      expect(first.dinner, 0);

      final last = MealPlans.forDay(rules, '2026-10-16')!;
      expect(last.lunch, 0);
      expect(last.dinner, 1);
    });

    test('a period works without everyday meals', () {
      const lunchOnly = MealPlanRule(
        lunch: 1,
        dinner: 0,
        fromDate: '2026-10-10',
        toDate: '2026-10-11',
      );

      expect(MealPlans.forDay(const [lunchOnly], '2026-10-10')!.total, 1);
      expect(MealPlans.forDay(const [lunchOnly], '2026-10-12'), isNull);
    });

    test('the period added last wins where two overlap', () {
      const back = MealPlanRule(
        lunch: 1,
        dinner: 1,
        fromDate: '2026-10-16',
        toDate: '2026-10-16',
      );

      expect(MealPlans.forDay(const [trip, back], '2026-10-16')!.total, 2);
      expect(MealPlans.forDay(const [trip, back], '2026-10-15')!.total, 0);
    });
  });

  group('withStanding', () {
    test('keeps earlier days as they were counted', () {
      final rules = MealPlans.withStanding(
        const [everyday, trip],
        lunch: 1,
        dinner: 0,
        fromDate: '2026-10-20',
      );

      expect(MealPlans.forDay(rules, '2026-10-19')!.total, 2);
      expect(MealPlans.forDay(rules, '2026-10-20')!.total, 1);
      // The trip is still there.
      expect(MealPlans.forDay(rules, '2026-10-15')!.total, 0);
      expect(MealPlans.standingOn(rules, '2026-10-25')!.dinner, 0);
    });

    test('replaces a change that starts on the same or a later day', () {
      var rules = MealPlans.withStanding(
        const [everyday],
        lunch: 0,
        dinner: 1,
        fromDate: '2026-10-20',
      );
      rules = MealPlans.withStanding(
        rules,
        lunch: 1,
        dinner: 0,
        fromDate: '2026-10-18',
      );

      expect(rules.where((rule) => rule.isStanding).length, 2);
      expect(MealPlans.forDay(rules, '2026-10-21')!.lunch, 1);
      expect(MealPlans.forDay(rules, '2026-10-21')!.dinner, 0);
    });

    test('setting 0 and 0 turns counting off', () {
      final rules = MealPlans.withStanding(
        const [everyday],
        lunch: 0,
        dinner: 0,
        fromDate: '2026-10-20',
      );

      expect(MealPlans.forDay(rules, '2026-10-21')!.total, 0);
    });
  });

  test('withRuleEnded stops a running period early', () {
    const rules = [everyday, trip];
    final ended = MealPlans.withRuleEnded(rules, trip, '2026-10-14');

    expect(MealPlans.forDay(ended, '2026-10-14')!.total, 0);
    expect(MealPlans.forDay(ended, '2026-10-15')!.total, 2);

    // Ended before it began: removed altogether.
    final removed = MealPlans.withRuleEnded(rules, trip, '2026-10-13');
    expect(removed.length, 1);
  });

  test('closedOn stops every rule and drops ones not yet started', () {
    const later = MealPlanRule(
      lunch: 0,
      dinner: 0,
      fromDate: '2026-11-01',
      toDate: '2026-11-05',
    );
    final closed = MealPlans.closedOn(const [
      everyday,
      trip,
      later,
    ], '2026-10-20');

    expect(closed.length, 2);
    expect(closed.every((rule) => rule.toDate != null), isTrue);
    expect(MealPlans.forDay(closed, '2026-10-20')!.total, 2);
    expect(MealPlans.forDay(closed, '2026-10-21'), isNull);
    expect(MealPlans.forDay(closed, '2026-10-15')!.total, 0);
  });

  group('automaticMeals', () {
    const plan = MemberMealPlan(
      memberId: 'a',
      memberName: 'Asif',
      rules: [everyday, trip],
    );

    List<MealRecord> run({
      List<MealRecord> meals = const [],
      Set<String> active = const {'a'},
      DateTime? today,
      MemberMealPlan member = plan,
    }) {
      return MealPlans.automaticMeals(
        plans: [member],
        meals: meals,
        activeMemberIds: active,
        month: DateTime(2026, 10),
        today: today ?? DateTime(2026, 10, 20),
      );
    }

    test('fills the days without an entry, up to today', () {
      final meals = run();

      // 5th to 13th (9 days) and 17th to 20th (4 days).
      expect(meals.length, 13);
      expect(meals.every((meal) => meal.isAutomatic), isTrue);
      expect(meals.first.dateKey, '2026-10-05');
      expect(meals.last.dateKey, '2026-10-20');
      expect(meals.first.userName, 'Asif');
    });

    test('a saved entry replaces the plan for its day, even at zero', () {
      final meals = run(
        meals: const [
          MealRecord(id: 'a_2026-10-06', userId: 'a', dateKey: '2026-10-06'),
          MealRecord(
            id: 'a_2026-10-07',
            userId: 'a',
            dateKey: '2026-10-07',
            lunch: 3,
          ),
          // Someone else's entry changes nothing.
          MealRecord(
            id: 'b_2026-10-08',
            userId: 'b',
            dateKey: '2026-10-08',
            lunch: 1,
          ),
        ],
      );

      expect(meals.length, 11);
      expect(meals.any((meal) => meal.dateKey == '2026-10-06'), isFalse);
      expect(meals.any((meal) => meal.dateKey == '2026-10-08'), isTrue);
    });

    test('counts nothing in a month that has not started', () {
      expect(run(today: DateTime(2026, 9, 30)), isEmpty);
    });

    test('counts a whole past month', () {
      final meals = MealPlans.automaticMeals(
        plans: const [plan],
        meals: const [],
        activeMemberIds: const {'a'},
        month: DateTime(2026, 11),
        today: DateTime(2026, 12, 3),
      );

      expect(meals.length, 30);
    });

    test('an open plan stops counting once the member has left', () {
      expect(run(active: const {}), isEmpty);
    });

    test('a closed plan still counts the days before the member left', () {
      final closed = MemberMealPlan(
        memberId: 'a',
        memberName: 'Asif',
        rules: MealPlans.closedOn(plan.rules, '2026-10-10'),
      );

      final meals = run(active: const {}, member: closed);

      expect(meals.length, 6);
      expect(meals.last.dateKey, '2026-10-10');
    });

    test('feeds the monthly calculation', () {
      final automatic = run();

      final result = MonthlyCalculator.calculate(
        month: DateTime(2026, 10),
        members: const [CalcMember(id: 'a', name: 'Asif')],
        meals: automatic,
        expenses: const [],
        minimumMeals: 0,
        shopDue: 0,
      );

      expect(result.members.single.actualMeals, 26);
    });
  });

  test('a plan survives being saved and read back', () {
    final saved = {
      'memberName': 'Asif',
      'rules': [
        everyday.toMap(),
        const MealPlanRule(
          lunch: 0.5,
          dinner: 0,
          fromDate: '2026-10-14',
          startsAtDinner: true,
          toDate: '2026-10-16',
          endsAfterLunch: true,
        ).toMap(),
        // Damaged data is skipped.
        'nonsense',
        {'lunch': 1},
      ],
    };

    final plan = MemberMealPlan.fromData('a', saved);

    expect(plan.memberName, 'Asif');
    expect(plan.rules.length, 2);
    expect(plan.rules.first.isStanding, isTrue);
    expect(plan.rules.last.lunch, 0.5);
    expect(plan.rules.last.startsAtDinner, isTrue);
    expect(plan.rules.last.endsAfterLunch, isTrue);
    expect(plan.rules.last.toDate, '2026-10-16');
  });
}
