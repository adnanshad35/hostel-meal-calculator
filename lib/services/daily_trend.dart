import 'monthly_calculator.dart';

/// A month's meals and cost added up day by day: index 0 holds the
/// 1st, index 1 the 1st and 2nd together, and so on.
class DailyTrend {
  const DailyTrend({required this.meals, required this.cost});

  final List<double> meals;
  final List<double> cost;

  /// Days covered: up to today for the current month.
  int get days => meals.length;

  /// The meal rate so far on the day at [index], from the meals
  /// eaten. Zero until the first meal.
  double rateAt(int index) {
    return meals[index] > 0 ? cost[index] / meals[index] : 0;
  }

  /// True when nothing was eaten or spent.
  bool get isEmpty => days == 0 || (meals.last <= 0 && cost.last <= 0);

  /// The running totals of [month], for its first [days] days. Records
  /// of another month, or without a date, are left out.
  static DailyTrend build({
    required DateTime month,
    required int days,
    required Iterable<MealRecord> meals,
    required Iterable<ExpenseRecord> expenses,
  }) {
    final dailyMeals = List<double>.filled(days, 0);
    final dailyCost = List<double>.filled(days, 0);
    final prefix = '${MonthlyCalculator.monthKey(month)}-';

    for (final meal in meals) {
      final key = meal.dateKey;
      if (key == null || !key.startsWith(prefix)) continue;

      final day = int.tryParse(key.substring(prefix.length));
      if (day == null || day < 1 || day > days) continue;

      dailyMeals[day - 1] += meal.lunch + meal.dinner;
    }

    for (final expense in expenses) {
      final date = expense.date;
      if (date == null ||
          date.year != month.year ||
          date.month != month.month ||
          date.day > days) {
        continue;
      }

      dailyCost[date.day - 1] += expense.amount;
    }

    for (var index = 1; index < days; index++) {
      dailyMeals[index] += dailyMeals[index - 1];
      dailyCost[index] += dailyCost[index - 1];
    }

    return DailyTrend(meals: dailyMeals, cost: dailyCost);
  }
}
