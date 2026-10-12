import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shows [child] once the signed-in user's sign-in token says their
/// email is verified.
///
/// Right after someone verifies their email, the account is verified
/// but the token the database sees is still the old one, so every
/// request would be refused until the app was restarted. This fetches
/// a fresh token first.
class VerifiedSession extends StatefulWidget {
  const VerifiedSession({super.key, required this.child});

  final Widget child;

  @override
  State<VerifiedSession> createState() => _VerifiedSessionState();
}

class _VerifiedSessionState extends State<VerifiedSession> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _refreshTokenIfStale();
  }

  static Future<void> _refreshTokenIfStale() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await user.getIdTokenResult();

      if (token.claims?['email_verified'] != true) {
        await user.getIdToken(true).timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // Offline or the refresh failed. Open the app anyway; its screens
      // show their own message if data cannot be loaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return widget.child;
      },
    );
  }
}
