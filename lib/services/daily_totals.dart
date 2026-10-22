import 'monthly_calculator.dart';

/// A month's meals and expenses added up day by day, for the chart on
/// the dashboard. Index 0 is the 1st of the month.
class DailyTotals {
  DailyTotals._();

  static int _daysIn(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// Lunches plus dinners on each day of [month]. Records of another
  /// month, or without a date, are left out.
  static List<double> meals(DateTime month, Iterable<MealRecord> records) {
    final totals = List<double>.filled(_daysIn(month), 0);
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}-';

    for (final record in records) {
      final key = record.dateKey;
      if (key == null || !key.startsWith(prefix)) continue;

      final day = int.tryParse(key.substring(prefix.length));
      if (day == null || day < 1 || day > totals.length) continue;

      totals[day - 1] += record.lunch + record.dinner;
    }

    return totals;
  }

  /// The amount spent on each day of [month]. Expenses of another
  /// month, or without a date, are left out.
  static List<double> expenses(
    DateTime month,
    Iterable<ExpenseRecord> records,
  ) {
    final totals = List<double>.filled(_daysIn(month), 0);

    for (final record in records) {
      final date = record.date;
      if (date == null ||
          date.year != month.year ||
          date.month != month.month) {
        continue;
      }

      totals[date.day - 1] += record.amount;
    }

    return totals;
  }
}
