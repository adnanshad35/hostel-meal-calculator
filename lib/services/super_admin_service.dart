import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A user account, as the super admin sees it.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.groupId,
    this.role = 'member',
    this.createdAt,
  });

  factory AdminUser.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    String? firstText(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final groupId = data['groupId'];

    return AdminUser(
      id: document.id,
      name: firstText(['name', 'displayName', 'fullName']) ?? 'Unnamed user',
      email: firstText(['email']) ?? '',
      phone: firstText(['phoneNumber']) ?? '',
      groupId: groupId is String && groupId.isNotEmpty ? groupId : null,
      role: firstText(['role']) ?? 'member',
      createdAt: ((data['createdAt'] ?? data['joinedAt']) as Timestamp?)
          ?.toDate(),
    );
  }

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? groupId;
  final String role;
  final DateTime? createdAt;

  bool get isHostelAdmin => groupId != null && role == 'admin';
}

/// A hostel group, as the super admin sees it.
class AdminHostel {
  const AdminHostel({
    required this.id,
    required this.name,
    this.memberIds = const [],
    this.adminIds = const [],
    this.inviteCode = '',
    this.createdAt,
  });

  factory AdminHostel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final name = data['name'];

    return AdminHostel(
      id: document.id,
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Unnamed hostel',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      adminIds: List<String>.from(data['admins'] as List? ?? const []),
      inviteCode: data['inviteCode'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String name;

  /// App users in the hostel. Members without the app are not counted.
  final List<String> memberIds;
  final List<String> adminIds;
  final String inviteCode;
  final DateTime? createdAt;
}

/// Everything the super admin panel shows, loaded in one go.
class AdminSnapshot {
  AdminSnapshot({
    required List<AdminUser> users,
    required List<AdminHostel> hostels,
  }) : users = [...users]..sort(_byNewestThenName),
       hostels = [...hostels]
         ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final List<AdminUser> users;
  final List<AdminHostel> hostels;

  static int _byNewestThenName(AdminUser a, AdminUser b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;

    if (aTime != null && bTime != null) return bTime.compareTo(aTime);
    if (aTime != null) return -1;
    if (bTime != null) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int get usersInHostels => users.where((user) => user.groupId != null).length;

  int get usersWithoutHostel => users.length - usersInHostels;

  /// Accounts created in the seven days before [now].
  int newUsers(DateTime now) {
    final since = now.subtract(const Duration(days: 7));
    return users.where((user) => user.createdAt?.isAfter(since) == true).length;
  }

  AdminHostel? hostelOf(AdminUser user) {
    final groupId = user.groupId;
    if (groupId == null) return null;

    for (final hostel in hostels) {
      if (hostel.id == groupId) return hostel;
    }
    return null;
  }

  List<AdminUser> membersOf(AdminHostel hostel) {
    return users.where((user) => user.groupId == hostel.id).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Users whose name, email, phone, or hostel name contains [query],
  /// newest first unless [oldestFirst]. Users without a sign-up date
  /// always come last.
  List<AdminUser> searchUsers(String query, {bool oldestFirst = false}) {
    final text = query.trim().toLowerCase();

    final matches = text.isEmpty
        ? users
        : users.where((user) {
            return user.name.toLowerCase().contains(text) ||
                user.email.toLowerCase().contains(text) ||
                user.phone.toLowerCase().contains(text) ||
                (hostelOf(user)?.name.toLowerCase().contains(text) ?? false);
          }).toList();

    if (!oldestFirst) return matches;

    final dated = matches
        .where((user) => user.createdAt != null)
        .toList()
        .reversed;
    final undated = matches.where((user) => user.createdAt == null);

    return [...dated, ...undated];
  }

  List<AdminHostel> searchHostels(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return hostels;

    return hostels
        .where((hostel) => hostel.name.toLowerCase().contains(text))
        .toList();
  }
}

/// The app-wide administrator. Read-only access to every account and
/// hostel, plus sending app notices.
class SuperAdminService {
  SuperAdminService._();

  /// The super admin's account. The security rules check the same
  /// verified email, so changing it here alone grants nothing.
  static const String email = 'adnanshad1035@gmail.com';

  static bool get isSuperAdmin {
    final user = FirebaseAuth.instance.currentUser;

    return user != null &&
        user.emailVerified &&
        user.email?.toLowerCase() == email;
  }

  /// Loads every user and hostel once. Called again on refresh, so
  /// the panel costs reads only when it is opened or refreshed.
  static Future<AdminSnapshot> load() async {
    final firestore = FirebaseFirestore.instance;

    final users = await firestore.collection('users').get();
    final hostels = await firestore.collection('groups').get();

    return AdminSnapshot(
      users: users.docs.map(AdminUser.fromDocument).toList(),
      hostels: hostels.docs.map(AdminHostel.fromDocument).toList(),
    );
  }
}
