import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/models/group_member.dart';
import 'package:hostel_meal_calculator/services/hostel_settings.dart';
import 'package:hostel_meal_calculator/services/month_rules.dart';

GroupMember _member({
  bool isAppUser = false,
  bool active = false,
  String status = '',
  String? linkedTo,
}) {
  return GroupMember(
    id: 'id',
    name: 'Karim',
    isAppUser: isAppUser,
    active: active,
    status: status,
    linkedTo: linkedTo,
  );
}

void main() {
  group('GroupMember.isAlumni', () {
    test('an admin made them alumni', () {
      expect(_member(status: GroupMember.alumni).isAlumni, isTrue);
      expect(
        _member(isAppUser: true, status: GroupMember.alumni).isAlumni,
        isTrue,
      );
    });

    test('a member without the app deactivated before alumni existed', () {
      expect(_member().isAlumni, isTrue);
    });

    test('never active, deleted, merged, or an app user who left', () {
      expect(_member(active: true).isAlumni, isFalse);
      expect(_member(status: GroupMember.deleted).isAlumni, isFalse);
      expect(_member(linkedTo: 'uid').isAlumni, isFalse);
      expect(_member(isAppUser: true).isAlumni, isFalse);
    });
  });

  group('HostelSettings Remove All limits', () {
    test('default to 5 meals and 200 taka', () {
      final settings = HostelSettings.fromGroupData(null);

      expect(settings.removeAllLimits.maxMeals, 5);
      expect(settings.removeAllLimits.maxExpense, 200);
    });

    test('read what an admin saved', () {
      final settings = HostelSettings.fromGroupData({
        'settings': {'removeAllMaxMeals': 8, 'removeAllMaxExpense': 500},
      });

      expect(settings.removeAllLimits.maxMeals, 8);
      expect(settings.removeAllLimits.maxExpense, 500);
    });

    test('are saved with the other settings', () {
      final map = const HostelSettings(
        removeAllLimits: RemoveAllLimits(maxMeals: 3, maxExpense: 100),
      ).toMap();

      expect(map['removeAllMaxMeals'], 3);
      expect(map['removeAllMaxExpense'], 100);
      expect(map['membersCanAddMeals'], isTrue);
    });
  });
}
