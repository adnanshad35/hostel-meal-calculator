import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/monthly_calculator.dart';

const _adnan = CalcMember(id: 'adnan', name: 'Adnan');
const _rahim = CalcMember(id: 'rahim', name: 'Rahim');
const _karim = CalcMember(id: 'karim', name: 'Karim');

final _october = DateTime(2026, 10);

MealRecord _meal(
  String userId,
  String dateKey, {
  double lunch = 0,
  double dinner = 0,
  String? userName,
}) {
  return MealRecord(
    id: '${userId}_$dateKey',
    userId: userId,
    userName: userName,
    dateKey: dateKey,
    lunch: lunch,
    dinner: dinner,
  );
}

ExpenseRecord _expense(
  String paidById,
  DateTime date,
  double amount, {
  String? paidByName,
}) {
  return ExpenseRecord(
    paidById: paidById,
    paidByName: paidByName,
    date: date,
    amount: amount,
  );
}

MonthlyCalculation _calculate({
  List<CalcMember> members = const [_adnan, _rahim],
  List<MealRecord> meals = const [],
  List<ExpenseRecord> expenses = const [],
  double minimumMeals = 0,
  double shopDue = 0,
}) {
  return MonthlyCalculator.calculate(
    month: _october,
    members: members,
    meals: meals,
    expenses: expenses,
    minimumMeals: minimumMeals,
    shopDue: shopDue,
  );
}

MemberCalculation _member(MonthlyCalculation result, String name) {
  return result.members.singleWhere((member) => member.name == name);
}

