import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_log.dart';
import 'group_member_service.dart';
import 'meal_plan.dart';
import 'meal_plan_service.dart';
import 'month_archive.dart';
import 'month_records.dart';
import 'month_rules.dart';
import 'monthly_calculator.dart';

/// How a member left the hostel.
enum LeavingWay {
  /// They left on their own.
  left,

  /// An admin made them alumni, so they can be restored.
  alumni,

  /// An admin removed them for good. Their records still stay.
  deleted;

  static LeavingWay fromName(Object? name) {
    for (final way in values) {
      if (way.name == name) return way;
    }
    return left;
  }
}

/// A member who left, kept in `groups/{id}/departures`, with how their
/// month counts. One that left on their own waits for an admin, and
/// counts as [LeavingChoice.normal] until one decides.
class Departure {
  const Departure({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.way,
    required this.monthKey,
    required this.leftOn,
    required this.choice,
  });

  factory Departure.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return Departure(
      id: document.id,
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? 'Member',
      way: LeavingWay.fromName(data['way']),
      monthKey: data['monthKey'] as String? ?? '',
      leftOn: data['leftOn'] as String? ?? '',
      choice: LeavingChoice.fromName(data['choice']),
    );
  }

  final String id;
  final String memberId;
  final String memberName;
  final LeavingWay way;

  /// The month it is for (`YYYY-MM`) and the day they left.
  final String monthKey;
  final String leftOn;

  /// Null while an admin has not decided.
  final LeavingChoice? choice;

  bool get isPending => choice == null;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// A member's month at the time they leave, and their balance under
/// each choice, shown to the admin before they choose.
class DepartureSummary {
  const DepartureSummary({
    required this.meals,
    required this.spending,
    required this.balances,
  });

  static const DepartureSummary empty = DepartureSummary(
    meals: 0,
    spending: 0,
    balances: {},
  );

  /// Meals they ate this month, and what they paid for the hostel.
  final double meals;
  final double spending;

  /// Their final balance under each choice: positive when they should
  /// get money back, negative when they owe.
  final Map<LeavingChoice, int> balances;

  /// False when there is nothing of theirs this month, so no choice is
  /// needed.
  bool get hasActivity => meals > 0 || spending > 0;
}

/// Records who left and how their month counts.
///
/// Nothing a member entered is ever changed or deleted: the choice is
/// saved under `leavers` in the month's settings, and the calculation
/// reads it from there.
class MemberDepartureService {
  MemberDepartureService._();

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _group(String groupId) =>
      _firestore.collection('groups').doc(groupId);

  static CollectionReference<Map<String, dynamic>> _departures(
    String groupId,
  ) => _group(groupId).collection('departures');

  static DocumentReference<Map<String, dynamic>> _settings(
    String groupId,
    String monthKey,
  ) => _group(groupId).collection('monthlySettings').doc(monthKey);

  /// The months whose choices may still change at [now].
  static List<String> openMonthKeys(DateTime now) {
    final first = MonthLock.firstEditableDay(now);
    return {
      MonthlyCalculator.monthKey(first),
      MonthlyCalculator.monthKey(now),
    }.toList();
  }

  /// Everyone who left in a month that is still open, newest first.
  /// Admins only.
  static Stream<List<Departure>> watchOpen(String groupId) {
    return _departures(groupId)
        .where('monthKey', whereIn: openMonthKeys(DateTime.now()))
        .snapshots()
        .map((snapshot) {
          final departures = snapshot.docs.map(Departure.fromDocument).toList()
            ..sort((a, b) => b.leftOn.compareTo(a.leftOn));
          return departures;
        });
  }

