import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'hostel_settings.dart';
import 'subscription_service.dart';

/// Shown wherever a hostel that is not active refuses a change.
const String readOnlyMessage =
    'This hostel is read-only right now. An admin can activate it from '
    'the hostel dashboard.';

/// A message for a failed save that a member can act on.
///
/// The security rules refuse a change either because the hostel is
/// read-only or because the member is not allowed to make it, and
/// cannot say which, so the message covers both.
String saveErrorMessage(FirebaseException error, {required String fallback}) {
  if (error.code == 'permission-denied') {
    return 'This could not be saved. The hostel may be read-only, or '
        'you may not have permission for this change.';
  }

  if (error.code == 'unavailable') {
    return 'No internet connection. Please try again.';
  }

  return fallback;
}

/// Returns true when records in [groupId] can be changed. Otherwise
/// tells the user the hostel is read-only and returns false.
Future<bool> ensureHostelEditable(BuildContext context, String groupId) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final subscription = await SubscriptionService.watch(groupId).first
        .timeout(const Duration(seconds: 4));

    if (subscription.canEdit(DateTime.now())) return true;
  } catch (_) {
    // The status could not be read. Let the attempt go ahead; the
    // security rules still have the final say.
    return true;
  }

  messenger.showSnackBar(const SnackBar(content: Text(readOnlyMessage)));
  return false;
}

/// Returns true when the signed-in member may add or change meals
/// (or expenses, when [meals] is false) in [groupId]. A hostel's
/// admins can keep that to themselves in Admin Settings; a member is
/// then told so and false is returned. Admins always may.
Future<bool> ensureMemberMayAdd(
  BuildContext context,
  String groupId, {
  required bool meals,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final group = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get()
        .timeout(const Duration(seconds: 4));
    final data = group.data();

    final admins = data?['admins'] as List? ?? const [];
    if (admins.contains(FirebaseAuth.instance.currentUser?.uid)) return true;

    final settings = HostelSettings.fromGroupData(data);
    if (meals ? settings.membersCanAddMeals : settings.membersCanAddExpenses) {
      return true;
    }
  } catch (_) {
    // The hostel could not be read. Let the attempt go ahead; the
    // security rules still have the final say.
    return true;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        meals
            ? 'In this hostel, only an admin enters meals.'
            : 'In this hostel, only an admin enters expenses.',
      ),
    ),
  );
  return false;
}
