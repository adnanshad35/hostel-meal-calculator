import 'package:cloud_firestore/cloud_firestore.dart';

import 'meal_plan.dart';

/// Queries for one month of a hostel's meals and expenses.
///
/// Screens read a month at a time through these, so opening one costs
/// that month's records and not the hostel's whole history.
class MonthRecords {
  MonthRecords._();

  static DocumentReference<Map<String, dynamic>> _group(String groupId) {
    return FirebaseFirestore.instance.collection('groups').doc(groupId);
  }

  /// The meal entries of [month], found by their `dateKey`.
  static Query<Map<String, dynamic>> meals(String groupId, DateTime month) {
    return _group(groupId)
        .collection('meals')
        .where(
          'dateKey',
          isGreaterThanOrEqualTo: MealPlans.dateKey(
            DateTime(month.year, month.month),
          ),
        )
        .where(
          'dateKey',
          isLessThan: MealPlans.dateKey(DateTime(month.year, month.month + 1)),
        );
  }

  /// The expenses of [month], found by their `date`.
  static Query<Map<String, dynamic>> expenses(String groupId, DateTime month) {
    return _group(groupId)
        .collection('expenses')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(month.year, month.month),
          ),
        )
        .where(
          'date',
          isLessThan: Timestamp.fromDate(DateTime(month.year, month.month + 1)),
        );
  }
}
