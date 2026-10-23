import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'group_member_service.dart';
import 'meal_plan.dart';
import 'meal_plan_service.dart';
import 'month_records.dart';
import 'monthly_calculator.dart';

/// When a month's meals and expenses may still be changed.
///
/// A month is open while it runs and for the first [lastEditDay] days
/// of the next one; after that it is locked. Its records are kept in
/// full for one more month, then only its summary is kept.
class MonthLock {
  MonthLock._();

  /// The last day of the next month on which a month can be changed.
  static const lastEditDay = 7;

  /// True while the meals and expenses of [month] may be changed.
  static bool canEdit(DateTime month, DateTime now) {
    final current = DateTime(now.year, now.month);
    final target = DateTime(month.year, month.month);
    final previous = DateTime(now.year, now.month - 1);

    return target == current || (target == previous && now.day <= lastEditDay);
  }

  /// The earliest date a meal or expense can be entered for at [now].
  static DateTime firstEditableDay(DateTime now) {
    return now.day <= lastEditDay
        ? DateTime(now.year, now.month - 1)
        : DateTime(now.year, now.month);
  }

  /// True once [month]'s meals and expenses can no longer change, so
  /// its summary is the last word.
  static bool isFinal(DateTime month, DateTime now) {
    final target = DateTime(month.year, month.month);
    return target.isBefore(DateTime(now.year, now.month)) &&
        !canEdit(month, now);
  }

  /// True when [month]'s own records are no longer kept at [now]:
  /// only its summary is. Last month is kept in full.
  static bool isSummaryOnly(DateTime month, DateTime now) {
    return DateTime(
      month.year,
      month.month,
    ).isBefore(DateTime(now.year, now.month - 1));
  }
}

/// A month's calculation as saved in its `monthlySettings` document,
/// under `summary`, so it outlives the month's own records.
class MonthSummary {
  MonthSummary._();

  static Map<String, dynamic> toMap(
    MonthlyCalculation result, {
    required bool isFinal,
  }) {
    return {
      'isFinal': isFinal,
      'mealRate': result.mealRate,
      'totalMealNumber': result.totalMealNumber,
      'totalActualMeals': result.totalActualMeals,
      'memberPaidExpenses': result.memberPaidExpenses,
      'shopDue': result.shopDue,
      'totalExpense': result.totalExpense,
      'members': [
        for (final member in result.members)
          {
            'id': member.id,
            'name': member.name,
            'isFormer': member.isFormer,
            'actualMeals': member.actualMeals,
            'mealNumber': member.mealNumber,
            'spending': member.spending,
            'mealExpense': member.mealExpense,
            'exactBalance': member.exactBalance,
            'finalBalance': member.finalBalance,
          },
      ],
      'savedAt': FieldValue.serverTimestamp(),
    };
  }

  /// The calculation saved in [settings], or null when there is none.
  static MonthlyCalculation? fromSettings(Map<String, dynamic>? settings) {
    final summary = settings?['summary'];
    if (summary is! Map) return null;

    double number(Map data, String key) => (data[key] as num?)?.toDouble() ?? 0;

    return MonthlyCalculation(
      totalMealNumber: number(summary, 'totalMealNumber'),
      totalActualMeals: number(summary, 'totalActualMeals'),
      memberPaidExpenses: number(summary, 'memberPaidExpenses'),
      shopDue: number(summary, 'shopDue'),
      totalExpense: number(summary, 'totalExpense'),
      mealRate: number(summary, 'mealRate'),
      members: [
        for (final member in (summary['members'] as List?) ?? const [])
          if (member is Map)
            MemberCalculation(
              id: member['id'] as String? ?? '',
              name: member['name'] as String? ?? 'Member',
              isFormer: member['isFormer'] == true,
              actualMeals: number(member, 'actualMeals'),
              mealNumber: number(member, 'mealNumber'),
              spending: number(member, 'spending'),
              mealExpense: number(member, 'mealExpense'),
              exactBalance: number(member, 'exactBalance'),
              finalBalance: (member['finalBalance'] as num?)?.round() ?? 0,
            ),
      ],
    );
  }

  /// True when [settings] holds a summary that can no longer change.
  static bool isFinal(Map<String, dynamic>? settings) {
    final summary = settings?['summary'];
    return summary is Map && summary['isFinal'] == true;
  }
}

/// Saves each past month's summary and clears the records that are no
/// longer kept. Run by an admin's app, since there is no server.
class MonthArchive {
  MonthArchive._();

