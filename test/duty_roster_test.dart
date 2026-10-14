import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/duty_roster.dart';

void main() {
  // Arif looks after the hostel 1–5 October, Rakib 6–10 October.
  final roster = DutyRoster.fromGroupData({
    'duties': [
      {
        'memberId': 'r',
        'memberName': 'Rakib',
        'fromDate': '2026-10-06',
        'toDate': '2026-10-10',
      },
      {
        'memberId': 'a',
        'memberName': 'Arif',
        'fromDate': '2026-10-01',
        'toDate': '2026-10-05',
      },
      // Damaged entries are skipped.
      'nonsense',
      {'memberId': 'x', 'fromDate': '2026-10-20'},
      {
        'memberId': 'y',
        'memberName': 'Backwards',
        'fromDate': '2026-10-25',
        'toDate': '2026-10-21',
      },
    ],
  });

  test('reads the saved turns, earliest first', () {
    expect(roster.turns.map((turn) => turn.memberName), ['Arif', 'Rakib']);
  });

  test('names whoever is responsible on a given day', () {
    expect(roster.responsibleOn(DateTime(2026, 10, 1))!.memberName, 'Arif');
    expect(roster.responsibleOn(DateTime(2026, 10, 5, 23))!.memberName, 'Arif');
    expect(roster.responsibleOn(DateTime(2026, 10, 6))!.memberName, 'Rakib');
    expect(roster.responsibleOn(DateTime(2026, 10, 10))!.memberName, 'Rakib');
  });

  test('names nobody on a day without a turn', () {
    expect(roster.responsibleOn(DateTime(2026, 9, 30)), isNull);
    expect(roster.responsibleOn(DateTime(2026, 10, 11)), isNull);
    expect(
      DutyRoster.fromGroupData(null).responsibleOn(DateTime(2026, 10, 3)),
      isNull,
    );
  });

  test('finds a clash with a turn that is already saved', () {
    DutyTurn turn(String from, String to) {
      return DutyTurn(
        memberId: 't',
        memberName: 'Tuhin',
        fromDate: from,
        toDate: to,
      );
    }

    expect(
      roster.clashWith(turn('2026-10-05', '2026-10-07'))!.memberName,
      'Arif',
    );
    expect(
      roster.clashWith(turn('2026-10-10', '2026-10-12'))!.memberName,
      'Rakib',
    );
    // The day after one turn ends is free.
    expect(roster.clashWith(turn('2026-10-11', '2026-10-15')), isNull);
    expect(roster.clashWith(turn('2026-09-25', '2026-09-30')), isNull);
  });

  test('lists the turns that have not finished', () {
    expect(roster.from(DateTime(2026, 10, 6)).map((turn) => turn.memberName), [
      'Rakib',
    ]);
    expect(roster.from(DateTime(2026, 10, 11)), isEmpty);
    expect(roster.from(DateTime(2026, 10, 1)).length, 2);
  });

  test('shows each member the turn that matters today', () {
    // On the 6th Arif has finished and Rakib is on duty.
    final day = DateTime(2026, 10, 6);

    final arif = roster.turnOf('a', day)!;
    expect(arif.status, DutyStatus.done);
    expect(arif.turn.toDate, '2026-10-05');

    final rakib = roster.turnOf('r', day)!;
    expect(rakib.status, DutyStatus.current);

    // Before either has started, both are still to come.
    expect(
      roster.turnOf('a', DateTime(2026, 9, 28))!.status,
      DutyStatus.upcoming,
    );

    // Someone never given a turn has nothing to show.
    expect(roster.turnOf('nobody', day), isNull);
  });

  test('a next turn is shown in place of a finished one', () {
    final twice = DutyRoster.fromGroupData({
      'duties': [
        {
          'memberId': 'a',
          'memberName': 'Arif',
          'fromDate': '2026-10-01',
          'toDate': '2026-10-05',
        },
        {
          'memberId': 'a',
          'memberName': 'Arif',
          'fromDate': '2026-10-20',
          'toDate': '2026-10-24',
        },
      ],
    });

    final shown = twice.turnOf('a', DateTime(2026, 10, 10))!;
    expect(shown.status, DutyStatus.upcoming);
    expect(shown.turn.fromDate, '2026-10-20');

    // After both, the later one is the one that stays.
    final after = twice.turnOf('a', DateTime(2026, 10, 30))!;
    expect(after.status, DutyStatus.done);
    expect(after.turn.fromDate, '2026-10-20');
  });

  test('a turn survives being saved and read back', () {
    final saved = DutyRoster.fromGroupData({
      'duties': [for (final turn in roster.turns) turn.toMap()],
    });

    expect(saved.turns.length, 2);
    expect(saved.turns.first.memberId, 'a');
    expect(saved.turns.first.toDate, '2026-10-05');
  });
}
