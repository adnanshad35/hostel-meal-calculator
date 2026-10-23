import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group_member.dart';
import 'activity_log.dart';
import 'month_archive.dart';
import 'meal_plan_service.dart';

/// Reads and maintains `groups/{groupId}/members`.
class GroupMemberService {
  GroupMemberService._();

  static final Map<String, Future<void>> _runningSyncs = {};

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _group(String groupId) {
    return _firestore.collection('groups').doc(groupId);
  }

  static CollectionReference<Map<String, dynamic>> _members(String groupId) {
    return _group(groupId).collection('members');
  }

  static Query<Map<String, dynamic>> _groupUsers(String groupId) {
    return _firestore.collection('users').where('groupId', isEqualTo: groupId);
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
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usersSubscription;

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
          controller.add(_sorted(snapshot.docs.map(GroupMember.fromDocument)));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is FirebaseException && error.code == 'permission-denied') {
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
    return _runningSyncs[groupId] ??= _sync(groupId)
        .whenComplete(() => _runningSyncs.remove(groupId));
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
      final admins = List<String>.from(groupData['admins'] as List? ?? []);

      if (!memberIds.contains(user.uid)) return;

      final isAdmin = admins.contains(user.uid);
      final userNames = {
        for (final document in usersSnapshot.docs)
          document.id: GroupMember.readUserName(document.data()),
      };
      final userPhones = {
        for (final document in usersSnapshot.docs)
          document.id: (document.data()['phoneNumber'] as String? ?? '').trim(),
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
        final userPhone = userPhones[uid] ?? '';

        if (data == null) {
          batch.set(reference, {
            'name': userName ?? 'Member',
            'phone': userPhone,
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

        // The phone number shown in the member list.
        if (usersSnapshot.docs.any((document) => document.id == uid) &&
            (data['phone'] as String? ?? '') != userPhone) {
          updates['phone'] = userPhone;
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

  /// A meal's month, from its `dateKey`, or null when it has none.
  static DateTime? _mealMonth(Map<String, dynamic> data) {
    final parts = (data['dateKey'] as String? ?? '').split('-');
    if (parts.length < 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    return year == null || month == null ? null : DateTime(year, month);
  }

  /// An expense's month, from its `date`, or null when it has none.
  static DateTime? _expenseMonth(Map<String, dynamic> data) {
    final date = data['date'];
    if (date is! Timestamp) return null;
    final local = date.toDate();
    return DateTime(local.year, local.month);
  }

  /// Whether a record of [month] may be deleted: while the month is
  /// open, or once only its summary is kept. A record without a month
  /// belongs to none, so it may go too.
  static bool _mayClear(DateTime? month, DateTime now) {
    return month == null ||
        MonthLock.canEdit(month, now) ||
        MonthLock.isSummaryOnly(month, now);
  }

  /// Deletes a member who does not use the app, with their meal plan,
  /// duty turns, and meals and expenses in open months. Closed months
  /// keep theirs. Admins only.
  static Future<void> deleteShadowMember({
    required String groupId,
    required GroupMember member,
  }) async {
    if (member.isAppUser) {
      throw Exception('Members who use the app are removed, not deleted.');
    }

    final group = _group(groupId);
    final meals = await group
        .collection('meals')
        .where('userId', isEqualTo: member.id)
        .get();
    final expenses = await group
        .collection('expenses')
        .where('paidById', isEqualTo: member.id)
        .get();

    // A closed month keeps their records, so its totals never change;
    // they are counted there as a former member.
    final now = DateTime.now();
    final mealsToDelete = [
      for (final meal in meals.docs)
        if (_mayClear(_mealMonth(meal.data()), now)) meal.reference,
    ];
    final expensesToDelete = [
      for (final expense in expenses.docs)
        if (_mayClear(_expenseMonth(expense.data()), now)) expense.reference,
    ];
    final references = [...mealsToDelete, ...expensesToDelete];

    // Recorded first, so their records can never vanish unseen.
    await ActivityLog.add(
      groupId,
      kind: ActivityKind.memberRemoved,
      memberId: member.id,
      memberName: member.name,
      details:
          '${mealsToDelete.length} meal entries and '
          '${expensesToDelete.length} expenses deleted',
    );

    const chunkSize = 400;
    for (var start = 0; start < references.length; start += chunkSize) {
      final batch = _firestore.batch();
      for (final reference in references.skip(start).take(chunkSize)) {
        batch.delete(reference);
      }
      await batch.commit();
    }

    final groupData = (await group.get()).data();
    final duties = groupData?['duties'] as List? ?? const [];
    final remaining = [
      for (final duty in duties)
        if (duty is! Map || duty['memberId'] != member.id) duty,
    ];

    final batch = _firestore.batch();
    batch.delete(group.collection('mealPlans').doc(member.id));
    if (remaining.length != duties.length) {
      batch.update(group, {
        'duties': remaining,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.delete(_members(groupId).doc(member.id));
    await batch.commit();
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
    await _members(groupId)
        .doc(memberId)
        .update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});

    // A deactivated member's meal plan stops counting from tomorrow.
    if (!active) await MealPlanService.close(groupId, memberId);
  }

  /// Promotes an app user to administrator or changes them back to
  /// a member. Throws an [Exception] with a readable message when
  /// the change is not allowed.
  static Future<void> setAdminRole({
    required String groupId,
    required String memberId,
    required String memberName,
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
        throw Exception('Only an administrator can change member roles.');
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

      ActivityLog.addToTransaction(
        transaction,
        groupId,
        kind: makeAdmin ? ActivityKind.adminMade : ActivityKind.adminRemoved,
        memberId: memberId,
        memberName: memberName,
      );
    });
  }

  /// Removes the signed-in user from the hostel. Their meals and
  /// expenses stay in the hostel records.
  static Future<void> leaveGroup(String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final groupReference = _group(groupId);
    final userReference = _firestore.collection('users').doc(currentUser.uid);

    // Done first, while this user may still write in the hostel.
    await MealPlanService.close(groupId, currentUser.uid);

    await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupReference);
      final userSnapshot = await transaction.get(userReference);

      if (!groupSnapshot.exists) {
        throw Exception('The hostel could not be found.');
      }

      final groupData = groupSnapshot.data()!;
      final memberIds = List<String>.from(
        groupData['memberIds'] as List? ?? [],
      );
      final admins = List<String>.from(groupData['admins'] as List? ?? []);

      if (!memberIds.contains(currentUser.uid)) {
        throw Exception('You are no longer a member of this hostel.');
      }

      if (admins.contains(currentUser.uid) && admins.length <= 1) {
        throw Exception('Promote another member before leaving.');
      }

      memberIds.remove(currentUser.uid);
      admins.remove(currentUser.uid);

      final userData = userSnapshot.data();
      final savedName = userData == null
          ? 'Member'
          : GroupMember.readUserName(userData);

      transaction.update(groupReference, {
        'memberIds': memberIds,
        'admins': admins,
        'formerMembers.${currentUser.uid}': {
          'name': savedName != 'Member'
              ? savedName
              : currentUser.displayName ?? currentUser.email ?? 'Member',
          'email': currentUser.email ?? '',
          'leftAt': FieldValue.serverTimestamp(),
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
  }

  /// Deletes a hostel whose only app user is the signed-in admin, and
  /// frees them to create or join another one.
  ///
  /// The hostel's invitation code is switched off and the hostel
  /// itself is removed. Throws an [Exception] with a readable message
  /// when other app users are still in the hostel.
  static Future<void> deleteHostel(String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final groupReference = _group(groupId);

    final groupSnapshot = await groupReference.get();
    final groupData = groupSnapshot.data();

    if (groupData == null) {
      throw Exception('The hostel could not be found.');
    }

    final memberIds = List<String>.from(groupData['memberIds'] as List? ?? []);
    final admins = List<String>.from(groupData['admins'] as List? ?? []);

    if (!admins.contains(currentUser.uid)) {
      throw Exception('Only an administrator can delete the hostel.');
    }

    if (memberIds.length != 1 || memberIds.single != currentUser.uid) {
      throw Exception(
        'Other members are still in this hostel. Remove them or make '
        'one of them an administrator, then leave instead.',
      );
    }

    final inviteCode = groupData['inviteCode'] as String? ?? '';
    final batch = _firestore.batch();

    if (inviteCode.isNotEmpty) {
      batch.update(_firestore.collection('invites').doc(inviteCode), {
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(_firestore.collection('users').doc(currentUser.uid), {
      'groupId': null,
      'role': 'member',
      'previousGroupId': groupId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(groupReference);

    await batch.commit();
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
      final admins = List<String>.from(groupData['admins'] as List? ?? []);

      if (!admins.contains(currentUserId)) {
        throw Exception('Only an administrator can remove members.');
      }

      if (!memberIds.contains(memberId)) {
        throw Exception('${member.name} is no longer a member of this hostel.');
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

      ActivityLog.addToTransaction(
        transaction,
        groupId,
        kind: ActivityKind.memberRemoved,
        memberId: memberId,
        memberName: member.name,
        details: 'Their meals and expenses stay',
      );
    });

    // Deactivates the removed user's member entry.
    await sync(groupId);
    await MealPlanService.close(groupId, memberId);
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

    final shadowMeals = await meals.where('userId', isEqualTo: shadow.id).get();
    final userMeals = await meals.where('userId', isEqualTo: appUser.id).get();
    final shadowExpenses = await expenses
        .where('paidById', isEqualTo: shadow.id)
        .get();

    final takenDates = {
      for (final meal in userMeals.docs) meal.data()['dateKey'],
    };

    // Each operation moves one document, so a copy and its delete
    // always land in the same batch.
    final operations = <void Function(WriteBatch)>[];

    // Only open months move: a closed month keeps its records, so its
    // totals never change.
    final now = DateTime.now();

    for (final meal in shadowMeals.docs) {
      final data = meal.data();
      final dateKey = data['dateKey'] as String?;
      if (dateKey == null) continue;
      final month = _mealMonth(data);
      if (month == null || !MonthLock.canEdit(month, now)) continue;

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
      final month = _expenseMonth(expense.data());
      if (month == null || !MonthLock.canEdit(month, now)) continue;

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

    await MealPlanService.move(
      groupId: groupId,
      fromMemberId: shadow.id,
      toMemberId: appUser.id,
      toMemberName: appUser.name,
    );
  }
}
