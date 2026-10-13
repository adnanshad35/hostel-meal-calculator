import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/widgets/desktop_scaffold.dart';
import 'package:hostel_meal_calculator/widgets/web_layout.dart';

void main() {
  const destinations = [
    DesktopDestination(label: 'Overview', icon: Icons.dashboard_outlined),
    DesktopDestination(label: 'Users', icon: Icons.people_outline),
  ];

  Widget scaffold({required ValueChanged<int> onSelect}) {
    return MaterialApp(
      home: DesktopScaffold(
        title: 'Super Admin',
        subtitle: 'admin@example.com',
        destinations: destinations,
        selectedIndex: 0,
        onSelect: onSelect,
        content: const Scaffold(body: Text('Content')),
      ),
    );
  }

  testWidgets('desktop scaffold shows its sidebar and content', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int? selected;
    await tester.pumpWidget(scaffold(onSelect: (index) => selected = index));
    await tester.pump();

    expect(find.text('HostelMate'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);

    await tester.tap(find.text('Users'));
    expect(selected, 1);
  });

  testWidgets('desktop scaffold claims the window only while shown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    expect(WebLayout.shellActive.value, isFalse);

    await tester.pumpWidget(scaffold(onSelect: (_) {}));
    await tester.pump();
    expect(WebLayout.shellActive.value, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(WebLayout.shellActive.value, isFalse);
  });
}
