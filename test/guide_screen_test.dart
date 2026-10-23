import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/screens/guide_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: GuideScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('fits a narrow phone and opens on the first part', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Quick Start'), findsOneWidget);
    // The menu shows the first part.
    expect(find.text('Getting Started'), findsWidgets);
  });

  testWidgets('the menu jumps to the part picked', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month Lock').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Until the 7th', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.textContaining('Until the 7th', findRichText: true))
          .dy,
      lessThan(700),
    );
  });

  test('every part has points', () {
    for (final section in guideSections) {
      expect(section.points, isNotEmpty, reason: section.title);
    }
  });
}
