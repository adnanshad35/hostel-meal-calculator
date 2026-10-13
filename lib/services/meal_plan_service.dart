import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'meal_plan.dart';

/// Reads and saves `groups/{groupId}/mealPlans`, one document per
/// member, stored under the member's id.
class MealPlanService {
  MealPlanService._();

  static CollectionReference<Map<String, dynamic>> _plans(String groupId) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('mealPlans');
  }

  static List<MemberMealPlan> _read(QuerySnapshot<Map<String, dynamic>> data) {
    return [
      for (final document in data.docs)
        MemberMealPlan.fromData(document.id, document.data()),
    ];
  }

  /// Every member's plan, live.
  static Stream<List<MemberMealPlan>> watchAll(String groupId) {
    return _plans(groupId).snapshots().map(_read);
  }

  /// One member's plan, live. Empty when they have none.
  static Stream<MemberMealPlan> watch(String groupId, String memberId) {
    return _plans(groupId).doc(memberId).snapshots().map((document) {
      return MemberMealPlan.fromData(
        memberId,
        document.data() ?? const <String, dynamic>{},
      );
    });
  }

  static Future<List<MemberMealPlan>> fetchAll(String groupId) async {
    return _read(await _plans(groupId).get());
  }

  static Future<MemberMealPlan> fetch(String groupId, String memberId) async {
    final document = await _plans(groupId).doc(memberId).get();

    return MemberMealPlan.fromData(
      memberId,
      document.data() ?? const <String, dynamic>{},
    );
  }

  static Future<void> save({
    required String groupId,
    required String memberId,
    required String memberName,
    required List<MealPlanRule> rules,
  }) {
    return _plans(groupId).doc(memberId).set({
      'memberId': memberId,
      'memberName': memberName,
      'rules': [for (final rule in rules) rule.toMap()],
      'updatedBy': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stops a member's plan after today, when they leave or are
  /// removed. What it already counted stays in the calculation.
  ///
  /// Never throws: a plan that could not be closed simply stops
  /// counting once the member is gone.
  static Future<void> close(String groupId, String memberId) async {
    try {
      final plan = await fetch(groupId, memberId);
      if (plan.rules.isEmpty) return;

      await save(
        groupId: groupId,
        memberId: memberId,
        memberName: plan.memberName,
        rules: MealPlans.closedOn(
          plan.rules,
          MealPlans.dateKey(DateTime.now()),
        ),
      );
    } on FirebaseException {
      // See above.
    }
  }

  /// Gives a non-app member's plan to the app user they were linked
  /// to. The app user's own rules, if any, take priority.
  static Future<void> move({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required String toMemberName,
  }) async {
    try {
      final source = await fetch(groupId, fromMemberId);
      if (source.rules.isEmpty) return;

      final target = await fetch(groupId, toMemberId);

      await save(
        groupId: groupId,
        memberId: toMemberId,
        memberName: toMemberName,
        rules: [...source.rules, ...target.rules],
      );
      await _plans(groupId).doc(fromMemberId).delete();
    } on FirebaseException {
      // The link itself has already succeeded.
    }
  }
}
