import 'package:cloud_firestore/cloud_firestore.dart';

import 'month_rules.dart';
import 'monthly_calculator.dart';

/// Reads a month's [MonthRules] from its `monthlySettings` document.
class MonthRulesService {
  MonthRulesService._();

  static DocumentReference<Map<String, dynamic>> _settings(
    String groupId,
    DateTime month,
  ) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('monthlySettings')
        .doc(MonthlyCalculator.monthKey(month));
  }

  /// The rules of [month], live.
  static Stream<MonthRules> watch(String groupId, DateTime month) {
    return _settings(
      groupId,
      month,
    ).snapshots().map((snapshot) => MonthRules.fromSettings(snapshot.data()));
  }

  /// The rules of [month], once. None when they cannot be read, so a
  /// failure never blocks a meal entry.
  static Future<MonthRules> fetch(String groupId, DateTime month) async {
    try {
      final snapshot = await _settings(groupId, month).get();
      return MonthRules.fromSettings(snapshot.data());
    } on FirebaseException {
      return MonthRules.none;
    }
  }
}
