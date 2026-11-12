import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;

  /// The hostel a full code belongs to, looked up as it is typed.
  String? _foundName;
  bool _isLooking = false;

  /// The code looked up last, and why it cannot be used, if so.
  String _lookedUp = '';
  String? _codeProblem;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    final code = _codeController.text.trim().toUpperCase();
    if (code == _lookedUp) return;
    _lookedUp = code;
    setState(() {
      _foundName = null;
      _codeProblem = null;
      _isLooking = false;
    });
    if (code.length == 6) _lookUp(code);
  }

  /// Shows which hostel the code is for, before joining.
  Future<void> _lookUp(String code) async {
    setState(() => _isLooking = true);
    try {
      final invite = await FirebaseFirestore.instance
          .collection('invites')
          .doc(code)
          .get();
      if (!mounted || _lookedUp != code) return;
      final data = invite.data();
      setState(() {
        if (data == null) {
          _codeProblem = 'No hostel has this code. Check it with your admin.';
        } else if (data['active'] != true) {
          _codeProblem = 'This code is no longer active.';
        } else {
          _foundName = (data['groupName'] as String?)?.trim().isNotEmpty == true
              ? data['groupName'] as String
              : 'this hostel';
        }
      });
    } catch (_) {
      // Checked again when Join is tapped.
    } finally {
      if (mounted && _lookedUp == code) setState(() => _isLooking = false);
    }
  }

  Future<void> _joinGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please sign in again.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final code = _codeController.text.trim().toUpperCase();

      final inviteSnapshot = await firestore
          .collection('invites')
          .doc(code)
          .get();

      if (!inviteSnapshot.exists) {
        throw Exception('invalid-code');
      }

      final inviteData = inviteSnapshot.data()!;

      if (inviteData['active'] != true) {
        throw Exception('inactive-code');
      }

      final groupId = inviteData['groupId'] as String;

      final groupReference = firestore.collection('groups').doc(groupId);
      final userReference = firestore.collection('users').doc(user.uid);

      final batch = firestore.batch();

      batch.update(groupReference, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
      });

      batch.set(userReference, {
        'uid': user.uid,
        'fullName': user.displayName ?? 'Member',
        'email': user.email,
        'groupId': groupId,
        'role': 'member',
        // The security rules compare this with the group's code.
        'joinCode': code,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome to ${inviteData['groupName'] ?? 'your hostel'}!',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'This hostel is not taking new members right now. '
                      'Ask your hostel admin to turn on Allow New Members.'
                : 'Unable to join the hostel. Please try again.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().contains('inactive-code')
          ? 'This code is no longer active.'
          : 'No hostel has this code. Check it with your admin.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Hostel')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      size: 36,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter Your Hostel Code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask your hostel admin for the 6-character code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    TextInputFormatter.withFunction(
                      (_, value) =>
                          value.copyWith(text: value.text.toUpperCase()),
                    ),
                  ],
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: const InputDecoration(
                    labelText: 'Hostel Code',
                    hintText: 'ABC123',
                    counterText: '',
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) != 6) {
                      return 'Enter the complete six-character code.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isLooking
                      ? const Padding(
                          key: ValueKey('looking'),
                          padding: EdgeInsets.all(14),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : _foundName != null
                      ? _CodeResult(
                          key: const ValueKey('found'),
                          icon: Icons.verified_rounded,
                          color: AppTheme.primary,
                          text: _foundName!,
                          isName: true,
                        )
                      : _codeProblem != null
                      ? _CodeResult(
                          key: const ValueKey('problem'),
                          icon: Icons.error_outline_rounded,
                          color: AppTheme.danger,
                          text: _codeProblem!,
                        )
                      : const SizedBox(key: ValueKey('none'), height: 0),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _isLoading || _codeProblem != null
                      ? null
                      : _joinGroup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _foundName == null ? 'Join Hostel' : 'Join $_foundName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a typed code was found to be: the hostel, or why not.
class _CodeResult extends StatelessWidget {
  const _CodeResult({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.isName = false,
  });

  final IconData icon;
  final Color color;
  final String text;

  /// True when [text] is the hostel's name.
  final bool isName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: isName
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hostel Found',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        text,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
