import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/widgets/month_calendar.dart';

void main() {
  // An earlier month, so every day is shown and the last day is picked
  // at first.
  final month = DateTime(2026, 9);

  Future<void> pump(
    WidgetTester tester, {
    bool showMonthOption = true,
    bool calendarOnly = false,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendarView(
            month: month,
            label: 'Total Meals',
            total: '412',
            markedDays: const {1, 2, 30},
            showMonthOption: showMonthOption,
            calendarOnly: calendarOnly,
            onTotalTap: () {},
            onPreviousMonth: () {},
            linesOf: (day) => [
              if (day == 1 || day == 2 || day == 30)
                CalendarLine(title: 'Meals on day $day', trailing: '2'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fits a narrow phone with the strip, not the calendar', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Sep 2026'), findsOneWidget);
    expect(find.text('412'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    // Only the picked day, the 30th, is listed.
    expect(find.text('Meals on day 30'), findsOneWidget);
    expect(find.text('Meals on day 1'), findsNothing);
  });

  testWidgets('All lists the whole month, and a second tap goes back', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Meals on day 1'), findsOneWidget);
    expect(find.text('Meals on day 30'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Meals on day 1'), findsNothing);
  });

  testWidgets('the calendar opens, and picking a day closes it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Show Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsNothing);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Meals on day 2'), findsOneWidget);
  });

  testWidgets('without the month option every day with entries is listed', (
    tester,
  ) async {
    await pump(tester, showMonthOption: false);

    expect(find.text('All'), findsNothing);
    expect(find.text('Meals on day 1'), findsOneWidget);
    expect(find.text('Meals on day 30'), findsOneWidget);
  });

  testWidgets('calendar only keeps the calendar open, with no strip', (
    tester,
  ) async {
    await pump(tester, calendarOnly: true);

    expect(tester.takeException(), isNull);
    expect(find.text('All'), findsNothing);
    expect(find.byTooltip('Show Calendar'), findsNothing);
    expect(find.text('Meals on day 30'), findsOneWidget);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();
    expect(find.text('Meals on day 2'), findsOneWidget);
    expect(find.text('Meals on day 30'), findsNothing);
    // Still open after picking a day.
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('calendar only does not open a day still to come', (
    tester,
  ) async {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    // Nothing is still to come on the last day of the month.
    if (now.day == lastDay) return;

    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendarView(
            month: DateTime(now.year, now.month),
            label: 'Total Meals',
            total: '0',
            markedDays: const {},
            calendarOnly: true,
            showMonthOption: true,
            linesOf: (day) => const [],
            dayDetails: (day) => Text('Table of day $day'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table of day ${now.day}'), findsOneWidget);

    await tester.tap(find.text('$lastDay').last);
    await tester.pumpAndSettle();
    expect(find.text('Table of day $lastDay'), findsNothing);
    expect(find.text('Table of day ${now.day}'), findsOneWidget);
  });

  testWidgets('figures sit side by side and a day shows its own details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendarView(
            month: month,
            label: 'Total Meals',
            total: '412',
            markedDays: const {30},
            calendarOnly: true,
            showMonthOption: true,
            onPreviousMonth: () {},
            figures: [
              CalendarFigure(
                label: 'My Meals',
                value: '58',
                onTap: () => opened = 'mine',
              ),
              CalendarFigure(
                label: 'Total Meals',
                value: '412',
                onTap: () => opened = 'all',
              ),
            ],
            linesOf: (day) => const [],
            dayDetails: (day) => Text('Table of day $day'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sep 2026'), findsOneWidget);
    expect(find.text('Table of day 30'), findsOneWidget);

    await tester.tap(find.text('My Meals'));
    expect(opened, 'mine');
    await tester.tap(find.text('Total Meals'));
    expect(opened, 'all');
  });
}
