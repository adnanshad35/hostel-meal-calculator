import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/daily_trend.dart';
import 'package:hostel_meal_calculator/widgets/month_trend_chart.dart';

void main() {
  DailyTrend trend(int days, double mealsPerDay, double costPerDay) {
    return DailyTrend(
      meals: [for (var day = 1; day <= days; day++) day * mealsPerDay],
      cost: [for (var day = 1; day <= days; day++) day * costPerDay],
    );
  }

  Future<void> pump(WidgetTester tester, {DailyTrend? previous}) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MonthTrendChart(
              month: DateTime(2026, 10),
              current: trend(12, 10, 600),
              previous: previous,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows this month alone and starts on its last day', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Day 12'), findsOneWidget);
    expect(find.text('Oct '), findsOneWidget);
    expect(find.text('Sep '), findsNothing);
    expect(find.text('৳60.00'), findsOneWidget);
  });

  testWidgets('compares with last month on a narrow phone', (tester) async {
    await pump(tester, previous: trend(30, 12, 840));

    expect(tester.takeException(), isNull);
    expect(find.text('Sep '), findsOneWidget);
    expect(find.text('৳70.00'), findsOneWidget);

    await tester.tap(find.text('Cost'));
    await tester.pumpAndSettle();

    // Day 12: 12 x 600 this month, 12 x 840 last month.
    expect(find.text('৳7,200'), findsOneWidget);
    expect(find.text('৳10,080'), findsOneWidget);
  });

  testWidgets('tapping the chart picks a day', (tester) async {
    await pump(tester, previous: trend(30, 12, 840));

    final chart = tester.getRect(find.byType(CustomPaint).last);
    await tester.tapAt(Offset(chart.right - 2, chart.center.dy));
    await tester.pumpAndSettle();

    // Past this month's last day, only last month has a figure.
    expect(find.text('Day 30'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}
