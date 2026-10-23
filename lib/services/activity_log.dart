import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_service.dart';
import 'super_admin_service.dart';

/// What a record in the hostel's history is about.
enum ActivityKind {
  mealAdded,
  mealChanged,
  mealPlanChanged,
  expenseAdded,
  expenseChanged,
  expenseDeleted,
  minMealsSet,
  shopDueSet,
  monthReset,
  memberRemoved,
  adminMade,
  adminRemoved,
  hostelActivated,
  paymentSent,
  activationSet,
}

/// One change to the hostel, as every member sees it in its history.
class Activity {
  const Activity({
    required this.kind,
    required this.actorId,
    required this.actorName,
    this.memberId = '',
    this.memberName = '',
    this.subject = '',
    this.day = '',
    this.details = '',
    this.at,
  });

  /// Null for a record this app version does not know.
  static Activity? fromData(Map<String, dynamic> data) {
    final kind = ActivityKind.values
        .where((kind) => kind.name == data['kind'])
        .firstOrNull;
    if (kind == null) return null;

    final at = data['createdAt'];
    return Activity(
      kind: kind,
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Someone',
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      day: data['day'] as String? ?? '',
      details: data['details'] as String? ?? '',
      at: at is Timestamp ? at.toDate() : null,
    );
  }

  final ActivityKind kind;

  /// Who made the change.
  final String actorId;
  final String actorName;

  /// Whose meals, expense or role it changed, when it is someone's.
  final String memberId;
  final String memberName;

  /// What it was, such as an expense's name or a month.
  final String subject;

  /// The day it is for, as `YYYY-MM-DD`, or the month as `YYYY-MM`.
  final String day;

  /// The figures, such as "Lunch 1 → 2".
  final String details;

  /// When it happened; null until the server has saved it.
  final DateTime? at;

  /// "Karim's" for someone else, or nothing for the actor themselves.
  String get _whose =>
      memberId.isEmpty || memberId == actorId ? '' : "$memberName's ";

  /// What happened, in three parts: who, the verb, and what, such as
  /// ("Rahim", "changed", "Karim's meals"). The verb is shown in the
  /// colour of its [tone].
  (String, String, String) get parts {
    return switch (kind) {
      ActivityKind.mealAdded => (actorName, 'added', '${_whose}meals'),
      ActivityKind.mealChanged => (actorName, 'changed', '${_whose}meals'),
      ActivityKind.mealPlanChanged => (
        actorName,
        'changed',
        '${_whose}meal plan',
      ),
      ActivityKind.expenseAdded => (actorName, 'added', subject),
      ActivityKind.expenseChanged => (actorName, 'changed', subject),
      ActivityKind.expenseDeleted => (actorName, 'deleted', subject),
      ActivityKind.minMealsSet => (actorName, 'changed', 'Min Meals'),
      ActivityKind.shopDueSet => (actorName, 'changed', 'Shop Due'),
      ActivityKind.monthReset => (actorName, 'reset', subject),
      ActivityKind.memberRemoved => (actorName, 'removed', memberName),
      ActivityKind.adminMade => (actorName, 'made', '$memberName an admin'),
      ActivityKind.adminRemoved => (
        actorName,
        'removed',
        '$memberName as admin',
      ),
      ActivityKind.hostelActivated => (actorName, 'activated', 'the hostel'),
      ActivityKind.paymentSent => (actorName, 'sent', 'a bKash payment'),
      ActivityKind.activationSet => (actorName, 'changed', 'the activation'),
    };
  }

  /// One line saying what happened, such as "Rahim changed Karim's
  /// meals".
  String get sentence {
    final (who, verb, what) = parts;
    return '$who $verb $what';
  }

  /// Whether it added, changed or removed something.
  ActivityTone get tone => switch (kind) {
    ActivityKind.mealAdded ||
    ActivityKind.expenseAdded ||
    ActivityKind.adminMade ||
    ActivityKind.hostelActivated ||
    ActivityKind.paymentSent => ActivityTone.added,
    ActivityKind.expenseDeleted ||
    ActivityKind.monthReset ||
    ActivityKind.memberRemoved ||
    ActivityKind.adminRemoved => ActivityTone.removed,
    _ => ActivityTone.changed,
  };

  /// True for a change that deletes something.
  bool get isRemoval => tone == ActivityTone.removed;
}

/// How a change is coloured: green for added, gold for changed, red
/// for deleted or removed.
enum ActivityTone { added, changed, removed }

