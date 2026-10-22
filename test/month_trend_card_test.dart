import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/widgets/month_trend_card.dart';

void main() {
  // An earlier month, so every day is shown and the readout starts on
  // the last day.
  final month = DateTime(2026, 9);
  final meals = [for (var day = 1; day <= 30; day++) (day % 7).toDouble()];
  final expenses = [for (var day = 1; day <= 30; day++) day * 100.0];

  Future<void> pump(WidgetTester tester, {double width = 320}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MonthTrendCard(
              month: month,
              meals: meals,
              expenses: expenses,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('fits a narrow phone and starts on the last day', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('30 Sep'), findsOneWidget);
    // 30 % 7 = 2 meals on the 30th.
    expect(find.text('2 Meals'), findsOneWidget);
  });

  testWidgets('switches to expenses', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();

    expect(find.text('৳3,000'), findsOneWidget);
  });

  testWidgets('tapping a day shows its figure', (tester) async {
    await pump(tester);

    // The chart's columns: tap near the left edge, the 1st.
    final chart = tester.getRect(find.byType(Semantics).last);
    await tester.tapAt(Offset(chart.left + 3, chart.top + 40));
    await tester.pumpAndSettle();

    expect(find.text('1 Sep'), findsOneWidget);
    expect(find.text('1 Meal'), findsOneWidget);
  });
}
