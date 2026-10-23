import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/activity_log.dart';

void main() {
  Activity activity(ActivityKind kind, {String memberId = 'karim'}) {
    return Activity.fromData({
      'kind': kind.name,
      'actorId': 'rahim',
      'actorName': 'Rahim',
      'memberId': memberId,
      'memberName': 'Karim',
      'subject': 'Rice',
    })!;
  }

  test('says whose entry an admin changed', () {
    expect(
      activity(ActivityKind.mealChanged).sentence,
      "Rahim changed Karim's meals",
    );
    expect(
      activity(ActivityKind.mealAdded, memberId: 'rahim').sentence,
      'Rahim added meals',
    );
    expect(
      activity(ActivityKind.expenseDeleted).sentence,
      'Rahim deleted Rice',
    );
    expect(
      activity(ActivityKind.adminMade).sentence,
      'Rahim made Karim an admin',
    );
  });

  test('deletions stand out', () {
    expect(activity(ActivityKind.expenseDeleted).isRemoval, isTrue);
    expect(activity(ActivityKind.monthReset).isRemoval, isTrue);
    expect(activity(ActivityKind.mealChanged).tone, ActivityTone.changed);
    expect(activity(ActivityKind.expenseAdded).tone, ActivityTone.added);
    expect(activity(ActivityKind.mealChanged).isRemoval, isFalse);
  });

  test('a record from a newer app version is skipped', () {
    expect(Activity.fromData({'kind': 'somethingNew'}), isNull);
  });

  test('meal details show only what changed', () {
    expect(ActivityLog.mealDetails(lunch: 1, dinner: 1), 'Lunch 1 · Dinner 1');
    expect(
      ActivityLog.mealDetails(lunch: 2, dinner: 1, oldLunch: 1, oldDinner: 1),
      'Lunch 1 → 2 · Dinner 1',
    );
    expect(
      ActivityLog.mealDetails(lunch: 0.5, dinner: 0),
      'Lunch 0.5 · Dinner 0',
    );
  });

  test('expense changes list each changed field', () {
    expect(
      ActivityLog.changes({
        '': ('৳500', '৳800'),
        'Item': ('Rice', 'Rice'),
        'Day': ('2026-10-20', '2026-10-21'),
      }),
      '৳500 → ৳800 · Day: 2026-10-20 → 2026-10-21',
    );
    expect(ActivityLog.changes({'Item': ('Rice', 'Rice')}), isEmpty);
  });

  test('the dot shows only for others\' changes since last looked', () {
    final seen = DateTime(2026, 10, 24, 12);
    Activity at(String actorId, DateTime time) => Activity(
      kind: ActivityKind.mealChanged,
      actorId: actorId,
      actorName: actorId,
      at: time,
    );

    expect(
      ActivityLog.hasUnseen(
        [at('karim', DateTime(2026, 10, 24, 13))],
        seen: seen,
        userId: 'rahim',
      ),
      isTrue,
    );
    // Their own change, or one from before they looked, is not new.
    expect(
      ActivityLog.hasUnseen(
        [
          at('rahim', DateTime(2026, 10, 24, 13)),
          at('karim', DateTime(2026, 10, 24, 11)),
        ],
        seen: seen,
        userId: 'rahim',
      ),
      isFalse,
    );
  });
}