/// The hostel's history: every change to meals, expenses, the month's
/// figures and members, kept where every member can read it. The
/// security rules let records be added but never changed or deleted,
/// so not even an admin can hide one.
class ActivityLog {
  ActivityLog._();

  static CollectionReference<Map<String, dynamic>> _log(String groupId) =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('activity');

  /// The newest records first, [limit] at a time.
  static Query<Map<String, dynamic>> newest(String groupId, {int limit = 50}) {
    return _log(groupId).orderBy('createdAt', descending: true).limit(limit);
  }

  static Map<String, dynamic> _record({
    required ActivityKind kind,
    String memberId = '',
    String memberName = '',
    String subject = '',
    String day = '',
    String details = '',
  }) {
    final user = FirebaseAuth.instance.currentUser!;

    return {
      'kind': kind.name,
      'actorId': user.uid,
      // The super admin acts for HostelMate, not as a person.
      'actorName': SuperAdminService.isSuperAdmin
          ? 'HostelMate'
          : ProfileService.memberName ?? user.displayName ?? 'Member',
      'memberId': memberId,
      'memberName': memberName,
      'subject': subject,
      'day': day,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Adds the record to [batch], so it is saved together with the
  /// change it describes, or not at all.
  static void addTo(
    WriteBatch batch,
    String groupId, {
    required ActivityKind kind,
    String memberId = '',
    String memberName = '',
    String subject = '',
    String day = '',
    String details = '',
  }) {
    batch.set(
      _log(groupId).doc(),
      _record(
        kind: kind,
        memberId: memberId,
        memberName: memberName,
        subject: subject,
        day: day,
        details: details,
      ),
    );
  }

  /// Adds the record to [transaction], so it is saved together with
  /// the change it describes, or not at all.
  static void addToTransaction(
    Transaction transaction,
    String groupId, {
    required ActivityKind kind,
    String memberId = '',
    String memberName = '',
    String subject = '',
    String day = '',
    String details = '',
  }) {
    transaction.set(
      _log(groupId).doc(),
      _record(
        kind: kind,
        memberId: memberId,
        memberName: memberName,
        subject: subject,
        day: day,
        details: details,
      ),
    );
  }

  /// Saves a record on its own, for a change made some other way.
  static Future<void> add(
    String groupId, {
    required ActivityKind kind,
    String memberId = '',
    String memberName = '',
    String subject = '',
    String day = '',
    String details = '',
  }) {
    return _log(groupId).add(
      _record(
        kind: kind,
        memberId: memberId,
        memberName: memberName,
        subject: subject,
        day: day,
        details: details,
      ),
    );
  }

  static String _seenKey(String groupId) => 'activitySeen_$groupId';

  /// When the signed-in member last opened the history on this phone,
  /// or null if never.
  static Future<DateTime?> lastSeen(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_seenKey(groupId));
      return millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (_) {
      return null;
    }
  }

  static Future<void> markSeen(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _seenKey(groupId),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Only the dot depends on it.
    }
  }

  /// True when someone else changed something after [seen]. The
  /// member's own changes never count as new for them.
  static bool hasUnseen(
    Iterable<Activity> activities, {
    required DateTime? seen,
    required String userId,
  }) {
    return activities.any(
      (activity) =>
          activity.actorId != userId &&
          activity.at != null &&
          (seen == null || activity.at!.isAfter(seen)),
    );
  }

  /// A count, such as 1.5 meals, without a needless ".0".
  static String number(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  /// "Lunch 1 → 2 · Dinner 1" for a change, or "Lunch 1 · Dinner 1"
  /// for a new entry.
  static String mealDetails({
    required double lunch,
    required double dinner,
    double? oldLunch,
    double? oldDinner,
  }) {
    String part(String label, double now, double? before) =>
        before == null || before == now
        ? '$label ${number(now)}'
        : '$label ${number(before)} → ${number(now)}';

    return '${part('Lunch', lunch, oldLunch)} · '
        '${part('Dinner', dinner, oldDinner)}';
  }

  /// Only what changed, such as "৳500 → ৳800", or "" when nothing did.
  static String changes(Map<String, (String, String)> fields) {
    return [
      for (final MapEntry(key: label, value: (before, after)) in fields.entries)
        if (before != after)
          label.isEmpty ? '$before → $after' : '$label: $before → $after',
    ].join(' · ');
  }
}
