import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'group_member_service.dart';

/// The signed-in member's own profile: their nickname, and the name
/// the hostel knows them by.
class ProfileService {
  ProfileService._();

  /// The most letters a nickname may have.
  static const int nicknameLength = 12;

  /// The name to save on this member's own meals and expenses: their
  /// nickname when they have one, otherwise their full name. Set when
  /// the profile loads; null until then.
  static String? memberName;

  /// A message for a nickname that cannot be used, or null when it is
  /// fine. An empty nickname is fine: it removes the nickname.
  static String? validateNickname(String text) {
    final nickname = text.trim();

    if (nickname.isEmpty) return null;
    if (nickname.contains(RegExp(r'\s'))) {
      return 'Use one word, without spaces.';
    }
    if (nickname.runes.length > nicknameLength) {
      return 'Use $nicknameLength letters or fewer.';
    }
    return null;
  }

  /// Saves the nickname, or removes it when [nickname] is empty, and
  /// passes it on to the member's hostel so everyone there sees it.
  static Future<void> saveNickname(String nickname) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final profile = FirebaseFirestore.instance.collection('users').doc(uid);
    final trimmed = nickname.trim();

    await profile.set({
      'nickname': trimmed.isEmpty ? FieldValue.delete() : trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final groupId = (await profile.get()).data()?['groupId'];
    if (groupId is String && groupId.isNotEmpty) {
      // Best effort: the hostel also picks the name up the next time
      // anyone opens it.
      await GroupMemberService.sync(groupId);
    }
  }
}
