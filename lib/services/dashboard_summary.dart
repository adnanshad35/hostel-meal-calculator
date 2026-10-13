import 'meal_plan.dart';
import 'monthly_calculator.dart';

/// One member's meals today.
class TodayMeal {
  const TodayMeal({
    required this.name,
    required this.lunch,
    required this.dinner,
  });

  final String name;
  final double lunch;
  final double dinner;
}

/// The figures on the hostel's home screen: this month so far, and
/// how many meals are needed today.
class DashboardSummary {
  const DashboardSummary({
    required this.mealRate,
    required this.totalExpense,
    required this.totalMeals,
    required this.todayLunch,
    required this.todayDinner,
    this.todayMembers = const [],
  });

  /// The same meal rate, cost and meal total the Monthly Calculation
  /// shows for the current month.
  final double mealRate;
  final double totalExpense;
  final double totalMeals;

  /// Lunches and dinners for the whole hostel today: saved entries,
  /// and meal plans for members who have not entered anything.
  final double todayLunch;
  final double todayDinner;

  /// Who is eating today and how much, by name. Members with no meal
  /// today are left out.
  final List<TodayMeal> todayMembers;

  /// [meals] and [expenses] may hold other months too; only this
  /// month's are counted.
  static DashboardSummary build({
    required DateTime now,
    required List<CalcMember> members,
    required List<MealRecord> meals,
    required List<MemberMealPlan> plans,
    required List<ExpenseRecord> expenses,
    required double minimumMeals,
    required double shopDue,
  }) {
    final allMeals = [
      ...meals,
      ...MealPlans.automaticMeals(
        plans: plans,
        meals: meals,
        activeMemberIds: {for (final member in members) member.id},
        month: now,
        today: now,
      ),
    ];

    final result = MonthlyCalculator.calculate(
      month: now,
      members: members,
      meals: allMeals,
      expenses: expenses,
      minimumMeals: minimumMeals,
      shopDue: shopDue,
    );

    final todayKey = MealPlans.dateKey(now);
    final names = {for (final member in members) member.id: member.name};
    final todayMembers = <TodayMeal>[];
    double lunch = 0;
    double dinner = 0;

    for (final meal in allMeals) {
      if (meal.dateKey != todayKey) continue;

      lunch += meal.lunch;
      dinner += meal.dinner;

      if (meal.lunch + meal.dinner <= 0) continue;

      todayMembers.add(
        TodayMeal(
          name: names[meal.userId] ?? meal.userName ?? 'Member',
          lunch: meal.lunch,
          dinner: meal.dinner,
        ),
      );
    }

    todayMembers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return DashboardSummary(
      mealRate: result.mealRate,
      totalExpense: result.totalExpense,
      totalMeals: result.totalMealNumber,
      todayLunch: lunch,
      todayDinner: dinner,
      todayMembers: todayMembers,
    );
  }
}
