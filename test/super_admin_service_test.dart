import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/super_admin_service.dart';

void main() {
  final now = DateTime(2026, 10, 14);

  final snapshot = AdminSnapshot(
    users: [
      AdminUser(
        id: 'adnan',
        name: 'Adnan',
        email: 'adnan@example.com',
        phone: '+8801712345678',
        groupId: 'green',
        role: 'admin',
        createdAt: DateTime(2026, 10, 2),
      ),
      AdminUser(
        id: 'rahim',
        name: 'rahim',
        email: 'rahim@example.com',
        groupId: 'green',
        createdAt: DateTime(2026, 10, 12),
      ),
      AdminUser(
        id: 'karim',
        name: 'Karim',
        email: 'karim@test.org',
        groupId: 'blue',
        role: 'admin',
        createdAt: DateTime(2026, 10, 13),
      ),
      // Signed up but never joined a hostel; no sign-up date saved.
      const AdminUser(id: 'salam', name: 'Salam', role: 'admin'),
      const AdminUser(id: 'babul', name: 'Babul', groupId: 'deleted'),
    ],
    hostels: const [
      AdminHostel(
        id: 'green',
        name: 'Green Hostel',
        memberIds: ['adnan', 'rahim'],
        adminIds: ['adnan'],
      ),
      AdminHostel(
        id: 'blue',
        name: 'blue House',
        memberIds: ['karim'],
        adminIds: ['karim'],
      ),
    ],
  );

  test('users are listed newest first, undated ones last by name', () {
    expect(snapshot.users.map((user) => user.id), [
      'karim',
      'rahim',
      'adnan',
      'babul',
      'salam',
    ]);
  });

  test('hostels are listed by name, ignoring case', () {
    expect(snapshot.hostels.map((hostel) => hostel.id), ['blue', 'green']);
  });

  test('counts users in and outside hostels', () {
    expect(snapshot.users.length, 5);
    expect(snapshot.usersInHostels, 4);
    expect(snapshot.usersWithoutHostel, 1);
  });

  test('counts accounts created in the last seven days', () {
    // Rahim and Karim; Adnan is older and two have no date.
    expect(snapshot.newUsers(now), 2);
    expect(snapshot.newUsers(DateTime(2026, 11, 30)), 0);
  });

  test('finds a user\'s hostel, or none', () {
    final byId = {for (final user in snapshot.users) user.id: user};

    expect(snapshot.hostelOf(byId['rahim']!)?.name, 'Green Hostel');
    expect(snapshot.hostelOf(byId['salam']!), isNull);
    // The user document points at a hostel that no longer exists.
    expect(snapshot.hostelOf(byId['babul']!), isNull);
  });

  test('lists a hostel\'s members by name', () {
    final green = snapshot.hostels.firstWhere((h) => h.id == 'green');

    expect(snapshot.membersOf(green).map((user) => user.id), [
      'adnan',
      'rahim',
    ]);
  });

  test('a hostel admin is an admin who is actually in a hostel', () {
    final byId = {for (final user in snapshot.users) user.id: user};

    expect(byId['adnan']!.isHostelAdmin, isTrue);
    expect(byId['rahim']!.isHostelAdmin, isFalse);
    expect(byId['salam']!.isHostelAdmin, isFalse);
  });

  group('searching users', () {
    List<String> search(String query) {
      return snapshot.searchUsers(query).map((user) => user.id).toList();
    }

    test('an empty search returns everyone', () {
      expect(search(''), hasLength(5));
      expect(search('   '), hasLength(5));
    });

    test('matches name, email and phone, ignoring case', () {
      expect(search('RAHIM'), ['rahim']);
      expect(search('test.org'), ['karim']);
      expect(search('01712'), ['adnan']);
    });

    test('matches the name of the user\'s hostel', () {
      expect(search('green'), ['rahim', 'adnan']);
      expect(search('Blue'), ['karim']);
    });

    test('returns nothing when nothing matches', () {
      expect(search('zzz'), isEmpty);
    });

    test('can be listed oldest first, undated users still last', () {
      expect(snapshot.searchUsers('', oldestFirst: true).map((u) => u.id), [
        'adnan',
        'rahim',
        'karim',
        'babul',
        'salam',
      ]);
      expect(
        snapshot.searchUsers('green', oldestFirst: true).map((u) => u.id),
        ['adnan', 'rahim'],
      );
    });
  });

  test('searching hostels matches by name', () {
    expect(snapshot.searchHostels('house').map((hostel) => hostel.id), [
      'blue',
    ]);
    expect(snapshot.searchHostels(''), hasLength(2));
    expect(snapshot.searchHostels('zzz'), isEmpty);
  });
}
