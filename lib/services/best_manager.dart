import 'duty_roster.dart';
import 'meal_plan.dart';
import 'monthly_calculator.dart';

/// One manager's duty turn within a month, and its meal rate.
class ManagerTurn {
  const ManagerTurn({
    required this.memberId,
    required this.memberName,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.meals,
    required this.spending,
  });

  final String memberId;
  final String memberName;

  /// The turn's days inside the month, as `YYYY-MM-DD`.
  final String fromDate;
  final String toDate;
  final int days;

  final double meals;
  final double spending;

  double get rate => meals > 0 ? spending / meals : 0;
}

/// Who kept food cheapest on duty in a month.
///
/// Each finished turn of at least [BestManager.minimumDays] days is
/// compared with the month's average rate, both worked out the same
/// way: the food bought on those days divided by the meals eaten on
/// them. Initial Share and Shop Due are month-wide money, not one
/// manager's shopping, so they are left out.
class BestManager {
  const BestManager({required this.averageRate, required this.turns});

  /// A turn shorter than this can be lucky, so it does not count.
  static const int minimumDays = 3;

  /// The month's rate over every finished day.
  final double averageRate;

  /// Counted turns, cheapest first.
  final List<ManagerTurn> turns;

  ManagerTurn? get best => turns.firstOrNull;

  /// How far [turn] is below the average; negative when above it.
  double belowAverage(ManagerTurn turn) => averageRate - turn.rate;

  /// Null when no turn of [month] can count yet.
  ///
  /// [meals] are the month's meals as they count, cancelled meals and
  /// meal plans included; [expenses] its food expenses, without any
  /// Initial Share. Days from [today] on are not finished.
  static BestManager? of({
    required DateTime month,
    required DutyRoster roster,
    required Iterable<MealRecord> meals,
    required Iterable<ExpenseRecord> expenses,
    required DateTime today,
  }) {
    final firstKey = MealPlans.dateKey(DateTime(month.year, month.month));
    final lastKey = MealPlans.dateKey(DateTime(month.year, month.month + 1, 0));
    final todayKey = MealPlans.dateKey(today);

    final mealsByDay = <String, double>{};
    for (final meal in meals) {
      final key = _mealDay(meal);
      if (key == null) continue;
      mealsByDay[key] = (mealsByDay[key] ?? 0) + meal.lunch + meal.dinner;
    }
    final spendingByDay = <String, double>{};
    for (final expense in expenses) {
      final date = expense.date;
      if (date == null) continue;
      final key = MealPlans.dateKey(date);
      spendingByDay[key] = (spendingByDay[key] ?? 0) + expense.amount;
    }

    bool isFinished(String key) =>
        key.compareTo(firstKey) >= 0 &&
        key.compareTo(lastKey) <= 0 &&
        key.compareTo(todayKey) < 0;

    double sum(Map<String, double> byDay, bool Function(String) keep) => byDay
        .entries
        .where((entry) => keep(entry.key))
        .fold(0, (running, entry) => running + entry.value);

    final counted = <ManagerTurn>[];
    for (final turn in roster.turns) {
      // Only the turn's days inside this month.
      final from = turn.fromDate.compareTo(firstKey) < 0
          ? firstKey
          : turn.fromDate;
      final to = turn.toDate.compareTo(lastKey) > 0 ? lastKey : turn.toDate;
      if (from.compareTo(to) > 0) continue;

      // A turn still running is not finished yet.
      if (to.compareTo(todayKey) >= 0) continue;

      final days = _daysBetween(from, to);
      if (days < minimumDays) continue;

      bool inTurn(String key) =>
          key.compareTo(from) >= 0 && key.compareTo(to) <= 0;

      final turnMeals = sum(mealsByDay, inTurn);
      if (turnMeals <= 0) continue;

      counted.add(
        ManagerTurn(
          memberId: turn.memberId,
          memberName: turn.memberName,
          fromDate: from,
          toDate: to,
          days: days,
          meals: turnMeals,
          spending: sum(spendingByDay, inTurn),
        ),
      );
    }

    if (counted.isEmpty) return null;

    final monthMeals = sum(mealsByDay, isFinished);
    final monthSpending = sum(spendingByDay, isFinished);
    counted.sort((a, b) => a.rate.compareTo(b.rate));

    return BestManager(
      averageRate: monthMeals > 0 ? monthSpending / monthMeals : 0,
      turns: counted,
    );
  }

  static String? _mealDay(MealRecord meal) {
    final saved = meal.dateKey;
    if (saved != null && saved.isNotEmpty) return saved;
    return RegExp(r'_(\d{4}-\d{2}-\d{2})$').firstMatch(meal.id)?.group(1);
  }

  static int _daysBetween(String from, String to) {
    DateTime parse(String key) {
      final parts = key.split('-').map(int.parse).toList();
      return DateTime.utc(parts[0], parts[1], parts[2]);
    }

    return parse(to).difference(parse(from)).inDays + 1;
  }
}
