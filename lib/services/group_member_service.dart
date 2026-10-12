import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group_member.dart';

/// Reads and maintains `groups/{groupId}/members`.
class GroupMemberService {
  GroupMemberService._();

  static final Map<String, Future<void>> _runningSyncs = {};

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _group(String groupId) {
    return _firestore.collection('groups').doc(groupId);
  }

  static CollectionReference<Map<String, dynamic>> _members(
    String groupId,
  ) {
    return _group(groupId).collection('members');
  }

  static Query<Map<String, dynamic>> _groupUsers(String groupId) {
    return _firestore
        .collection('users')
        .where('groupId', isEqualTo: groupId);
  }

  static List<GroupMember> _sorted(Iterable<GroupMember> members) {
    return members.toList()..sort(GroupMember.compareByName);
  }

  static Future<List<GroupMember>> _fetchFromUsers(String groupId) async {
    final snapshot = await _groupUsers(groupId).get();
    return _sorted(snapshot.docs.map(GroupMember.fromUserDocument));
  }

  /// Live member list, sorted by name.
  ///
  /// Falls back to the app users of the group when the members
  /// collection is empty or not readable yet, so screens keep working
  /// before the group is migrated.
  ///
  /// Only snapshot listeners are used, so cached data shows at once
  /// when the device is offline. The sync runs in the background and
  /// never delays the list.
  static Stream<List<GroupMember>> watch(
    String groupId, {
    bool activeOnly = true,
  }) {
    late final StreamController<List<GroupMember>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        membersSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        usersSubscription;

    void watchUsers() {
      usersSubscription ??= _groupUsers(groupId).snapshots().listen(
        (snapshot) => controller.add(
          _sorted(snapshot.docs.map(GroupMember.fromUserDocument)),
        ),
        onError: controller.addError,
      );
    }

    void start() {
      unawaited(sync(groupId));

      Query<Map<String, dynamic>> query = _members(groupId);
      if (activeOnly) {
        query = query.where('active', isEqualTo: true);
      }

      membersSubscription = query.snapshots().listen(
        (snapshot) {
          if (snapshot.docs.isEmpty) {
            watchUsers();
            return;
          }

          usersSubscription?.cancel();
          usersSubscription = null;
          controller.add(
            _sorted(snapshot.docs.map(GroupMember.fromDocument)),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is FirebaseException &&
              error.code == 'permission-denied') {
            watchUsers();
          } else {
            controller.addError(error, stackTrace);
          }
        },
      );
    }

    controller = StreamController<List<GroupMember>>(
      onListen: start,
      onCancel: () async {
        await membersSubscription?.cancel();
        await usersSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// One-time read of the active members, sorted by name.
  static Future<List<GroupMember>> fetchActive(String groupId) async {
    try {
      final snapshot = await _members(groupId)
          .where('active', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return _sorted(snapshot.docs.map(GroupMember.fromDocument));
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    return _fetchFromUsers(groupId);
  }

  /// Makes sure every app user of the group has a member entry and
  /// that users who left are deactivated. This is also what migrates
  /// groups created before the members collection existed.
  ///
  /// Best effort: failures are ignored and retried on the next call.
  static Future<void> sync(String groupId) {
    return _runningSyncs[groupId] ??= _sync(groupId).whenComplete(
      () => _runningSyncs.remove(groupId),
    );
  }

  static Future<void> _sync(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final (groupSnapshot, usersSnapshot, membersSnapshot) = await (
        _group(groupId).get(),
        _groupUsers(groupId).get(),
        _members(groupId).get(),
      ).wait.timeout(const Duration(seconds: 10));

      final groupData = groupSnapshot.data();
      if (groupData == null) return;

      final memberIds = List<String>.from(
        groupData['memberIds'] as List? ?? [],
      );
      final admins = List<String>.from(
        groupData['admins'] as List? ?? [],
      );

      if (!memberIds.contains(user.uid)) return;

      final isAdmin = admins.contains(user.uid);
      final userNames = {
        for (final document in usersSnapshot.docs)
          document.id: GroupMember.readUserName(document.data()),
      };
      final existing = {
        for (final document in membersSnapshot.docs)
          document.id: document.data(),
      };

      final batch = _firestore.batch();
      var hasWrites = false;

      for (final uid in memberIds) {
        final reference = _members(groupId).doc(uid);
        final data = existing[uid];
        final userName = userNames[uid];

        if (data == null) {
          batch.set(reference, {
            'name': userName ?? 'Member',
            'isAppUser': true,
            'userId': uid,
            'addedBy': user.uid,
            'addedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'active': true,
          });
          hasWrites = true;
          continue;
        }

        final updates = <String, dynamic>{};

        if (data['active'] != true) {
          updates['active'] = true;
        }

        // Only admins may correct another member's name.
        if (userName != null &&
            data['name'] != userName &&
            (isAdmin || uid == user.uid)) {
          updates['name'] = userName;
        }

        if (updates.isNotEmpty) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          batch.update(reference, updates);
          hasWrites = true;
        }
      }

      for (final entry in existing.entries) {
        final data = entry.value;

        if (data['isAppUser'] == true &&
            data['active'] != false &&
            !memberIds.contains(entry.key)) {
          batch.update(_members(groupId).doc(entry.key), {
            'active': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasWrites = true;
        }
      }

      if (hasWrites) {
        await batch.commit();
      }
    } catch (_) {
      // Best effort. Readers fall back to the group's app users.
    }
  }

  static Future<void> addShadowMember({
    required String groupId,
    required String name,
  }) async {
    await _members(groupId).add({
      'name': name.trim(),
      'isAppUser': false,
      'userId': null,
      'addedBy': FirebaseAuth.instance.currentUser!.uid,
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'active': true,
    });
  }

  static Future<void> rename({
    required String groupId,
    required String memberId,
    required String name,
  }) async {
    await _members(groupId).doc(memberId).update({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setActive({
    required String groupId,
    required String memberId,
    required bool active,
  }) async {
    await _members(groupId).doc(memberId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Promotes an app user to administrator or changes them back to
  /// a member. Throws an [Exception] with a readable message when
  /// the change is not allowed.
  static Future<void> setAdminRole({
    required String groupId,
    required String memberId,
    required bool makeAdmin,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final groupReference = _group(groupId);
    final userReference = _firestore.collection('users').doc(memberId);

    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupReference);

      if (!groupSnapshot.exists) {
        throw Exception('The hostel group could not be found.');
      }

      final admins = List<String>.from(
        groupSnapshot.data()!['admins'] as List? ?? [],
      );

      if (!admins.contains(currentUserId)) {
        throw Exception(
          'Only an administrator can change member roles.',
        );
      }

      if (makeAdmin) {
        if (!admins.contains(memberId)) {
          admins.add(memberId);
        }
      } else {
        if (!admins.contains(memberId)) return;

        if (admins.length <= 1) {
          throw Exception(
            'The hostel must always have at least one administrator.',
          );
        }

        admins.remove(memberId);
      }

      transaction.update(groupReference, {
        'admins': admins,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(userReference, {
        'role': makeAdmin ? 'admin' : 'member',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Removes an app user from the hostel. Their meals and expenses
  /// stay in the hostel records.
  static Future<void> removeAppUser({
    required String groupId,
    required GroupMember member,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final memberId = member.id;
    final groupReference = _group(groupId);
    final userReference = _firestore.collection('users').doc(memberId);

    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupReference);
      final userSnapshot = await transaction.get(userReference);

      if (!groupSnapshot.exists) {
        throw Exception('The hostel group could not be found.');
      }

      final groupData = groupSnapshot.data()!;
      final memberIds = List<String>.from(
        groupData['memberIds'] as List? ?? [],
      );
      final admins = List<String>.from(
        groupData['admins'] as List? ?? [],
      );

      if (!admins.contains(currentUserId)) {
        throw Exception('Only an administrator can remove members.');
      }

      if (!memberIds.contains(memberId)) {
        throw Exception(
          '${member.name} is no longer a member of this hostel.',
        );
      }

      if (admins.contains(memberId) && admins.length <= 1) {
        throw Exception('The final administrator cannot be removed.');
      }

      memberIds.remove(memberId);
      admins.remove(memberId);

      transaction.update(groupReference, {
        'memberIds': memberIds,
        'admins': admins,
        'formerMembers.$memberId': {
          'name': member.name,
          'email': userSnapshot.data()?['email'] as String? ?? '',
          'removedBy': currentUserId,
          'removedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(userReference, {
        'groupId': null,
        'role': 'member',
        'previousGroupId': groupId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Deactivates the removed user's member entry.
    await sync(groupId);
  }

  /// Moves a shadow member's meals and expenses to [appUser] and
  /// deactivates the shadow member.
  ///
  /// When both have a meal entry on the same day, the app user's
  /// entry is kept. Safe to run again if it stops halfway.
  static Future<void> linkToAppUser({
    required String groupId,
    required GroupMember shadow,
    required GroupMember appUser,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final meals = _group(groupId).collection('meals');
    final expenses = _group(groupId).collection('expenses');

    final shadowMeals =
        await meals.where('userId', isEqualTo: shadow.id).get();
    final userMeals =
        await meals.where('userId', isEqualTo: appUser.id).get();
    final shadowExpenses =
        await expenses.where('paidById', isEqualTo: shadow.id).get();

    final takenDates = {
      for (final meal in userMeals.docs) meal.data()['dateKey'],
    };

    // Each operation moves one document, so a copy and its delete
    // always land in the same batch.
    final operations = <void Function(WriteBatch)>[];

    for (final meal in shadowMeals.docs) {
      final data = meal.data();
      final dateKey = data['dateKey'] as String?;
      if (dateKey == null) continue;

      operations.add((batch) {
        if (!takenDates.contains(dateKey)) {
          batch.set(meals.doc('${appUser.id}_$dateKey'), {
            ...data,
            'userId': appUser.id,
            'userName': appUser.name,
          });
        }
        batch.delete(meal.reference);
      });
    }

    for (final expense in shadowExpenses.docs) {
      operations.add((batch) {
        batch.set(expenses.doc(), {
          ...expense.data(),
          'paidById': appUser.id,
          'paidByName': appUser.name,
          'enteredBy': currentUser.uid,
        });
        batch.delete(expense.reference);
      });
    }

    operations.add((batch) {
      batch.update(_members(groupId).doc(shadow.id), {
        'active': false,
        'linkedTo': appUser.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    const chunkSize = 200;

    for (var start = 0; start < operations.length; start += chunkSize) {
      final batch = _firestore.batch();
      for (final operation in operations.skip(start).take(chunkSize)) {
        operation(batch);
      }
      await batch.commit();
    }
  }
}
