import 'dart:math';

/// A person included in a monthly calculation.
class CalcMember {
  const CalcMember({required this.id, required this.name});

  final String id;
  final String name;
}

/// One saved meal entry, reduced to what the calculation needs.
class MealRecord {
  const MealRecord({
    required this.id,
    this.userId,
    this.userName,
    this.monthKey,
    this.dateKey,
    this.lunch = 0,
    this.dinner = 0,
    this.isAutomatic = false,
  });

  /// Builds a record from a `groups/{groupId}/meals` document.
  factory MealRecord.fromData(String id, Map<String, dynamic> data) {
    return MealRecord(
      id: id,
      userId: data['userId'] as String?,
      userName: data['userName'] as String?,
      monthKey: data['monthKey'] as String?,
      dateKey: data['dateKey'] as String?,
      lunch: (data['lunch'] as num?)?.toDouble() ?? 0,
      dinner: (data['dinner'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String? userId;
  final String? userName;
  final String? monthKey;
  final String? dateKey;
  final double lunch;
  final double dinner;

  /// True when the day was counted from the member's meal plan
  /// instead of a saved entry.
  final bool isAutomatic;
}

/// One saved expense, reduced to what the calculation needs.
class ExpenseRecord {
  const ExpenseRecord({
    this.paidById,
    this.paidByName,
    this.date,
    this.amount = 0,
  });

  final String? paidById;
  final String? paidByName;
  final DateTime? date;
  final double amount;
}

class MemberCalculation {
  const MemberCalculation({
    required this.id,
    required this.name,
    this.isFormer = false,
    required this.actualMeals,
    required this.mealNumber,
    required this.spending,
    this.mealExpense = 0,
    this.exactBalance = 0,
    this.finalBalance = 0,
  });

  final String id;
  final String name;

  /// True for someone with records this month who is no longer in
  /// the member list.
  final bool isFormer;

  /// Meals the member actually ate.
  final double actualMeals;

  /// Meals the member is charged for, after the monthly minimum.
  final double mealNumber;

  /// Expenses paid by the member.
  final double spending;

  final double mealExpense;

  /// Positive when the member should collect, negative when they owe.
  final double exactBalance;

  /// [exactBalance] rounded to a whole taka.
  final int finalBalance;

  MemberCalculation copyWith({
    double? mealExpense,
    double? exactBalance,
    int? finalBalance,
  }) {
    return MemberCalculation(
      id: id,
      name: name,
      isFormer: isFormer,
      actualMeals: actualMeals,
      mealNumber: mealNumber,
      spending: spending,
      mealExpense: mealExpense ?? this.mealExpense,
      exactBalance: exactBalance ?? this.exactBalance,
      finalBalance: finalBalance ?? this.finalBalance,
    );
  }
}

class MonthlyCalculation {
  const MonthlyCalculation({
    required this.totalMealNumber,
    this.totalActualMeals = 0,
    required this.memberPaidExpenses,
    required this.shopDue,
    required this.totalExpense,
    required this.mealRate,
    required this.members,
  });

  /// The meals charged for: each member's meals, or the minimum when
  /// they ate fewer. The meal rate is worked out from this.
  final double totalMealNumber;

  /// The meals actually eaten, without the minimum.
  final double totalActualMeals;
  final double memberPaidExpenses;
  final double shopDue;
  final double totalExpense;
  final double mealRate;
  final List<MemberCalculation> members;
}

/// The hostel's monthly meal-rate and balance calculation.
///
/// Meal rate = (expenses paid by members + shop due) / charged meals,
/// where every member is charged at least [minimumMeals]. A member's
/// balance is what they paid minus their charged meals at that rate.
class MonthlyCalculator {
  MonthlyCalculator._();

  /// Whether the minimum meals and shop due of [month] may be entered
  /// at [now]. They are settled at the end of the month, so they are
  /// open from the 25th of that month to the 5th of the next.
  static bool isClosingWindowOpen(DateTime month, DateTime now) {
    final opens = DateTime(month.year, month.month, 25);
    final closes = DateTime(month.year, month.month + 1, 6);

    return !now.isBefore(opens) && now.isBefore(closes);
  }

  static String monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static MonthlyCalculation calculate({
    required DateTime month,
    required List<CalcMember> members,
    required Iterable<MealRecord> meals,
    required Iterable<ExpenseRecord> expenses,
    required double minimumMeals,
    required double shopDue,
  }) {
    final memberById = <String, CalcMember>{
      for (final member in members) member.id: member,
    };
    final actualMeals = <String, double>{};
    final memberSpending = <String, double>{};
    final formerMemberIds = <String>{};

    for (final member in members) {
      actualMeals[member.id] = 0;
      memberSpending[member.id] = 0;
    }

    // People with records this month who are no longer in the member
    // list still take part in the calculation.
    void addFormerMember(String id, String? savedName) {
      memberById[id] = CalcMember(
        id: id,
        name: savedName?.trim().isNotEmpty == true
            ? savedName!.trim()
            : 'Former Member',
      );
      actualMeals[id] = 0;
      memberSpending[id] = 0;
      formerMemberIds.add(id);
    }

    final selectedMonthKey = monthKey(month);

    for (final meal in meals) {
      final userId = meal.userId;
      if (userId == null) continue;

      final belongsToMonth =
          meal.monthKey == selectedMonthKey ||
          meal.dateKey?.startsWith(selectedMonthKey) == true ||
          meal.id.contains('_$selectedMonthKey-');

      if (!belongsToMonth) continue;

      if (!memberById.containsKey(userId)) {
        addFormerMember(userId, meal.userName);
      }

      actualMeals[userId] = actualMeals[userId]! + meal.lunch + meal.dinner;
    }

    final firstDay = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);

    for (final expense in expenses) {
      final userId = expense.paidById;
      final date = expense.date;
      if (userId == null || date == null) continue;

      final belongsToMonth =
          !date.isBefore(firstDay) && date.isBefore(nextMonth);
      if (!belongsToMonth) continue;

      if (!memberById.containsKey(userId)) {
        addFormerMember(userId, expense.paidByName);
      }

      memberSpending[userId] = memberSpending[userId]! + expense.amount;
    }

    final calculations = <MemberCalculation>[];
    double totalMealNumber = 0;
    double totalActualMeals = 0;
    double memberPaidExpenses = 0;

    for (final member in memberById.values) {
      final actual = actualMeals[member.id] ?? 0;
      final calculatedMealNumber = max(actual, minimumMeals).toDouble();
      final spending = memberSpending[member.id] ?? 0;

      totalMealNumber += calculatedMealNumber;
      totalActualMeals += actual;
      memberPaidExpenses += spending;

      calculations.add(
        MemberCalculation(
          id: member.id,
          name: member.name,
          isFormer: formerMemberIds.contains(member.id),
          actualMeals: actual,
          mealNumber: calculatedMealNumber,
          spending: spending,
        ),
      );
    }

    final totalExpense = memberPaidExpenses + shopDue;
    final mealRate = totalMealNumber > 0 ? totalExpense / totalMealNumber : 0.0;

    final completedCalculations = calculations.map((calculation) {
      final mealExpense = calculation.mealNumber * mealRate;
      final exactBalance = calculation.spending - mealExpense;

      return calculation.copyWith(
        mealExpense: mealExpense,
        exactBalance: exactBalance,
        finalBalance: exactBalance.round(),
      );
    }).toList();

    return MonthlyCalculation(
      totalMealNumber: totalMealNumber,
      totalActualMeals: totalActualMeals,
      memberPaidExpenses: memberPaidExpenses,
      shopDue: shopDue,
      totalExpense: totalExpense,
      mealRate: mealRate,
      members: completedCalculations,
    );
  }
}
