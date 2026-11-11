import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/rent_calculator.dart';

void main() {
  test('rent plus an equal share of the bills', () {
    const calculation = RentCalculation(
      rent: 3000,
      bills: [
        (name: 'Wi-Fi', amount: 1000),
        (name: 'Electricity', amount: 2000),
      ],
      people: 6,
    );
    expect(calculation.billsTotal, 3000);
    expect(calculation.billShare, 500);
    expect(calculation.fixedCost, 3500);
    expect(calculation.toPay, 3500);
  });

  test('a meal balance to get back lowers what is paid', () {
    const calculation = RentCalculation(
      rent: 3000,
      bills: [(name: 'Wi-Fi', amount: 600)],
      people: 3,
      mealBalance: 400,
    );
    expect(calculation.toPay, 2800);
  });

  test('a meal balance owed adds to it, and can turn into getting back', () {
    const owes = RentCalculation(
      rent: 1000,
      bills: [],
      people: 1,
      mealBalance: -250,
    );
    expect(owes.toPay, 1250);

    const getsBack = RentCalculation(
      rent: 0,
      bills: [],
      people: 1,
      mealBalance: 300,
    );
    expect(getsBack.toPay, -300);
  });

  test('the phone remembers what was typed', () {
    final saved = RentCalculatorMemory.encode(
      rent: '3000',
      people: '6',
      bills: [(name: 'Wi-Fi', amount: '1000')],
    );
    final read = RentCalculatorMemory.decode(saved)!;
    expect(read.rent, '3000');
    expect(read.people, '6');
    expect(read.bills.single.name, 'Wi-Fi');
    expect(read.bills.single.amount, '1000');

    expect(RentCalculatorMemory.decode(null), isNull);
    expect(RentCalculatorMemory.decode('not json'), isNull);
  });
}