  /// How many past months are looked at.
  static const monthsBack = 12;

  /// Hostels already handled since the app started.
  static final Set<String> _done = {};

  /// Runs at most once per hostel each time the app starts. Failures
  /// are left for the next start.
  static Future<void> runOnce(String groupId) async {
    if (!_done.add(groupId)) return;

    try {
      await _run(groupId, DateTime.now());
    } catch (error) {
      _done.remove(groupId);
      debugPrint('Month archive failed: $error');
    }
  }

  static Future<void> _run(String groupId, DateTime now) async {
    final group = FirebaseFirestore.instance.collection('groups').doc(groupId);
    final groupData = (await group.get()).data();
    final created = (groupData?['createdAt'] as Timestamp?)?.toDate();
    final settingsSnapshot = await group.collection('monthlySettings').get();
    final settingsByMonth = {
      for (final document in settingsSnapshot.docs)
        document.id: document.data(),
    };

    List<CalcMember>? members;
    List<MemberMealPlan>? plans;

    for (var back = 1; back <= monthsBack; back++) {
      final month = DateTime(now.year, now.month - back);
      if (created != null &&
          month.isBefore(DateTime(created.year, created.month))) {
        break;
      }

      final key = MonthlyCalculator.monthKey(month);
      final settings = settingsByMonth[key];
      final isFinal = MonthLock.isFinal(month, now);
      final hasFinalSummary = MonthSummary.isFinal(settings);
      final reference = group.collection('monthlySettings').doc(key);
      final kept = {
        'monthKey': key,
        'minimumMeals': (settings?['minimumMeals'] as num?)?.toDouble() ?? 0,
        'shopDue': (settings?['shopDue'] as num?)?.toDouble() ?? 0,
      };

      // Once a summary is final, nothing changes, except clearing the
      // records it was made from.
      if (!hasFinalSummary) {
        members ??= [
          for (final member in await GroupMemberService.fetchActive(groupId))
            CalcMember(id: member.id, name: member.name),
        ];
        plans ??= await MealPlanService.fetchAll(groupId);

        final result = await _calculate(
          groupId: groupId,
          month: month,
          members: members,
          plans: plans,
          minimumMeals: kept['minimumMeals'] as double,
          shopDue: kept['shopDue'] as double,
          now: now,
        );

        await reference.set({
          ...kept,
          'summary': MonthSummary.toMap(result, isFinal: isFinal),
        }, SetOptions(merge: true));
        if (!isFinal) continue;
      }

      if (MonthLock.isSummaryOnly(month, now) &&
          settings?['recordsErased'] != true) {
        await _eraseRecords(groupId, month);
        await reference.set({
          ...kept,
          'recordsErased': true,
        }, SetOptions(merge: true));
      }
    }
  }

  static Future<MonthlyCalculation> _calculate({
    required String groupId,
    required DateTime month,
    required List<CalcMember> members,
    required List<MemberMealPlan> plans,
    required double minimumMeals,
    required double shopDue,
    required DateTime now,
  }) async {
    final mealsSnapshot = await MonthRecords.meals(groupId, month).get();
    final expensesSnapshot = await MonthRecords.expenses(groupId, month).get();
    final meals = [
      for (final document in mealsSnapshot.docs)
        MealRecord.fromData(document.id, document.data()),
    ];

    return MonthlyCalculator.calculate(
      month: month,
      members: members,
      meals: [
        ...meals,
        ...MealPlans.automaticMeals(
          plans: plans,
          meals: meals,
          activeMemberIds: {for (final member in members) member.id},
          month: month,
          today: now,
        ),
      ],
      expenses: [
        for (final document in expensesSnapshot.docs)
          ExpenseRecord(
            paidById: document.data()['paidById'] as String?,
            paidByName: document.data()['paidByName'] as String?,
            date: (document.data()['date'] as Timestamp?)?.toDate(),
            amount: (document.data()['amount'] as num?)?.toDouble() ?? 0,
          ),
      ],
      minimumMeals: minimumMeals,
      shopDue: shopDue,
    );
  }

  /// Deletes [month]'s meal entries and expenses, a batch at a time.
  static Future<void> _eraseRecords(String groupId, DateTime month) async {
    final documents = [
      ...(await MonthRecords.meals(groupId, month).get()).docs,
      ...(await MonthRecords.expenses(groupId, month).get()).docs,
    ];

    for (var start = 0; start < documents.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final document in documents.skip(start).take(400)) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
