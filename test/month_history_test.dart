import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/widgets/month_calendar.dart';

void main() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);

  test('steps back one month at a time', () {
    expect(shiftMonth(thisMonth, -1), DateTime(now.year, now.month - 1));
  });

  test('never goes past the current month', () {
    expect(shiftMonth(thisMonth, 1), isNull);
    expect(shiftMonth(DateTime(now.year, now.month - 1), 1), thisMonth);
  });

  test('goes back to last month only', () {
    final oldest = DateTime(now.year, now.month - monthsOfHistory);

    expect(shiftMonth(thisMonth, -monthsOfHistory), oldest);
    expect(shiftMonth(oldest, -1), isNull);
  });

  test('knows the current month', () {
    expect(isCurrentMonth(thisMonth), isTrue);
    expect(isCurrentMonth(DateTime(now.year, now.month - 1)), isFalse);
  });
}
