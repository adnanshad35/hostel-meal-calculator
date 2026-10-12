import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/theme/app_theme.dart';
import 'package:hostel_meal_calculator/widgets/meal_counter.dart';

void main() {
  group('parse', () {
    test('accepts whole and half meals', () {
      expect(MealCounter.parse('4'), 4);
      expect(MealCounter.parse(' 2.5 '), 2.5);
      expect(MealCounter.parse('0'), 0);
      expect(MealCounter.parse('1,5'), 1.5);
    });

    test('rounds to the nearest half meal', () {
      expect(MealCounter.parse('1.2'), 1);
      expect(MealCounter.parse('1.3'), 1.5);
      expect(MealCounter.parse('1.'), 1);
    });

    test('rejects text that is not a quantity', () {
      expect(MealCounter.parse(''), isNull);
      expect(MealCounter.parse('abc'), isNull);
      expect(MealCounter.parse('-1'), isNull);
      expect(MealCounter.parse('1.2.3'), isNull);
    });

    test('caps very large numbers', () {
      expect(MealCounter.parse('500'), MealCounter.maxValue);
    });
  });

  test('format drops a trailing .0', () {
    expect(MealCounter.format(4), '4');
    expect(MealCounter.format(2.5), '2.5');
    expect(MealCounter.format(0), '0');
  });

  testWidgets('typing and the buttons both change the value',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var value = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          // Same width as the content of the Add Meal dialog.
          body: Center(
            child: SizedBox(
              width: 232,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return MealCounter(
                    title: 'Dinner',
                    icon: Icons.dinner_dining_outlined,
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // Type 4 directly instead of pressing + eight times.
    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    expect(value, 4);

    // The buttons continue from the typed value.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 4.5);
    expect(find.text('4.5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(value, 3.5);

    // Half-typed and invalid text never produce a wrong value.
    await tester.enterText(find.byType(TextField), '2.');
    await tester.pump();
    expect(value, 2);
    await tester.enterText(find.byType(TextField), '.');
    await tester.pump();
    expect(value, 2);

    // Clearing the field means zero, and the minus button then stops.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(value, 0);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(value, 0);
    expect(tester.takeException(), isNull);
  });
}
