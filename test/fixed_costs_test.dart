import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/fixed_costs.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

MemberCalculation _member(
  String id, {
  double exactBalance = 0,
  bool isFormer = false,
}) {
  return MemberCalculation(
    id: id,
    name: id,
    isFormer: isFormer,
    actualMeals: 0,
    mealNumber: 0,
    spending: 0,
    exactBalance: exactBalance,
    finalBalance: exactBalance.round(),
  );
}

MemberSettlement _of(List<MemberSettlement> settlements, String id) {
  return settlements.singleWhere((settlement) => settlement.id == id);
}

void main() {
  const bills = [
    SharedBill(name: 'Wi-Fi', amount: 600),
    SharedBill(name: 'Electricity', amount: 900),
  ];

  test('shared bills are divided equally and rent is per member', () {
    final settlements = FixedCostsCalculator.settle(
      members: [_member('adnan'), _member('rahim'), _member('karim')],
      rents: const {'adnan': 3000, 'rahim': 2500},
      bills: bills,
    );

    expect(FixedCostsCalculator.totalBills(bills), 1500);

    final adnan = _of(settlements, 'adnan');
    expect(adnan.rent, 3000);
    expect(adnan.billShare, 500);
    expect(adnan.finalTotal, -3500);

    expect(_of(settlements, 'rahim').finalTotal, -3000);

    // No rent entered for Karim: only the bill share.
    final karim = _of(settlements, 'karim');
    expect(karim.rent, 0);
    expect(karim.finalTotal, -500);
  });

  test('the meal balance is combined with rent and bills', () {
    final settlements = FixedCostsCalculator.settle(
      members: [
        _member('adnan', exactBalance: 1200),
        _member('rahim', exactBalance: -800),
      ],
      rents: const {'adnan': 1000, 'rahim': 1000},
      bills: const [SharedBill(name: 'Chef', amount: 400)],
    );

    // Adnan should receive 1200 for meals but owes 1000 + 200.
    expect(_of(settlements, 'adnan').finalTotal, 0);
    // Rahim owes 800 for meals plus 1000 + 200.
    expect(_of(settlements, 'rahim').finalTotal, -2000);
  });

  test('a member who is owed more than their costs still receives', () {
    final settlements = FixedCostsCalculator.settle(
      members: [_member('adnan', exactBalance: 5000), _member('rahim')],
      rents: const {'adnan': 2000},
      bills: const [SharedBill(name: 'Wi-Fi', amount: 1000)],
    );

    expect(_of(settlements, 'adnan').finalTotal, 2500);
  });

  test('former members keep their meal balance but pay no bill share',
      () {
    final members = [
      _member('adnan'),
      _member('rahim'),
      _member('gone', exactBalance: -150, isFormer: true),
    ];

    expect(
      FixedCostsCalculator.billShare(members: members, bills: bills),
      750,
    );

    final settlements = FixedCostsCalculator.settle(
      members: members,
      rents: const {},
      bills: bills,
    );

    expect(_of(settlements, 'adnan').billShare, 750);
    expect(_of(settlements, 'gone').billShare, 0);
    expect(_of(settlements, 'gone').finalTotal, -150);
  });

  test('members together owe exactly the rent and bills', () {
    final settlements = FixedCostsCalculator.settle(
      members: [
        _member('adnan', exactBalance: 333.33),
        _member('rahim', exactBalance: -333.33),
        _member('karim'),
      ],
      rents: const {'adnan': 2000, 'rahim': 2500, 'karim': 1800},
      bills: const [SharedBill(name: 'Wi-Fi', amount: 1000)],
    );

    final sum = settlements.fold<double>(
      0,
      (total, settlement) => total + settlement.exactTotal,
    );

    expect(sum, closeTo(-(6300 + 1000), 1e-9));
  });

  test('the total is rounded once, from the exact amounts', () {
    final settlements = FixedCostsCalculator.settle(
      members: [
        _member('adnan', exactBalance: -0.4),
        _member('rahim'),
        _member('karim'),
      ],
      rents: const {},
      bills: const [SharedBill(name: 'Wi-Fi', amount: 100)],
    );

    // -0.4 - 33.33 = -33.73, which rounds to -34.
    expect(_of(settlements, 'adnan').finalTotal, -34);
    expect(_of(settlements, 'rahim').finalTotal, -33);
  });

  test('nothing entered leaves the meal balance unchanged', () {
    final settlements = FixedCostsCalculator.settle(
      members: [_member('adnan', exactBalance: -250)],
      rents: const {},
      bills: const [],
    );

    expect(_of(settlements, 'adnan').finalTotal, -250);
  });

  test('no current members means no bill share and no division by zero',
      () {
    expect(
      FixedCostsCalculator.billShare(
        members: [_member('gone', isFormer: true)],
        bills: bills,
      ),
      0,
    );
    expect(FixedCostsCalculator.billShare(members: [], bills: bills), 0);
  });

  group('reading saved data', () {
    test('rents keep only positive numbers', () {
      expect(
        FixedCostsCalculator.readRents({
          'adnan': 3000,
          'rahim': 2500.5,
          'karim': 0,
          'salam': 'abc',
          'x': -5,
        }),
        {'adnan': 3000.0, 'rahim': 2500.5},
      );
      expect(FixedCostsCalculator.readRents(null), isEmpty);
      expect(FixedCostsCalculator.readRents('oops'), isEmpty);
    });

    test('bills keep only named, positive entries', () {
      final read = FixedCostsCalculator.readBills([
        {'name': ' Wi-Fi ', 'amount': 600},
        {'name': 'Free', 'amount': 0},
        {'amount': 50},
        'junk',
        {'name': 'Chef', 'amount': 4000.5},
      ]);

      expect(read.map((bill) => bill.name), ['Wi-Fi', 'Chef']);
      expect(read.map((bill) => bill.amount), [600.0, 4000.5]);
      expect(FixedCostsCalculator.readBills(null), isEmpty);
    });

    test('a bill round-trips through its saved form', () {
      const bill = SharedBill(name: 'Electricity', amount: 912.5);
      final read = FixedCostsCalculator.readBills([bill.toData()]);

      expect(read.single.name, 'Electricity');
      expect(read.single.amount, 912.5);
    });
  });
}
