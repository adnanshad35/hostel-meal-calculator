import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/notification_service.dart';

AppNotification _item(
  String id,
  DateTime createdAt, {
  bool isAnnouncement = false,
  String? actorId,
}) {
  return AppNotification(
    id: id,
    title: id,
    message: '',
    createdAt: createdAt,
    isAnnouncement: isAnnouncement,
    actorId: actorId,
  );
}

void main() {
  final seenAt = DateTime(2026, 10, 12, 10);

  // Newest first, as the service delivers them.
  final items = [
    _item('new-expense', DateTime(2026, 10, 12, 12), actorId: 'rahim'),
    _item('my-expense', DateTime(2026, 10, 12, 11), actorId: 'me'),
    _item(
      'new-announcement',
      DateTime(2026, 10, 12, 10, 30),
      isAnnouncement: true,
    ),
    _item('old-expense', DateTime(2026, 10, 12, 9), actorId: 'rahim'),
    _item(
      'old-announcement',
      DateTime(2026, 10, 11),
      isAnnouncement: true,
    ),
  ];

  group('unreadCount', () {
    test('counts only what arrived after the last visit', () {
      expect(
        NotificationService.unreadCount(
          items,
          seenAt: seenAt,
          currentUserId: 'me',
        ),
        2,
      );
    });

    test('never counts the member\'s own actions', () {
      expect(
        NotificationService.unreadCount(
          items,
          seenAt: seenAt,
          currentUserId: 'rahim',
        ),
        2, // my-expense and new-announcement
      );
    });

    test('everything is unread before the first visit', () {
      expect(
        NotificationService.unreadCount(
          items,
          seenAt: null,
          currentUserId: 'me',
        ),
        4,
      );
    });

    test('nothing is unread once everything has been seen', () {
      expect(
        NotificationService.unreadCount(
          items,
          seenAt: DateTime(2026, 10, 13),
          currentUserId: 'me',
        ),
        0,
      );
      expect(
        NotificationService.unreadCount(
          const [],
          seenAt: null,
          currentUserId: 'me',
        ),
        0,
      );
    });
  });

  group('newestUnseen', () {
    test('returns the newest item written after the last visit', () {
      expect(
        NotificationService.newestUnseen(items, seenAt: seenAt)?.id,
        'new-expense',
      );
      expect(
        NotificationService.newestUnseen(items, seenAt: null)?.id,
        'new-expense',
      );
    });

    test('returns nothing once everything has been seen', () {
      expect(
        NotificationService.newestUnseen(
          items,
          seenAt: DateTime(2026, 10, 13),
        ),
        isNull,
      );
      expect(
        NotificationService.newestUnseen(const [], seenAt: null),
        isNull,
      );
    });
  });

  group('wordCount', () {
    test('counts words separated by any whitespace', () {
      expect(NotificationService.wordCount(''), 0);
      expect(NotificationService.wordCount('   '), 0);
      expect(NotificationService.wordCount('Rent'), 1);
      expect(
        NotificationService.wordCount('  Rent is due\non   Friday. '),
        5,
      );
    });

    test('fifty words is the announcement limit', () {
      final fifty = List.filled(50, 'word').join(' ');

      expect(NotificationService.maxAnnouncementWords, 50);
      expect(NotificationService.wordCount(fifty), 50);
      expect(NotificationService.wordCount('$fifty more'), 51);
    });
  });

  test('each list remembers separately when it was last opened', () {
    expect(
      NotificationService.seenField(isGroup: true),
      isNot(NotificationService.seenField(isGroup: false)),
    );
  });
}
