import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/expense_items.dart';

void main() {
  const items = [
    ExpenseItem(name: 'Rice', quantity: '5 kg', price: 350),
    ExpenseItem(name: 'Oil', price: 180.5),
    ExpenseItem(name: 'Onion', quantity: '2 kg', price: 120),
  ];

  test('saves as a normal name, amount and description', () {
    expect(ExpenseItems.nameOf(items), 'Rice, Oil, Onion');
    expect(ExpenseItems.totalOf(items), 650.5);
    expect(
      ExpenseItems.describe(items),
      'Rice · 5 kg · ৳350\nOil · ৳180.50\nOnion · 2 kg · ৳120',
    );
  });

  test('reads back what it saved', () {
    final parsed = ExpenseItems.parse(
      name: ExpenseItems.nameOf(items),
      description: ExpenseItems.describe(items),
      amount: ExpenseItems.totalOf(items),
    );
    expect(parsed, isNotNull);
    expect(parsed!.map((item) => item.name), ['Rice', 'Oil', 'Onion']);
    expect(parsed.map((item) => item.quantity), ['5 kg', '', '2 kg']);
    expect(parsed.map((item) => item.price), [350, 180.5, 120]);
  });

  test('a simple expense or one changed since opens as simple', () {
    final description = ExpenseItems.describe(items);
    // A plain note.
    expect(
      ExpenseItems.parse(name: 'Bazar', description: 'Fish', amount: 500),
      isNull,
    );
    // No description.
    expect(
      ExpenseItems.parse(name: 'Bazar', description: '', amount: 5),
      isNull,
    );
    // The amount was changed in an older app.
    expect(
      ExpenseItems.parse(
        name: 'Rice, Oil, Onion',
        description: description,
        amount: 700,
      ),
      isNull,
    );
    // The name was changed.
    expect(
      ExpenseItems.parse(
        name: 'Bazar',
        description: description,
        amount: 650.5,
      ),
      isNull,
    );
  });

  test('clean keeps a line from breaking', () {
    expect(ExpenseItems.clean(' Dal · red\n'), 'Dal - red');
  });
}
