import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_log.dart';
import 'meal_plan.dart';
import 'profile_service.dart';

/// One member's part of an [InitialShare].
class ShareContribution {
  const ShareContribution({
    required this.memberId,
    required this.memberName,
    required this.amount,
    this.expenseId = '',
  });

  final String memberId;
  final String memberName;
  final double amount;

  /// The expense it is saved as; empty until saved.
  final String expenseId;
}

/// Money collected from members at the start of a month to buy food
/// for the whole month, such as rice and oil.
///
/// Each contribution is saved as an ordinary expense named
/// [InitialShare.name], paid by that member and marked with the
/// share's id. It therefore counts like any expense: in the member's
/// paid amount, and in full in the month's cost and meal rate.
class InitialShare {
  const InitialShare({
    required this.id,
    required this.date,
    required this.contributions,
  });

  static const String name = 'Initial Share';

  /// The `kind` of an expense that is part of a share.
  static const String kind = 'initialShare';

  final String id;
  final DateTime date;
  final List<ShareContribution> contributions;

  double get total => contributions.fold(
    0,
    (running, contribution) => running + contribution.amount,
  );

  static bool isPartOfShare(Map<String, dynamic> expense) =>
      expense['kind'] == kind;

  /// The shares in [expenses], newest first.
  static List<InitialShare> fromExpenses(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
  ) {
    final byId = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final expense in expenses) {
      final data = expense.data();
      if (!isPartOfShare(data) || data['date'] is! Timestamp) continue;

      final shareId = data['shareId'] as String? ?? expense.id;
      byId.putIfAbsent(shareId, () => []).add(expense);
    }

    final shares = [
      for (final entry in byId.entries)
        InitialShare(
          id: entry.key,
          date: (entry.value.first.data()['date'] as Timestamp).toDate(),
          contributions: [
            for (final expense in entry.value)
              ShareContribution(
                memberId: expense.data()['paidById'] as String? ?? '',
                memberName: expense.data()['paidByName'] as String? ?? 'Member',
                amount: (expense.data()['amount'] as num?)?.toDouble() ?? 0,
                expenseId: expense.id,
              ),
          ]..sort((a, b) => a.memberName.compareTo(b.memberName)),
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return shares;
  }

  /// The total of every share in [expenses].
  static double totalOf(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
  ) {
    double total = 0;
    for (final expense in expenses) {
      final data = expense.data();
      if (isPartOfShare(data)) {
        total += (data['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  /// [total] divided among [count] members in whole taka, the first
  /// ones taking a taka more when it does not divide evenly. Any
  /// paisa go to the first member, so the parts always add up.
  static List<double> splitEqually(double total, int count) {
    if (count <= 0 || total <= 0) return List.filled(count < 0 ? 0 : count, 0);

    final whole = total.floorToDouble();
    final base = (whole / count).floorToDouble();
    final extra = (whole - base * count).round();
    final paisa = ((total - whole) * 100).round() / 100;

    return [
      for (var index = 0; index < count; index++)
        base + (index < extra ? 1 : 0) + (index == 0 ? paisa : 0),
    ];
  }
}

class InitialShareService {
  InitialShareService._();

  static CollectionReference<Map<String, dynamic>> _expenses(String groupId) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('expenses');
  }

  static String _amount(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  /// Saves a share collected on [date]: one expense for each
  /// contribution, and one record in the hostel's history.
  static Future<void> add({
    required String groupId,
    required DateTime date,
    required List<ShareContribution> contributions,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final enteredByName =
        ProfileService.memberName ??
        (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email ?? 'Member');
    final shareId = _expenses(groupId).doc().id;
    final day = MealPlans.dateKey(date);
    final total = contributions.fold<double>(
      0,
      (running, contribution) => running + contribution.amount,
    );

    final batch = FirebaseFirestore.instance.batch();
    for (final contribution in contributions) {
      if (contribution.amount <= 0) continue;

      batch.set(_expenses(groupId).doc(), {
        'name': InitialShare.name,
        'description': '',
        'amount': contribution.amount,
        'date': Timestamp.fromDate(date),
        'paidById': contribution.memberId,
        'paidByName': contribution.memberName,
        'enteredBy': user.uid,
        'enteredByName': enteredByName,
        'kind': InitialShare.kind,
        'shareId': shareId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    ActivityLog.addTo(
      batch,
      groupId,
      kind: ActivityKind.expenseAdded,
      subject: InitialShare.name,
      day: day,
      details:
          '৳${_amount(total)} · ${contributions.length} '
          '${contributions.length == 1 ? 'member' : 'members'}',
    );
    await batch.commit();
  }

  /// Deletes [share]'s expenses, with a record in the hostel's history.
  static Future<void> delete({
    required String groupId,
    required InitialShare share,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final contribution in share.contributions) {
      batch.delete(_expenses(groupId).doc(contribution.expenseId));
    }
    ActivityLog.addTo(
      batch,
      groupId,
      kind: ActivityKind.expenseDeleted,
      subject: InitialShare.name,
      day: MealPlans.dateKey(share.date),
      details:
          '৳${_amount(share.total)} · ${share.contributions.length} '
          '${share.contributions.length == 1 ? 'member' : 'members'}',
    );
    await batch.commit();
  }
}