  /// [memberId]'s month up to [leftOn], with their balance under each
  /// choice, as if they had already left.
  static Future<DepartureSummary> summarize({
    required String groupId,
    required String memberId,
    required DateTime leftOn,
  }) async {
    final month = DateTime(leftOn.year, leftOn.month);
    final leftOnKey = MealPlans.dateKey(leftOn);

    final (settings, meals, expenses, plans, members) = await (
      _settings(groupId, MonthlyCalculator.monthKey(month)).get(),
      MonthRecords.meals(groupId, month).get(),
      MonthRecords.expenses(groupId, month).get(),
      MealPlanService.fetchAll(groupId),
      GroupMemberService.fetchActive(groupId),
    ).wait;

    final settingsData = settings.data();
    final minimumMeals =
        (settingsData?['minimumMeals'] as num?)?.toDouble() ?? 0;
    final shopDue = (settingsData?['shopDue'] as num?)?.toDouble() ?? 0;
    final baseRules = MonthRules.fromSettings(settingsData);

    final mealRecords = [
      for (final document in meals.docs)
        MealRecord.fromData(document.id, document.data()),
    ];
    final expenseRecords = [
      for (final document in expenses.docs)
        ExpenseRecord(
          paidById: document.data()['paidById'] as String?,
          paidByName: document.data()['paidByName'] as String?,
          date: (document.data()['date'] as Timestamp?)?.toDate(),
          amount: (document.data()['amount'] as num?)?.toDouble() ?? 0,
        ),
    ];

    // Everyone else stays; their meal plan stops on the day they leave.
    final others = [
      for (final member in members)
        if (member.id != memberId) CalcMember(id: member.id, name: member.name),
    ];
    final closedPlans = [
      for (final plan in plans)
        plan.memberId == memberId
            ? MemberMealPlan(
                memberId: plan.memberId,
                memberName: plan.memberName,
                rules: MealPlans.closedOn(plan.rules, leftOnKey),
              )
            : plan,
    ];
    final allMeals = [
      ...mealRecords,
      ...MealPlans.automaticMeals(
        plans: closedPlans,
        meals: mealRecords,
        activeMemberIds: {for (final member in others) member.id},
        month: month,
        today: DateTime.now(),
      ),
    ];

    MemberCalculation? resultFor(LeavingChoice choice) {
      final rules = MonthRules(
        cancellations: baseRules.cancellations,
        leavers: baseRules.leavers.withRule(
          LeaverRule(memberId: memberId, choice: choice, leftOn: leftOnKey),
        ),
      );
      final result = MonthlyCalculator.calculate(
        month: month,
        members: others,
        meals: allMeals,
        expenses: expenseRecords,
        minimumMeals: minimumMeals,
        shopDue: shopDue,
        rules: rules,
      );
      return result.members
          .where((member) => member.id == memberId)
          .firstOrNull;
    }

    final normal = resultFor(LeavingChoice.normal);

    return DepartureSummary(
      meals: normal?.actualMeals ?? 0,
      spending: normal?.spending ?? 0,
      balances: {
        for (final choice in LeavingChoice.values)
          choice: resultFor(choice)?.finalBalance ?? 0,
      },
    );
  }

  /// A new departure, written in [transaction] with the change that
  /// takes the member out. [choice] is null while an admin decides.
  static void addTo(
    Transaction transaction,
    String groupId, {
    required String memberId,
    required String memberName,
    required LeavingWay way,
    required DateTime leftOn,
    required LeavingChoice? choice,
  }) {
    final user = FirebaseAuth.instance.currentUser!;

    transaction.set(_departures(groupId).doc(), {
      'memberId': memberId,
      'memberName': memberName,
      'way': way.name,
      'monthKey': MonthlyCalculator.monthKey(leftOn),
      'leftOn': MealPlans.dateKey(leftOn),
      'choice': choice?.name,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      if (choice != null) ...{
        'decidedBy': user.uid,
        'decidedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  /// Saves [rule] in the month's settings, from a [settings] snapshot
  /// read earlier in the same [transaction]. Admins only.
  static void saveRuleIn(
    Transaction transaction, {
    required DocumentReference<Map<String, dynamic>> reference,
    required DocumentSnapshot<Map<String, dynamic>> settings,
    required LeaverRule rule,
  }) {
    if (settings.exists) {
      transaction.update(reference, {
        FieldPath([MonthLeavers.field, rule.memberId]): rule.toMap(),
      });
    } else {
      // The rules need a month's figures on every settings document.
      transaction.set(reference, {
        'monthKey': reference.id,
        'minimumMeals': 0,
        'shopDue': 0,
        MonthLeavers.field: {rule.memberId: rule.toMap()},
      });
    }
  }

  static DocumentReference<Map<String, dynamic>> settingsOf(
    String groupId,
    DateTime month,
  ) => _settings(groupId, MonthlyCalculator.monthKey(month));

  /// Saves how [departure] counts, or changes it while its month is
  /// open. Admins only.
  static Future<void> decide({
    required String groupId,
    required Departure departure,
    required LeavingChoice choice,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final settingsReference = _settings(groupId, departure.monthKey);

    await _firestore.runTransaction((transaction) async {
      final settings = await transaction.get(settingsReference);

      saveRuleIn(
        transaction,
        reference: settingsReference,
        settings: settings,
        rule: LeaverRule(
          memberId: departure.memberId,
          choice: choice,
          leftOn: departure.leftOn,
        ),
      );
      transaction.update(_departures(groupId).doc(departure.id), {
        'choice': choice.name,
        'decidedBy': user.uid,
        'decidedAt': FieldValue.serverTimestamp(),
      });
      ActivityLog.addToTransaction(
        transaction,
        groupId,
        kind: ActivityKind.leavingChosen,
        memberId: departure.memberId,
        memberName: departure.memberName,
        subject: choice.label,
        day: departure.monthKey,
      );
    });
  }
}
