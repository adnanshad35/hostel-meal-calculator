import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity_log.dart';
import 'meal_cancellation.dart';
import 'monthly_calculator.dart';
import 'notification_service.dart';

/// Reads and saves the meals an admin cancelled for the whole hostel,
/// kept in each month's `monthlySettings` document.
class MealCancellationService {
  MealCancellationService._();

  static DocumentReference<Map<String, dynamic>> _settings(
    String groupId,
    String monthKey,
  ) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('monthlySettings')
        .doc(monthKey);
  }

  /// Cancels the [lunch] and [dinner] of [day] for everyone, or brings
  /// them back when both are false. The hostel's history records it
  /// and the members are told. Admins only.
  static Future<void> save({
    required String groupId,
    required DateTime day,
    required bool lunch,
    required bool dinner,
  }) async {
    final monthKey = MonthlyCalculator.monthKey(day);
    final dateKey = _dateKey(day);
    final reference = _settings(groupId, monthKey);
    final restore = !lunch && !dinner;
    var previous = MealCancellations.none.dayOf(dateKey);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      previous = MealCancellations.fromSettings(snapshot.data()).dayOf(dateKey);

      final value = restore
          ? FieldValue.delete()
          : {'lunch': lunch, 'dinner': dinner};

      if (snapshot.exists) {
        transaction.update(reference, {
          FieldPath([MealCancellations.field, dateKey]): value,
        });
      } else if (!restore) {
        // The rules need a month's figures on every settings document.
        transaction.set(reference, {
          'monthKey': monthKey,
          'minimumMeals': 0,
          'shopDue': 0,
          MealCancellations.field: {dateKey: value},
        });
      }

      final changed = restore
          ? previous
          : CancelledDay(dateKey: dateKey, lunch: lunch, dinner: dinner);
      if (changed == null) return;

      ActivityLog.addToTransaction(
        transaction,
        groupId,
        kind: restore ? ActivityKind.mealRestored : ActivityKind.mealCancelled,
        subject: changed.label,
        day: dateKey,
      );
    });

    final changed = restore
        ? previous
        : CancelledDay(dateKey: dateKey, lunch: lunch, dinner: dinner);
    if (changed == null) return;

    final date = '${day.day} ${_monthNames[day.month - 1]}';
    await NotificationService.notifyGroup(
      groupId: groupId,
      type: 'mealCancelled',
      title: restore ? 'Meal On' : 'Meal Off',
      message: restore
          ? '${changed.label} on $date is on again.'
          : '${changed.label} on $date is off for everyone.',
    );
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
