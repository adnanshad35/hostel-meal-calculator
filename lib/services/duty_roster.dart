import 'package:cloud_firestore/cloud_firestore.dart';

import 'meal_plan.dart';

/// One member's turn at looking after the hostel: the days they are
/// responsible for it. Saved on the hostel itself, under `duties`.
class DutyTurn {
  const DutyTurn({
    required this.memberId,
    required this.memberName,
    required this.fromDate,
    required this.toDate,
  });

  final String memberId;
  final String memberName;

  /// First and last day of the turn, as `YYYY-MM-DD`.
  final String fromDate;
  final String toDate;

  bool covers(String dateKey) {
    return dateKey.compareTo(fromDate) >= 0 && dateKey.compareTo(toDate) <= 0;
  }

  bool overlaps(DutyTurn other) {
    return fromDate.compareTo(other.toDate) <= 0 &&
        other.fromDate.compareTo(toDate) <= 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'fromDate': fromDate,
      'toDate': toDate,
    };
  }
}

/// Where a turn stands on a given day.
enum DutyStatus { done, current, upcoming }

/// Who looks after the hostel, and when.
class DutyRoster {
  const DutyRoster(this.turns);

  /// Reads the turns from a `groups/{id}` document, earliest first.
  /// Anything malformed is skipped.
  factory DutyRoster.fromGroupData(Map<String, dynamic>? group) {
    final turns = <DutyTurn>[];

    for (final item in group?['duties'] as List? ?? const []) {
      if (item is! Map) continue;

      final memberId = item['memberId'];
      final fromDate = item['fromDate'];
      final toDate = item['toDate'];

      if (memberId is! String || fromDate is! String || toDate is! String) {
        continue;
      }
      if (fromDate.compareTo(toDate) > 0) continue;

      turns.add(
        DutyTurn(
          memberId: memberId,
          memberName: item['memberName'] as String? ?? 'Member',
          fromDate: fromDate,
          toDate: toDate,
        ),
      );
    }

    turns.sort((a, b) => a.fromDate.compareTo(b.fromDate));
    return DutyRoster(turns);
  }

  final List<DutyTurn> turns;

  /// Whose turn it is on [date], or null when nobody is set.
  DutyTurn? responsibleOn(DateTime date) {
    final dateKey = MealPlans.dateKey(date);
    return turns.where((turn) => turn.covers(dateKey)).firstOrNull;
  }

  /// The turn to show beside a member on [date]: the one running now,
  /// otherwise their next one, otherwise the last one they finished.
  /// Null for a member who has never been given a turn.
  ({DutyTurn turn, DutyStatus status})? turnOf(String memberId, DateTime date) {
    final dateKey = MealPlans.dateKey(date);
    // Earliest first, as [turns] always is.
    final own = turns.where((turn) => turn.memberId == memberId).toList();

    final current = own.where((turn) => turn.covers(dateKey)).firstOrNull;
    if (current != null) return (turn: current, status: DutyStatus.current);

    final next = own
        .where((turn) => turn.fromDate.compareTo(dateKey) > 0)
        .firstOrNull;
    if (next != null) return (turn: next, status: DutyStatus.upcoming);

    final last = own.lastOrNull;
    return last == null ? null : (turn: last, status: DutyStatus.done);
  }

  /// The turn already saved that [turn] would clash with, if any.
  DutyTurn? clashWith(DutyTurn turn) {
    return turns.where((existing) => existing.overlaps(turn)).firstOrNull;
  }

  /// Turns that have not finished before [date], earliest first.
  List<DutyTurn> from(DateTime date) {
    final dateKey = MealPlans.dateKey(date);
    return [
      for (final turn in turns)
        if (turn.toDate.compareTo(dateKey) >= 0) turn,
    ];
  }
}

class DutyRosterService {
  DutyRosterService._();

  static DocumentReference<Map<String, dynamic>> _group(String groupId) {
    return FirebaseFirestore.instance.collection('groups').doc(groupId);
  }

  static Stream<DutyRoster> watch(String groupId) {
    return _group(groupId)
        .snapshots()
        .map((group) => DutyRoster.fromGroupData(group.data()));
  }

  /// Only a hostel admin can save; the security rules check it.
  static Future<void> save(String groupId, List<DutyTurn> turns) {
    return _group(groupId).update({
      'duties': [for (final turn in turns) turn.toMap()],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