void main() {
  group('meal rate and balances', () {
    test('splits expenses by meals eaten', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1, dinner: 1),
          _meal('adnan', '2026-10-02', lunch: 1),
          _meal('rahim', '2026-10-01', dinner: 1),
        ],
        expenses: [
          _expense('adnan', DateTime(2026, 10, 3), 300),
          _expense('rahim', DateTime(2026, 10, 5), 100),
        ],
      );

      expect(result.totalMealNumber, 4);
      expect(result.memberPaidExpenses, 400);
      expect(result.totalExpense, 400);
      expect(result.mealRate, 100);

      final adnan = _member(result, 'Adnan');
      expect(adnan.actualMeals, 3);
      expect(adnan.mealExpense, 300);
      expect(adnan.exactBalance, 0);
      expect(adnan.finalBalance, 0);

      // Rahim ate 1 meal (100) and paid 100.
      expect(_member(result, 'Rahim').finalBalance, 0);
    });

    test('a member who paid more than they ate collects', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1),
          _meal('rahim', '2026-10-01', lunch: 1, dinner: 2),
        ],
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 400)],
      );

      expect(result.mealRate, 100);
      expect(_member(result, 'Adnan').finalBalance, 300);
      expect(_member(result, 'Rahim').finalBalance, -300);
    });

    test('without shop due the exact balances cancel out', () {
      final result = _calculate(
        members: const [_adnan, _rahim, _karim],
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1, dinner: 1),
          _meal('rahim', '2026-10-01', lunch: 0.5),
          _meal('karim', '2026-10-02', dinner: 1.5),
        ],
        expenses: [
          _expense('adnan', DateTime(2026, 10, 1), 250),
          _expense('karim', DateTime(2026, 10, 2), 75.5),
        ],
      );

      final sum = result.members.fold<double>(
        0,
        (total, member) => total + member.exactBalance,
      );

      expect(sum, closeTo(0, 1e-9));
    });

    test('half meals are counted', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 0.5, dinner: 0.5),
          _meal('rahim', '2026-10-01', lunch: 1.5),
        ],
      );

      expect(_member(result, 'Adnan').actualMeals, 1);
      expect(_member(result, 'Rahim').actualMeals, 1.5);
      expect(result.totalMealNumber, 2.5);
    });

    test('final balance is the exact balance rounded to a whole taka', () {
      final result = _calculate(
        members: const [_adnan, _rahim, _karim],
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1),
          _meal('rahim', '2026-10-01', lunch: 1),
          _meal('karim', '2026-10-01', lunch: 1),
        ],
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 100)],
      );

      expect(result.mealRate, closeTo(33.3333, 1e-4));
      expect(_member(result, 'Adnan').exactBalance, closeTo(66.6667, 1e-4));
      expect(_member(result, 'Adnan').finalBalance, 67);
      expect(_member(result, 'Rahim').finalBalance, -33);
      expect(_member(result, 'Karim').finalBalance, -33);
    });
  });

  group('minimum meals', () {
    test('members below the minimum are charged the minimum', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1, dinner: 1),
          for (var day = 2; day <= 10; day++)
            _meal('rahim', '2026-10-${day.toString().padLeft(2, '0')}',
                lunch: 1, dinner: 1),
        ],
        expenses: [_expense('rahim', DateTime(2026, 10, 1), 2800)],
        minimumMeals: 10,
      );

      final adnan = _member(result, 'Adnan');
      expect(adnan.actualMeals, 2);
      expect(adnan.mealNumber, 10);

      final rahim = _member(result, 'Rahim');
      expect(rahim.actualMeals, 18);
      expect(rahim.mealNumber, 18);

      expect(result.totalMealNumber, 28);
      expect(result.mealRate, 100);
      expect(adnan.finalBalance, -1000);
      expect(rahim.finalBalance, 1000);
    });

    test('a member with no entries still pays for the minimum', () {
      final result = _calculate(
        members: const [_adnan, _karim],
        meals: [_meal('adnan', '2026-10-01', lunch: 5, dinner: 5)],
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 1500)],
        minimumMeals: 5,
      );

      final karim = _member(result, 'Karim');
      expect(karim.actualMeals, 0);
      expect(karim.mealNumber, 5);
      expect(result.mealRate, 100);
      expect(karim.finalBalance, -500);
    });

    test('a member with no entries and no minimum is settled', () {
      final result = _calculate(
        members: const [_adnan, _karim],
        meals: [_meal('adnan', '2026-10-01', lunch: 1)],
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 80)],
      );

      final karim = _member(result, 'Karim');
      expect(karim.mealNumber, 0);
      expect(karim.finalBalance, 0);
    });
  });

  group('shop due', () {
    test('is added to the total and raises the meal rate', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1, dinner: 1),
          _meal('rahim', '2026-10-01', lunch: 1, dinner: 1),
        ],
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 300)],
        shopDue: 100,
      );

      expect(result.memberPaidExpenses, 300);
      expect(result.shopDue, 100);
      expect(result.totalExpense, 400);
      expect(result.mealRate, 100);
      expect(_member(result, 'Adnan').finalBalance, 100);
      expect(_member(result, 'Rahim').finalBalance, -200);
    });

    test('members together owe exactly the shop due', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 2),
          _meal('rahim', '2026-10-01', lunch: 3),
        ],
        expenses: [_expense('rahim', DateTime(2026, 10, 1), 410)],
        shopDue: 90,
      );

      final sum = result.members.fold<double>(
        0,
        (total, member) => total + member.exactBalance,
      );

      expect(sum, closeTo(-90, 1e-9));
    });
  });

  group('empty and incomplete data', () {
    test('no meals gives a zero rate instead of dividing by zero', () {
      final result = _calculate(
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 500)],
      );

      expect(result.totalMealNumber, 0);
      expect(result.mealRate, 0);
      expect(_member(result, 'Adnan').mealExpense, 0);
      expect(_member(result, 'Adnan').finalBalance, 500);
      expect(_member(result, 'Rahim').finalBalance, 0);
    });

    test('no members and no records gives an empty result', () {
      final result = _calculate(members: const []);

      expect(result.members, isEmpty);
      expect(result.totalExpense, 0);
      expect(result.mealRate, 0);
    });

    test('records without an owner or a date are ignored', () {
      final result = _calculate(
        meals: [
          const MealRecord(id: 'x', dateKey: '2026-10-01', lunch: 9),
          _meal('adnan', '2026-10-01', lunch: 1),
        ],
        expenses: [
          const ExpenseRecord(amount: 999),
          const ExpenseRecord(paidById: 'adnan', amount: 999),
          _expense('adnan', DateTime(2026, 10, 1), 50),
        ],
      );

      expect(result.totalMealNumber, 1);
      expect(result.memberPaidExpenses, 50);
    });

    test('reads numbers and names from stored meal data', () {
      final record = MealRecord.fromData('rahim_2026-10-01', {
        'userId': 'rahim',
        'userName': 'Rahim',
        'dateKey': '2026-10-01',
        'lunch': 1,
        'dinner': 0.5,
      });

      expect(record.userId, 'rahim');
      expect(record.lunch, 1.0);
      expect(record.dinner, 0.5);

      final empty = MealRecord.fromData('x', const {});
      expect(empty.userId, isNull);
      expect(empty.lunch, 0);
      expect(empty.dinner, 0);
    });
  });

  group('month boundaries', () {
    test('meals from other months are ignored', () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-09-30', lunch: 1),
          _meal('adnan', '2026-10-01', lunch: 1),
          _meal('adnan', '2026-10-31', dinner: 1),
          _meal('adnan', '2026-11-01', lunch: 1),
          _meal('adnan', '2025-10-15', lunch: 1),
        ],
      );

      expect(_member(result, 'Adnan').actualMeals, 2);
    });

    test('a meal is matched by month key, date key, or document id', () {
      final result = _calculate(
        meals: const [
          MealRecord(id: 'a', userId: 'adnan', monthKey: '2026-10', lunch: 1),
          MealRecord(
            id: 'b',
            userId: 'adnan',
            dateKey: '2026-10-07',
            lunch: 1,
          ),
          MealRecord(id: 'adnan_2026-10-09', userId: 'adnan', lunch: 1),
          MealRecord(id: 'adnan_2026-09-09', userId: 'adnan', lunch: 1),
        ],
      );

      expect(_member(result, 'Adnan').actualMeals, 3);
    });

    test('expenses count from the first to the last moment of the month',
        () {
      final result = _calculate(
        expenses: [
          _expense('adnan', DateTime(2026, 9, 30, 23, 59), 1),
          _expense('adnan', DateTime(2026, 10, 1), 10),
          _expense('adnan', DateTime(2026, 10, 31, 23, 59), 100),
          _expense('adnan', DateTime(2026, 11, 1), 1000),
        ],
      );

      expect(result.memberPaidExpenses, 110);
    });

    test('December rolls over into the next year', () {
      final result = MonthlyCalculator.calculate(
        month: DateTime(2026, 12),
        members: const [_adnan],
        meals: [
          _meal('adnan', '2026-12-31', lunch: 1),
          _meal('adnan', '2027-01-01', lunch: 1),
        ],
        expenses: [
          _expense('adnan', DateTime(2026, 12, 31), 40),
          _expense('adnan', DateTime(2027, 1, 1), 400),
        ],
        minimumMeals: 0,
        shopDue: 0,
      );

      expect(result.totalMealNumber, 1);
      expect(result.memberPaidExpenses, 40);
    });

    test('month keys are zero padded', () {
      expect(MonthlyCalculator.monthKey(DateTime(2026, 3, 9)), '2026-03');
      expect(MonthlyCalculator.monthKey(DateTime(2026, 12)), '2026-12');
    });
  });

  group('former members', () {
    test('someone with meals who left is included under their saved name',
        () {
      final result = _calculate(
        meals: [
          _meal('adnan', '2026-10-01', lunch: 1),
          _meal('gone', '2026-10-01', lunch: 1, userName: ' Salam '),
        ],
        expenses: [_expense('adnan', DateTime(2026, 10, 1), 200)],
      );

      expect(result.members, hasLength(3));
      final salam = _member(result, 'Salam');
      expect(salam.actualMeals, 1);
      expect(salam.finalBalance, -100);
    });

    test('someone who only paid an expense is included', () {
      final result = _calculate(
        meals: [_meal('adnan', '2026-10-01', lunch: 2)],
        expenses: [
          _expense('gone', DateTime(2026, 10, 2), 120, paidByName: 'Salam'),
        ],
      );

      final salam = _member(result, 'Salam');
      expect(salam.spending, 120);
      expect(salam.finalBalance, 120);
      expect(_member(result, 'Adnan').finalBalance, -120);
    });

    test('a missing saved name falls back to Former Member', () {
      final result = _calculate(
        meals: [_meal('gone', '2026-10-01', lunch: 1, userName: '  ')],
      );

      expect(_member(result, 'Former Member').actualMeals, 1);
    });

    test('former members from other months are not added', () {
      final result = _calculate(
        meals: [_meal('gone', '2026-09-01', lunch: 1, userName: 'Salam')],
        expenses: [
          _expense('gone', DateTime(2026, 9, 2), 120, paidByName: 'Salam'),
        ],
      );

      expect(result.members, hasLength(2));
    });
  });

  test('members keep the order they were given in', () {
    final result = _calculate(
      members: const [_karim, _adnan, _rahim],
      meals: [_meal('gone', '2026-10-01', lunch: 1, userName: 'Salam')],
    );

    expect(
      result.members.map((member) => member.name),
      ['Karim', 'Adnan', 'Rahim', 'Salam'],
    );
  });
}
