import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/onboarding.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _isSending = false;

  /// Looks again every few seconds, so the app moves on by itself once
  /// the link is opened.
  Timer? _autoCheck;

  /// Seconds until Resend can be tapped again.
  int _resendWait = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoCheck = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkQuietly(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCheck?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Back from the email app: look straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkQuietly();
  }

  /// Checks without any message; the app simply moves on when verified.
  Future<void> _checkQuietly() async {
    if (_isChecking || _isSending) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // As the button does: a fresh token first, so the database sees
      // the email as verified by the time the app moves on.
      await user.getIdToken(true);
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {
      // Tried again shortly.
    }
  }

  void _startResendWait() {
    _resendTimer?.cancel();
    setState(() => _resendWait = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendWait--);
      if (_resendWait <= 0) timer.cancel();
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      // Fetch a fresh sign-in token first. Reloading the account is
      // what moves the app off this screen, and the database must
      // already see the email as verified by then.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (user?.emailVerified == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified successfully.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your email is not verified yet. Open the link in your email first.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to check verification.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      _startResendWait();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification email has been sent.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      final message = error.code == 'too-many-requests'
          ? 'Please wait before requesting another email.'
          : error.message ?? 'Unable to resend the verification email.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final isBusy = _isChecking || _isSending;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    title: 'Check Your Email',
                    subtitle: 'We sent a verification link to',
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const _StepRow(
                            number: '1',
                            text: 'Open the email and tap the link.',
                          ),
                          const SizedBox(height: 14),
                          const _StepRow(
                            number: '2',
                            text: 'Come back here. The app moves on by itself.',
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                  color: AppTheme.accentDeep,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'It comes from noreply@hostel-meal-'
                                    'calculator-1035.firebaseapp.com, our '
                                    'sign-in service. Not in your inbox? '
                                    'Check Spam or Promotions.',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isBusy ? null : _checkVerification,
                              icon: _isChecking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.verified_outlined),
                              label: const Text('I Have Verified My Email'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: isBusy || _resendWait > 0
                                  ? null
                                  : _resendEmail,
                              child: Text(
                                _isSending
                                    ? 'Sending...'
                                    : _resendWait > 0
                                    ? 'Resend in ${_resendWait}s'
                                    : 'Resend Email',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isBusy ? null : _signOut,
                    child: const Text('Use a Different Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
