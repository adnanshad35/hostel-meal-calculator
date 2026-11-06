import 'monthly_calculator.dart';

/// Which meals of one day an admin cancelled.
class CancelledDay {
  const CancelledDay({
    required this.dateKey,
    required this.lunch,
    required this.dinner,
  });

  /// The day, as `YYYY-MM-DD`.
  final String dateKey;
  final bool lunch;
  final bool dinner;

  /// "Lunch", "Dinner" or "Lunch & Dinner".
  String get label => lunch && dinner
      ? 'Lunch & Dinner'
      : lunch
      ? 'Lunch'
      : 'Dinner';
}

/// Meals an admin cancelled for the whole hostel, such as when the
/// cook is away. A cancelled meal counts as zero for every member,
/// whatever they entered or their meal plan says, so undoing it
/// brings their own figures back.
///
/// Saved in the month's `monthlySettings` document under
/// `cancelledMeals`, as `{'2026-11-12': {'lunch': true}}`.
class MealCancellations {
  const MealCancellations([this._days = const {}]);

  static const MealCancellations none = MealCancellations();

  /// The settings field the cancellations are saved in.
  static const String field = 'cancelledMeals';

  factory MealCancellations.fromSettings(Map<String, dynamic>? settings) {
    final saved = settings?[field];
    if (saved is! Map) return none;

    final days = <String, CancelledDay>{};
    saved.forEach((key, value) {
      if (key is! String || value is! Map) return;

      final lunch = value['lunch'] == true;
      final dinner = value['dinner'] == true;
      if (!lunch && !dinner) return;

      days[key] = CancelledDay(dateKey: key, lunch: lunch, dinner: dinner);
    });

    return MealCancellations(days);
  }

  final Map<String, CancelledDay> _days;

  bool get isEmpty => _days.isEmpty;

  /// Every cancelled day, earliest first.
  List<CancelledDay> get days =>
      _days.values.toList()..sort((a, b) => a.dateKey.compareTo(b.dateKey));

  CancelledDay? dayOf(String dateKey) => _days[dateKey];

  bool isLunchCancelled(String dateKey) => _days[dateKey]?.lunch ?? false;

  bool isDinnerCancelled(String dateKey) => _days[dateKey]?.dinner ?? false;

  /// The day of [meal], from its `dateKey`, or from an id such as
  /// `uid_2026-11-12` for an entry saved without one.
  static String? _dateKeyOf(MealRecord meal) {
    final saved = meal.dateKey;
    if (saved != null && saved.isNotEmpty) return saved;

    return RegExp(r'_(\d{4}-\d{2}-\d{2})$').firstMatch(meal.id)?.group(1);
  }

  /// [meal] with its cancelled meals counted as zero.
  MealRecord apply(MealRecord meal) {
    if (_days.isEmpty) return meal;

    final dateKey = _dateKeyOf(meal);
    final day = dateKey == null ? null : _days[dateKey];
    if (day == null) return meal;

    return MealRecord(
      id: meal.id,
      userId: meal.userId,
      userName: meal.userName,
      monthKey: meal.monthKey,
      dateKey: meal.dateKey,
      lunch: day.lunch ? 0 : meal.lunch,
      dinner: day.dinner ? 0 : meal.dinner,
      isAutomatic: meal.isAutomatic,
    );
  }

  List<MealRecord> applyAll(Iterable<MealRecord> meals) {
    if (_days.isEmpty) return meals.toList();
    return [for (final meal in meals) apply(meal)];
  }
}
