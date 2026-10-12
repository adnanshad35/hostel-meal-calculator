import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/screens/hostel_activation_screen.dart';
import 'package:hostel_meal_calculator/screens/super_admin_billing.dart';
import 'package:hostel_meal_calculator/services/subscription_service.dart';
import 'package:hostel_meal_calculator/theme/app_theme.dart';
import 'package:hostel_meal_calculator/widgets/maintenance_gate.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  final now = DateTime.now();

  final billing = AdminBilling(
    subscriptions: {
      'green': HostelSubscription(
        periodStart: now.subtract(const Duration(days: 5)),
        days: 30,
        voucherCode: 'WC100',
      ),
      'blue': HostelSubscription(
        periodStart: now.subtract(const Duration(days: 40)),
        days: 30,
        voucherCode: 'WC100',
      ),
    },
    vouchers: const [
      Voucher(code: 'WC100', days: 30, note: 'First hostels'),
      Voucher(code: 'OLD2025', days: 7, active: false),
    ],
    payments: [
      PaymentRequest(
        trxId: '9HK3ABC1XY',
        groupId: 'blue',
        groupName: 'Blue House With A Rather Long Hostel Name',
        amount: 300,
        status: PaymentStatus.pending,
        senderNumber: '01712345678',
        submittedByName: 'Karim',
        createdAt: now,
      ),
      const PaymentRequest(
        trxId: '8AA1BBB2CC',
        groupId: 'green',
        groupName: 'Green Hostel',
        amount: 250.5,
        status: PaymentStatus.approved,
        daysGranted: 30,
      ),
      const PaymentRequest(
        trxId: '7ZZ9YYY8XX',
        groupId: 'green',
        groupName: 'Green Hostel',
        amount: 100,
        status: PaymentStatus.rejected,
        note: 'The transaction could not be confirmed.',
      ),
    ],
    paymentInfo: const PaymentInfo(
      bkashNumber: '01700000000',
      instructions: 'Send Money, then submit the transaction ID.',
    ),
  );

  test('billing summary counts', () {
    expect(billing.activeHostels(now), 1);
    expect(billing.pendingPayments, 1);
    expect(billing.hostelsUsing('WC100'), 2);
    expect(billing.hostelsUsing('OLD2025'), 0);
    expect(billing.subscriptionOf('missing').isActive(now), isFalse);
  });

  testWidgets('status card: active, ended, and never activated', (
    tester,
  ) async {
    await _pump(
      tester,
      ListView(
        children: [
          SubscriptionStatusCard(
            subscription: billing.subscriptionOf('green'),
            action: FilledButton(onPressed: () {}, child: const Text('Extend')),
          ),
          SubscriptionStatusCard(subscription: billing.subscriptionOf('blue')),
          const SubscriptionStatusCard(subscription: HostelSubscription.none()),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Active · 25 days left'), findsOneWidget);
    expect(find.text('Read-only'), findsNWidgets(2));
    expect(
      find.text('This hostel has not been activated yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('Ended on'), findsOneWidget);
  });

  testWidgets('payments tab lists payments with actions on pending ones', (
    tester,
  ) async {
    await _pump(
      tester,
      AdminPaymentsTab(billing: billing, onRefresh: () async {}),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1 waiting · 3 in total'), findsOneWidget);
    expect(find.text('9HK3ABC1XY'), findsOneWidget);
    expect(find.text('Waiting for review'), findsOneWidget);
    expect(find.text('Approved · 30 days added'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    // Only the pending payment can be approved or rejected.
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.textContaining('bKash 01700000000'), findsOneWidget);
  });

  testWidgets('vouchers tab shows each voucher and whether it is on', (
    tester,
  ) async {
    await _pump(
      tester,
      AdminVouchersTab(billing: billing, onRefresh: () async {}),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('WC100'), findsOneWidget);
    expect(find.textContaining('30 days · on 2 hostels'), findsOneWidget);
    expect(find.text('New Voucher'), findsOneWidget);

    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    // WC100 is switched on, OLD2025 is switched off.
    expect(switches.map((tile) => tile.value), [true, false]);
  });

  testWidgets('new voucher dialog validates the code and days', (tester) async {
    await _pump(
      tester,
      AdminVouchersTab(billing: billing, onRefresh: () async {}),
    );

    await tester.tap(find.text('New Voucher'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Code'), 'ab');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Days it adds'),
      '0',
    );
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(find.text('Use 4 to 20 letters and numbers.'), findsOneWidget);
    expect(find.text('Enter a number of days from 1 to 3650.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status card shows locked and suspended hostels', (tester) async {
    await _pump(
      tester,
      ListView(
        children: [
          SubscriptionStatusCard(
            subscription: HostelSubscription(
              periodStart: now,
              days: 30,
              editingDisabled: true,
            ),
          ),
          SubscriptionStatusCard(
            subscription: HostelSubscription(
              periodStart: now,
              days: 30,
              accessDisabled: true,
            ),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Read-only'), findsOneWidget);
    expect(
      find.textContaining('Editing has been switched off'),
      findsOneWidget,
    );
    expect(find.text('Suspended'), findsOneWidget);
  });

  testWidgets('maintenance card and screen', (tester) async {
    await _pump(
      tester,
      ListView(
        children: [
          AdminMaintenanceCard(
            config: const AppConfig(maintenance: true),
            onRefresh: () async {},
          ),
          AdminMaintenanceCard(
            config: const AppConfig(),
            onRefresh: () async {},
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('On. Everyone except you'), findsOneWidget);
    expect(find.textContaining('Off. Turn on to pause'), findsOneWidget);

    // Turning it on asks for confirmation and a message first.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(find.text('Turn On Maintenance?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await _pump(tester, const MaintenanceScreen(message: 'Back at 9 PM.'));
    expect(find.text('Under maintenance'), findsOneWidget);
    expect(find.text('Back at 9 PM.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
