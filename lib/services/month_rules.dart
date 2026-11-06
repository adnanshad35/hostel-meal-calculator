import 'meal_cancellation.dart';
import 'monthly_calculator.dart';

/// How a member who left counts in the month they left, as an admin
/// chose it.
enum LeavingChoice {
  /// Everything counts, the minimum meals too. What a member who left
  /// always counted as before this choice existed.
  normal,

  /// Their meals and expenses count, without the minimum meals.
  actualOnly,

  /// Their meals and expenses up to the day they left are left out.
  removeAll;

  String get label => switch (this) {
    LeavingChoice.normal => 'Keep Normal Calculation',
    LeavingChoice.actualOnly => 'Keep Actual Records Only',
    LeavingChoice.removeAll => 'Remove All',
  };

  static LeavingChoice? fromName(Object? name) {
    for (final choice in values) {
      if (choice.name == name) return choice;
    }
    return null;
  }
}

/// One member who left in a month, and how they count in it.
class LeaverRule {
  const LeaverRule({
    required this.memberId,
    required this.choice,
    required this.leftOn,
  });

  final String memberId;
  final LeavingChoice choice;

  /// The day they left, as `YYYY-MM-DD`. With [LeavingChoice.removeAll]
  /// their records up to and including it are left out, so anything
  /// after they rejoin still counts.
  final String leftOn;

  Map<String, dynamic> toMap() => {'choice': choice.name, 'leftOn': leftOn};
}

/// The members who left in a month, saved in its `monthlySettings`
/// document under `leavers`, as `{memberId: {choice, leftOn}}`.
///
/// A member with no entry counts as they always did, so months saved
/// before this existed come out exactly the same.
class MonthLeavers {
  const MonthLeavers([this._rules = const {}]);

  static const MonthLeavers none = MonthLeavers();

  /// The settings field the leavers are saved in.
  static const String field = 'leavers';

  factory MonthLeavers.fromSettings(Map<String, dynamic>? settings) {
    final saved = settings?[field];
    if (saved is! Map) return none;

    final rules = <String, LeaverRule>{};
    saved.forEach((id, value) {
      if (id is! String || value is! Map) return;

      final choice = LeavingChoice.fromName(value['choice']);
      final leftOn = value['leftOn'];
      if (choice == null || leftOn is! String || leftOn.isEmpty) return;

      rules[id] = LeaverRule(memberId: id, choice: choice, leftOn: leftOn);
    });

    return MonthLeavers(rules);
  }

  final Map<String, LeaverRule> _rules;

  bool get isEmpty => _rules.isEmpty;

  LeaverRule? ruleOf(String memberId) => _rules[memberId];

  /// These leavers with [rule] added or replaced.
  MonthLeavers withRule(LeaverRule rule) =>
      MonthLeavers({..._rules, rule.memberId: rule});

  /// False for a record of [memberId] on [dateKey] that an admin
  /// removed from the month.
  bool counts(String? memberId, String? dateKey) {
    if (memberId == null || dateKey == null) return true;

    final rule = _rules[memberId];
    if (rule == null || rule.choice != LeavingChoice.removeAll) return true;

    return dateKey.compareTo(rule.leftOn) > 0;
  }

  /// True when [memberId] is charged only for what they ate, not the
  /// minimum meals.
  bool skipsMinimum(String memberId) =>
      _rules[memberId]?.choice == LeavingChoice.actualOnly;
}

/// Everything an admin decided for one month that changes how its
/// records count: meals cancelled for everyone, and members who left.
class MonthRules {
  const MonthRules({
    this.cancellations = MealCancellations.none,
    this.leavers = MonthLeavers.none,
  });

  static const MonthRules none = MonthRules();

  factory MonthRules.fromSettings(Map<String, dynamic>? settings) {
    return MonthRules(
      cancellations: MealCancellations.fromSettings(settings),
      leavers: MonthLeavers.fromSettings(settings),
    );
  }

  final MealCancellations cancellations;
  final MonthLeavers leavers;

  /// [meals] as they count: cancelled meals as zero, and records an
  /// admin removed left out.
  List<MealRecord> applyToMeals(Iterable<MealRecord> meals) {
    return [
      for (final meal in cancellations.applyAll(meals))
        if (leavers.counts(meal.userId, _mealDateKey(meal))) meal,
    ];
  }

  /// False for an expense an admin removed with the member who paid it.
  bool countsExpense(ExpenseRecord expense) {
    final date = expense.date;
    return leavers.counts(
      expense.paidById,
      date == null ? null : dateKeyOf(date),
    );
  }

  static String? _mealDateKey(MealRecord meal) {
    final saved = meal.dateKey;
    if (saved != null && saved.isNotEmpty) return saved;

    return RegExp(r'_(\d{4}-\d{2}-\d{2})$').firstMatch(meal.id)?.group(1);
  }

  static String dateKeyOf(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// When Remove All may be offered: only for a member with fewer than
/// [maxMeals] meals and less than [maxExpense] paid in the month, so
/// removing them barely changes anyone's balance.
class RemoveAllLimits {
  const RemoveAllLimits({
    this.maxMeals = defaultMaxMeals,
    this.maxExpense = defaultMaxExpense,
  });

  static const double defaultMaxMeals = 5;
  static const double defaultMaxExpense = 200;

  final double maxMeals;
  final double maxExpense;

  bool allows({required double meals, required double spending}) {
    return meals < maxMeals && spending < maxExpense;
  }
}
