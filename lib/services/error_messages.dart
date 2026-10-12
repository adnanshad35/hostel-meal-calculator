import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
