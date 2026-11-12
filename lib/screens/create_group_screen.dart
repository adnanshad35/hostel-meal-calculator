import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _generateInvitationCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(
      6,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  Future<void> _createGroup() async {
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
      final invitationCode = _generateInvitationCode();

      final groupReference = firestore.collection('groups').doc();
      final userReference = firestore.collection('users').doc(user.uid);
      final inviteReference = firestore
          .collection('invites')
          .doc(invitationCode);

      final batch = firestore.batch();

      batch.set(groupReference, {
        'name': _nameController.text.trim(),
        'inviteCode': invitationCode,
        'createdBy': user.uid,
        'admins': [user.uid],
        'memberIds': [user.uid],
        'currency': 'BDT',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(inviteReference, {
        'groupId': groupReference.id,
        'groupName': _nameController.text.trim(),
        'createdBy': user.uid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(userReference, {
        'uid': user.uid,
        'fullName': user.displayName ?? 'Member',
        'email': user.email,
        'groupId': groupReference.id,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      SubscriptionService.startFreeTrial(
        batch,
        groupReference.id,
        uid: user.uid,
      );

      await batch.commit();

      if (!mounted) return;

      // The admin's next step: inviting the members.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _HostelCreatedScreen(
            hostelName: _nameController.text.trim(),
            code: invitationCode,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'network-request-failed' ||
                    error.code == 'unavailable'
                ? 'Please check your internet connection.'
                : 'Unable to create the hostel. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Hostel')),
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
                      Icons.groups_outlined,
                      size: 36,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create Your Hostel',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _createGroup(),
                  decoration: const InputDecoration(
                    labelText: 'Hostel Name',
                    hintText: 'Example: Green View Hostel',
                    // There is no rename later, so it is said up front.
                    helperText: 'Choose carefully: it stays the same later.',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.length < 3) {
                      return 'Please enter your hostel\'s name.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.payments_outlined),
                  title: Text('Currency'),
                  subtitle: Text('Bangladeshi Taka (BDT)'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _createGroup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Create Hostel'),
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

/// Shown once a hostel is made: its code, ready to send to members.
class _HostelCreatedScreen extends StatelessWidget {
  const _HostelCreatedScreen({required this.hostelName, required this.code});

  final String hostelName;
  final String code;

  String get _message =>
      'Join our hostel "$hostelName" on HostelMate.\n\n'
      '1. Get the app: https://hostelmate.web.app\n'
      '2. Create an account\n'
      '3. Tap Join a Hostel and enter the code: $code';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        size: 38,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$hostelName Is Ready',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Send this code to your members so they can join.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppTheme.heroShadow,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'HOSTEL CODE',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied.')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 19),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(text: _message),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 19),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Go to My Hostel'),
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
