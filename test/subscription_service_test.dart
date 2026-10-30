import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/subscription_service.dart';

void main() {
  final start = DateTime(2026, 10, 1, 9);
  final thirtyDays = HostelSubscription(periodStart: start, days: 30);

  group('HostelSubscription', () {
    test('is active until start + days, then read-only', () {
      expect(thirtyDays.activeUntil, DateTime(2026, 10, 31, 9));

      expect(thirtyDays.isActive(DateTime(2026, 10, 1, 9)), isTrue);
      expect(thirtyDays.isActive(DateTime(2026, 10, 31, 8, 59)), isTrue);
      expect(thirtyDays.isActive(DateTime(2026, 10, 31, 9)), isFalse);
      expect(thirtyDays.isActive(DateTime(2026, 11, 5)), isFalse);
    });

    test('a hostel that was never activated is not active', () {
      const none = HostelSubscription.none();

      expect(none.isActive(DateTime(2026, 10, 1)), isFalse);
      expect(none.activeUntil, isNull);
      expect(none.daysLeft(DateTime(2026, 10, 1)), 0);
    });

    test('days left are rounded up and never negative', () {
      expect(thirtyDays.daysLeft(DateTime(2026, 10, 1, 9)), 30);
      expect(thirtyDays.daysLeft(DateTime(2026, 10, 30, 10)), 1);
      expect(thirtyDays.daysLeft(DateTime(2026, 10, 31, 8)), 1);
      expect(thirtyDays.daysLeft(DateTime(2026, 10, 31, 9)), 0);
      expect(thirtyDays.daysLeft(DateTime(2026, 12, 1)), 0);
    });

    test('reads saved data and tolerates missing fields', () {
      final read = HostelSubscription.fromData({
        'periodStart': Timestamp.fromDate(start),
        'days': 30,
        'voucherCode': 'WC100',
      });

      expect(read.periodStart, start);
      expect(read.days, 30);
      expect(read.voucherCode, 'WC100');
      expect(read.isSaving, isFalse);

      expect(
        HostelSubscription.fromData(null).isActive(DateTime(2026, 10, 2)),
        isFalse,
      );
      expect(
        HostelSubscription.fromData(const {}).isActive(DateTime(2026)),
        isFalse,
      );
    });

    test('counts as active while the server is still saving the start', () {
      final saving = HostelSubscription.fromData({
        'periodStart': null,
        'days': 30,
      });

      expect(saving.isSaving, isTrue);
      expect(saving.isActive(DateTime(2026, 10, 2)), isTrue);
    });
  });

  group('super admin switches', () {
    final during = DateTime(2026, 10, 10);

    test('an active hostel can be edited by default', () {
      expect(thirtyDays.canEdit(during), isTrue);
      expect(thirtyDays.canEdit(DateTime(2026, 11, 5)), isFalse);
    });

    test('switching editing off makes an active hostel read-only', () {
      final locked = HostelSubscription(
        periodStart: start,
        days: 30,
        editingDisabled: true,
      );

      expect(locked.isActive(during), isTrue);
      expect(locked.canEdit(during), isFalse);
    });

    test('a suspended hostel cannot be edited either', () {
      final suspended = HostelSubscription(
        periodStart: start,
        days: 30,
        accessDisabled: true,
      );

      expect(suspended.canEdit(during), isFalse);
    });

    test('switches are read from saved data and default to off', () {
      final read = HostelSubscription.fromData({
        'periodStart': Timestamp.fromDate(start),
        'days': 30,
        'editingDisabled': true,
        'accessDisabled': true,
      });

      expect(read.editingDisabled, isTrue);
      expect(read.accessDisabled, isTrue);

      final plain = HostelSubscription.fromData({
        'periodStart': Timestamp.fromDate(start),
        'days': 30,
      });
      expect(plain.editingDisabled, isFalse);
      expect(plain.accessDisabled, isFalse);

      // Switches saved for a hostel that was never activated.
      final onlySwitches = HostelSubscription.fromData(const {
        'accessDisabled': true,
      });
      expect(onlySwitches.accessDisabled, isTrue);
      expect(onlySwitches.isSaving, isFalse);
      expect(onlySwitches.isActive(during), isFalse);
    });

    test('maintenance mode is off unless saved as on', () {
      expect(AppConfig.fromData(null).maintenance, isFalse);
      expect(AppConfig.fromData(const {}).maintenance, isFalse);

      final on = AppConfig.fromData(const {
        'maintenance': true,
        'maintenanceMessage': 'Back at 9 PM.',
      });
      expect(on.maintenance, isTrue);
      expect(on.maintenanceMessage, 'Back at 9 PM.');
    });
  });

  group('extensionFields', () {
    test('an active period just gets longer', () {
      final fields = SubscriptionService.extensionFields(
        thirtyDays,
        addDays: 15,
        now: DateTime(2026, 10, 20),
      );

      expect(fields, {'days': 45});
    });

    test('an ended period starts again from now', () {
      final fields = SubscriptionService.extensionFields(
        thirtyDays,
        addDays: 15,
        now: DateTime(2026, 11, 20),
      );

      expect(fields['days'], 15);
      expect(fields['periodStart'], isA<FieldValue>());
    });

    test('a hostel that was never activated starts from now', () {
      final fields = SubscriptionService.extensionFields(
        const HostelSubscription.none(),
        addDays: 30,
        now: DateTime(2026, 10, 20),
      );

      expect(fields['days'], 30);
      expect(fields['periodStart'], isA<FieldValue>());
    });
  });

  group('freeTrialFields', () {
    test('gives a new hostel 7 days from now', () {
      final fields = SubscriptionService.freeTrialFields(uid: 'admin');

      expect(fields['days'], 7);
      expect(fields['periodStart'], isA<FieldValue>());
      expect(fields['lastSource'], 'trial');
      expect(fields['updatedBy'], 'admin');
      expect(fields.containsKey('voucherCode'), isFalse);
    });

    test('a voucher used during the free days adds to them', () {
      final trial = HostelSubscription(periodStart: start, days: 7);

      final fields = SubscriptionService.extensionFields(
        trial,
        addDays: 30,
        now: DateTime(2026, 10, 3),
      );

      expect(fields, {'days': 37});
    });
  });

  group('codes and transaction IDs', () {
    test('are compared without spaces or case', () {
      expect(SubscriptionService.normalizeCode(' wc 100 '), 'WC100');
      expect(SubscriptionService.normalizeCode('9hk3\tabc1'), '9HK3ABC1');
    });

    test('must be 4 to 20 letters and numbers', () {
      expect(SubscriptionService.isValidCode('WC100'), isTrue);
      expect(SubscriptionService.isValidCode('9HK3ABC1XY'), isTrue);
      expect(SubscriptionService.isValidCode('ABC'), isFalse);
      expect(SubscriptionService.isValidCode('WC-100'), isFalse);
      expect(SubscriptionService.isValidCode('A' * 21), isFalse);
      expect(SubscriptionService.isValidCode(''), isFalse);
    });
  });

  test('payment info knows when nothing has been set', () {
    expect(const PaymentInfo().isEmpty, isTrue);
    expect(PaymentInfo.fromData(null).isEmpty, isTrue);
    expect(PaymentInfo.fromData(const {'bkashNumber': '017'}).isEmpty, isFalse);
  });

  group('time left', () {
    final start = DateTime(2026, 10, 1, 12);
    final subscription = HostelSubscription(periodStart: start, days: 10);
    // Active until 11 October, 12:00.

    test('is counted in days while more than a day is left', () {
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 1, 13)),
        '10 days left',
      );
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 9, 12)),
        '2 days left',
      );
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 10, 11)),
        '2 days left',
      );
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 10, 12)),
        '1 day left',
      );
    });

    test('is counted in hours on the last day', () {
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 10, 16)),
        '20 hours left',
      );
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 11, 2)),
        '10 hours left',
      );
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 11, 10, 30)),
        '2 hours left',
      );
      expect(
        subscription.timeLeftText(DateTime(2026, 10, 11, 11, 40)),
        '1 hour left',
      );
    });

    test('is empty once the period has ended or never started', () {
      expect(subscription.timeLeftText(DateTime(2026, 10, 11, 12)), '');
      expect(subscription.timeLeftText(DateTime(2026, 11, 1)), '');
      expect(
        const HostelSubscription.none().timeLeftText(DateTime(2026, 10, 5)),
        '',
      );
    });
  });
}
