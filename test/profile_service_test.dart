import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/models/group_member.dart';
import 'package:hostel_meal_calculator/services/profile_service.dart';

void main() {
  group('ProfileService.validateNickname', () {
    test('accepts one word of up to twelve letters', () {
      expect(ProfileService.validateNickname('Shad'), isNull);
      expect(ProfileService.validateNickname('abcdefghijkl'), isNull);
    });

    test('ignores spaces around the word', () {
      expect(ProfileService.validateNickname('  Shad  '), isNull);
    });

    test('accepts an empty nickname, which removes it', () {
      expect(ProfileService.validateNickname(''), isNull);
      expect(ProfileService.validateNickname('   '), isNull);
    });

    test('rejects more than one word', () {
      expect(ProfileService.validateNickname('Abu Shad'), isNotNull);
      expect(ProfileService.validateNickname('Abu\tShad'), isNotNull);
    });

    test('rejects more than twelve letters', () {
      expect(ProfileService.validateNickname('abcdefghijklm'), isNotNull);
    });

    test('counts Bangla letters as letters, not bytes', () {
      expect(ProfileService.validateNickname('আদনান'), isNull);
    });
  });

  group('GroupMember.readUserName', () {
    test('prefers the nickname over the full name', () {
      expect(
        GroupMember.readUserName({'nickname': 'Shad', 'name': 'Abu Adnan'}),
        'Shad',
      );
    });

    test('falls back to the full name without a nickname', () {
      expect(GroupMember.readUserName({'name': 'Abu Adnan'}), 'Abu Adnan');
      expect(
        GroupMember.readUserName({'nickname': ' ', 'name': 'Abu Adnan'}),
        'Abu Adnan',
      );
    });
  });
}
