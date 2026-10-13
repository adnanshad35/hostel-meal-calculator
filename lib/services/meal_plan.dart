import 'monthly_calculator.dart';

/// One line of a member's meal plan: how many lunches and dinners to
/// count on days the member has no meal entry.
///
/// A standing rule ("every day") runs from its start until the member
/// changes it. Any other rule covers a fixed range, such as a trip,
/// and takes priority over the standing rule while it lasts.
class MealPlanRule {
  const MealPlanRule({
    required this.lunch,
    required this.dinner,
    required this.fromDate,
    this.startsAtDinner = false,
    this.toDate,
    this.endsAfterLunch = false,
    this.isStanding = false,
  });

  factory MealPlanRule.fromMap(Map<String, dynamic> data) {
    return MealPlanRule(
      lunch: (data['lunch'] as num?)?.toDouble() ?? 0,
      dinner: (data['dinner'] as num?)?.toDouble() ?? 0,
      fromDate: data['fromDate'] as String? ?? '',
      startsAtDinner: data['startsAtDinner'] == true,
      toDate: data['toDate'] as String?,
      endsAfterLunch: data['endsAfterLunch'] == true,
      isStanding: data['isStanding'] == true,
    );
  }

  final double lunch;
  final double dinner;

  /// First day covered, as `YYYY-MM-DD`.
  final String fromDate;

  /// True when the first day's lunch is not covered.
  final bool startsAtDinner;

  /// Last day covered, or null while the rule has no end.
  final String? toDate;

  /// True when the last day's dinner is not covered.
  final bool endsAfterLunch;

  final bool isStanding;

  /// Whether this rule decides the lunch or the dinner of [dateKey].
  bool covers(String dateKey, {required bool dinnerSlot}) {
    if (dateKey.compareTo(fromDate) < 0) return false;
    if (dateKey == fromDate && startsAtDinner && !dinnerSlot) return false;

    final end = toDate;
    if (end != null) {
      if (dateKey.compareTo(end) > 0) return false;
      if (dateKey == end && endsAfterLunch && dinnerSlot) return false;
    }

    return true;
  }

  MealPlanRule endingOn(String lastDate) {
    return MealPlanRule(
      lunch: lunch,
      dinner: dinner,
      fromDate: fromDate,
      startsAtDinner: startsAtDinner,
      toDate: lastDate,
      isStanding: isStanding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lunch': lunch,
      'dinner': dinner,
      'fromDate': fromDate,
      'startsAtDinner': startsAtDinner,
      'toDate': toDate,
      'endsAfterLunch': endsAfterLunch,
      'isStanding': isStanding,
    };
  }
}

/// The meals a plan gives for one day.
class PlannedMeals {
  const PlannedMeals({required this.lunch, required this.dinner});

  final double lunch;
  final double dinner;

  double get total => lunch + dinner;
}

/// Everything saved for one member under `groups/{id}/mealPlans`.
class MemberMealPlan {
  const MemberMealPlan({
    required this.memberId,
    required this.memberName,
    required this.rules,
  });

  factory MemberMealPlan.fromData(String id, Map<String, dynamic> data) {
    final rules = <MealPlanRule>[];

    for (final rule in data['rules'] as List? ?? const []) {
      if (rule is Map) {
        final parsed = MealPlanRule.fromMap(Map<String, dynamic>.from(rule));
        if (parsed.fromDate.isNotEmpty) rules.add(parsed);
      }
    }

    return MemberMealPlan(
      memberId: id,
      memberName: data['memberName'] as String? ?? 'Member',
      rules: rules,
    );
  }

  final String memberId;
  final String memberName;

  /// In the order they were added. Among ranges, a later one wins.
  final List<MealPlanRule> rules;
}

