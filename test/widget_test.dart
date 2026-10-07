import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/main.dart';

void main() {
  testWidgets('welcome screen displays main actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );

    expect(find.text('HostelMate'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create New Account'), findsOneWidget);
  });
}