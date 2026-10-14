import 'package:cloud_firestore/cloud_firestore.dart';

/// A person who belongs to a hostel group.
///
/// App users are stored under their Firebase Auth uid. Shadow members
/// (people who never installed the app) get an auto-generated id.
class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.isAppUser,
    this.userId,
    this.active = true,
    this.addedAt,
    this.linkedTo,
  });

  factory GroupMember.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final name = data['name'];

    return GroupMember(
      id: document.id,
      name: name is String && name.trim().isNotEmpty ? name.trim() : 'Member',
      isAppUser: data['isAppUser'] == true,
      userId: data['userId'] as String?,
      active: data['active'] != false,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      linkedTo: data['linkedTo'] as String?,
    );
  }

  /// Builds a member from a `users/{uid}` document. Used as a fallback
  /// while the members collection is not available yet.
  factory GroupMember.fromUserDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return GroupMember(
      id: document.id,
      name: readUserName(data),
      isAppUser: true,
      userId: document.id,
      addedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String name;
  final bool isAppUser;
  final String? userId;
  final bool active;
  final DateTime? addedAt;

  /// Uid of the app user this shadow member was merged into.
  final String? linkedTo;

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'M';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// The name the hostel shows for a user: their nickname when they
  /// have set one, otherwise their full name.
  static String readUserName(Map<String, dynamic> data) {
    final possibleNames = [
      data['nickname'],
      data['name'],
      data['displayName'],
      data['fullName'],
    ];

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
  }

  static int compareByName(GroupMember first, GroupMember second) {
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }
}
