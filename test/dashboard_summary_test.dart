import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/dashboard_summary.dart';
import 'package:hostel_meal_calculator/services/hostel_settings.dart';
import 'package:hostel_meal_calculator/services/meal_plan.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

void main() {
  final now = DateTime(2026, 10, 14, 9);

  const members = [
    CalcMember(id: 'a', name: 'Asif'),
    CalcMember(id: 'b', name: 'Babu'),
    CalcMember(id: 'c', name: 'Chand'),
  ];

  MealRecord meal(String member, String date, double lunch, double dinner) {
    return MealRecord(
      id: '${member}_$date',
      userId: member,
      dateKey: date,
      lunch: lunch,
      dinner: dinner,
    );
  }

  DashboardSummary build({
    List<MealRecord> meals = const [],
    List<MemberMealPlan> plans = const [],
    List<ExpenseRecord> expenses = const [],
    double minimumMeals = 0,
    double shopDue = 0,
  }) {
    return DashboardSummary.build(
      now: now,
      members: members,
      meals: meals,
      plans: plans,
      expenses: expenses,
      minimumMeals: minimumMeals,
      shopDue: shopDue,
    );
  }

  test('shows the month so far: rate, cost and meals', () {
    final summary = build(
      meals: [
        meal('a', '2026-10-01', 1, 1),
        meal('b', '2026-10-01', 1, 1),
        meal('c', '2026-10-02', 2, 2),
        // Last month is not part of this one.
        meal('a', '2026-09-30', 5, 5),
      ],
      expenses: [
        ExpenseRecord(paidById: 'a', date: DateTime(2026, 10, 3), amount: 600),
        ExpenseRecord(paidById: 'b', date: DateTime(2026, 9, 30), amount: 999),
      ],
      shopDue: 200,
    );

    expect(summary.totalMeals, 8);
    expect(summary.totalExpense, 800);
    expect(summary.mealRate, 100);
  });

  test('today counts every member\'s saved lunch and dinner', () {
    final summary = build(
      meals: [
        meal('a', '2026-10-14', 1, 1),
        meal('b', '2026-10-14', 2, 0),
        meal('c', '2026-10-13', 1, 1),
      ],
    );

    expect(summary.todayLunch, 3);
    expect(summary.todayDinner, 1);

    // Each member who eats today, by name, with their own amounts.
    expect(summary.todayMembers.map((member) => member.name), ['Asif', 'Babu']);
    expect(summary.todayMembers.last.lunch, 2);
    expect(summary.todayMembers.last.dinner, 0);
  });

  test('today includes meal plans of members who entered nothing', () {
    const plans = [
      // Babu eats lunch and dinner every day.
      MemberMealPlan(
        memberId: 'b',
        memberName: 'Babu',
        rules: [
          MealPlanRule(
            lunch: 1,
            dinner: 1,
            fromDate: '2026-10-10',
            isStanding: true,
          ),
        ],
      ),
      // Chand is away today.
      MemberMealPlan(
        memberId: 'c',
        memberName: 'Chand',
        rules: [
          MealPlanRule(
            lunch: 1,
            dinner: 1,
            fromDate: '2026-10-01',
            isStanding: true,
          ),
          MealPlanRule(
            lunch: 0,
            dinner: 0,
            fromDate: '2026-10-14',
            toDate: '2026-10-15',
          ),
        ],
      ),
    ];

    final summary = build(
      // Asif saved an entry, which is used as it is.
      meals: [meal('a', '2026-10-14', 1, 0)],
      plans: plans,
    );

    expect(summary.todayLunch, 2);
    expect(summary.todayDinner, 1);

    // Chand is away, so only Asif and Babu are listed.
    expect(summary.todayMembers.map((member) => member.name), ['Asif', 'Babu']);
  });

  test('an empty month shows zeros, not an error', () {
    final summary = build();

    expect(summary.mealRate, 0);
    expect(summary.totalExpense, 0);
    expect(summary.totalMeals, 0);
    expect(summary.todayLunch, 0);
    expect(summary.todayDinner, 0);
  });

  group('hostel settings', () {
    test('everything is on for a hostel that never saved settings', () {
      for (final data in <Map<String, dynamic>?>[
        null,
        {},
        {'settings': 'nonsense'},
        {'settings': <String, dynamic>{}},
      ]) {
        final settings = HostelSettings.fromGroupData(data);

        expect(settings.membersCanAddMeals, isTrue);
        expect(settings.membersCanAddExpenses, isTrue);
        expect(settings.fixedCostsEnabled, isTrue);
      }
    });

    test('only what was switched off is off', () {
      final settings = HostelSettings.fromGroupData({
        'settings': {'membersCanAddMeals': false, 'fixedCostsEnabled': false},
      });

      expect(settings.membersCanAddMeals, isFalse);
      expect(settings.membersCanAddExpenses, isTrue);
      expect(settings.fixedCostsEnabled, isFalse);
    });

    test('a change survives being saved and read back', () {
      final changed = const HostelSettings().copyWith(
        membersCanAddExpenses: false,
      );
      final read = HostelSettings.fromGroupData({'settings': changed.toMap()});

      expect(read.membersCanAddMeals, isTrue);
      expect(read.membersCanAddExpenses, isFalse);
      expect(read.fixedCostsEnabled, isTrue);
    });
  });
}