/// Works out what a meal plan counts for each day.
class MealPlans {
  MealPlans._();

  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime dateOf(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static MealPlanRule? _ruleFor(
    List<MealPlanRule> rules,
    String dateKey, {
    required bool dinnerSlot,
  }) {
    MealPlanRule? best;

    for (final rule in rules) {
      if (!rule.covers(dateKey, dinnerSlot: dinnerSlot)) continue;

      if (best == null) {
        best = rule;
      } else if (rule.isStanding != best.isStanding) {
        // A range, such as a trip, beats the everyday rule.
        if (!rule.isStanding) best = rule;
      } else if (!rule.isStanding) {
        // The range added last wins.
        best = rule;
      } else if (rule.fromDate.compareTo(best.fromDate) >= 0) {
        // The everyday rule that started most recently wins.
        best = rule;
      }
    }

    return best;
  }

  /// What [rules] count for [dateKey], or null when no rule covers
  /// either meal of that day.
  static PlannedMeals? forDay(List<MealPlanRule> rules, String dateKey) {
    final lunchRule = _ruleFor(rules, dateKey, dinnerSlot: false);
    final dinnerRule = _ruleFor(rules, dateKey, dinnerSlot: true);

    if (lunchRule == null && dinnerRule == null) return null;

    return PlannedMeals(
      lunch: lunchRule?.lunch ?? 0,
      dinner: dinnerRule?.dinner ?? 0,
    );
  }

  /// The everyday rule in effect on [dateKey], if any.
  static MealPlanRule? standingOn(List<MealPlanRule> rules, String dateKey) {
    return _ruleFor(
      rules.where((rule) => rule.isStanding).toList(),
      dateKey,
      dinnerSlot: true,
    );
  }

  /// [rules] with the everyday meals changed from [fromDate] onward.
  /// Earlier days keep what they were counted as.
  static List<MealPlanRule> withStanding(
    List<MealPlanRule> rules, {
    required double lunch,
    required double dinner,
    required String fromDate,
  }) {
    return [
      for (final rule in rules)
        if (!rule.isStanding || rule.fromDate.compareTo(fromDate) < 0) rule,
      MealPlanRule(
        lunch: lunch,
        dinner: dinner,
        fromDate: fromDate,
        isStanding: true,
      ),
    ];
  }

  /// [rules] with [rule] stopped after [lastDate], or removed when it
  /// would not have started by then.
  static List<MealPlanRule> withRuleEnded(
    List<MealPlanRule> rules,
    MealPlanRule rule,
    String lastDate,
  ) {
    return [
      for (final existing in rules)
        if (!identical(existing, rule))
          existing
        else if (existing.fromDate.compareTo(lastDate) <= 0)
          existing.endingOn(lastDate),
    ];
  }

  /// [rules] stopped after [lastDate], for a member who is leaving.
  /// Days already counted stay counted.
  static List<MealPlanRule> closedOn(
    List<MealPlanRule> rules,
    String lastDate,
  ) {
    return [
      for (final rule in rules)
        if (rule.fromDate.compareTo(lastDate) <= 0)
          if (rule.toDate != null && rule.toDate!.compareTo(lastDate) <= 0)
            rule
          else
            rule.endingOn(lastDate),
    ];
  }

  /// Meal records for the days of [month] that a plan counts and the
  /// member has no entry for. Days after [today] are never counted.
  ///
  /// For someone no longer in [activeMemberIds], only rules that were
  /// given an end are used, so a plan left behind cannot keep counting.
  static List<MealRecord> automaticMeals({
    required Iterable<MemberMealPlan> plans,
    required Iterable<MealRecord> meals,
    required Set<String> activeMemberIds,
    required DateTime month,
    required DateTime today,
  }) {
    final monthKey = MonthlyCalculator.monthKey(month);
    final todayKey = dateKey(today);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final entered = <String>{};
    for (final meal in meals) {
      final userId = meal.userId;
      if (userId == null) continue;

      final mealDate = meal.dateKey;
      entered.add(mealDate == null ? meal.id : '${userId}_$mealDate');
    }

    final automatic = <MealRecord>[];

    for (final plan in plans) {
      final rules = activeMemberIds.contains(plan.memberId)
          ? plan.rules
          : plan.rules.where((rule) => rule.toDate != null).toList();

      if (rules.isEmpty) continue;

      for (var day = 1; day <= daysInMonth; day++) {
        final key = dateKey(DateTime(month.year, month.month, day));
        if (key.compareTo(todayKey) > 0) break;

        final id = '${plan.memberId}_$key';
        if (entered.contains(id)) continue;

        final planned = forDay(rules, key);
        if (planned == null || planned.total <= 0) continue;

        automatic.add(
          MealRecord(
            id: id,
            userId: plan.memberId,
            userName: plan.memberName,
            monthKey: monthKey,
            dateKey: key,
            lunch: planned.lunch,
            dinner: planned.dinner,
            isAutomatic: true,
          ),
        );
      }
    }

    return automatic;
  }
}
