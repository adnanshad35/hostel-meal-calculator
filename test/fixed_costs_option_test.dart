import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/fixed_costs.dart';
import 'package:hostel_meal_calculator/services/hostel_settings.dart';

void main() {
  Map<String, dynamic> saved(double rent) => {
    'rents': {'a': rent},
    'sharedBills': <Map<String, dynamic>>[],
  };

  group('Fixed Costs option', () {
    test('is off for every hostel until switched on', () {
      const options = BalanceOptions();
      expect(options.usesFixedCosts('2026-11'), isFalse);
      expect(options.fixedCostsSince('2026-11'), isNull);
      expect(
        HostelSettings.fromGroupData(const {}).balanceOptions
            .usesFixedCosts('2026-11'),
        isFalse,
      );
    });

    test('counts from the month it is switched on, not before', () {
      final options = const BalanceOptions().withFixedCosts(true, '2026-11');
      expect(options.usesFixedCosts('2026-10'), isFalse);
      expect(options.usesFixedCosts('2026-11'), isTrue);
      expect(options.usesFixedCosts('2027-01'), isTrue);
      expect(options.fixedCostsSince('2027-01'), '2026-11');
    });

    test('rent saved before the switch never comes back by itself', () {
      final settings = {'2025-03': saved(4000)};
      expect(
        FixedCostsCalculator.resolve(settings, '2026-11', since: '2026-11'),
        isNull,
      );

      settings['2026-11'] = saved(3000);
      final costs = FixedCostsCalculator.resolve(
        settings,
        '2027-01',
        since: '2026-11',
      )!;
      expect(costs.monthKey, '2026-11');
      expect(costs.rents['a'], 3000);
    });

    test('switched off and on again starts fresh from the new month', () {
      final options = const BalanceOptions()
          .withFixedCosts(true, '2026-11')
          .withFixedCosts(false, '2026-12')
          .withFixedCosts(true, '2027-02');
      expect(options.usesFixedCosts('2027-01'), isFalse);
      expect(options.fixedCostsSince('2027-01'), isNull);
      expect(options.fixedCostsSince('2027-03'), '2027-02');
      expect(options.fixedCostsSince('2026-11'), '2026-11');
    });

    test('switching on and off in the same month leaves nothing behind', () {
      final options = const BalanceOptions()
          .withFixedCosts(true, '2026-11')
          .withFixedCosts(false, '2026-11');
      expect(options.fixedCostsChanges, isEmpty);
    });

    test('is saved under options and read back', () {
      final settings = HostelSettings(
        balanceOptions: const BalanceOptions()
            .withFixedCosts(true, '2026-11')
            .withMonthTrend(false),
      );
      final read = HostelSettings.fromGroupData({
        'options': settings.optionsMap(),
      }).balanceOptions;
      expect(read.fixedCostsSince('2026-12'), '2026-11');
      expect(read.monthTrend, isFalse);
    });
  });

  test('Month Trend stays on for every hostel unless switched off', () {
    expect(const BalanceOptions().monthTrend, isTrue);
    expect(
      HostelSettings.fromGroupData(const {}).balanceOptions.monthTrend,
      isTrue,
    );
  });
}
