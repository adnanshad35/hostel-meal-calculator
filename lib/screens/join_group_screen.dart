import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
            'You joined ${inviteData['groupName'] ?? 'the hostel group'}.',
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
                ? 'This invitation code is not accepted. Ask your '
                      'hostel admin whether joining is switched on.'
                : 'Unable to join the group. Please try again.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().contains('inactive-code')
          ? 'This invitation code is no longer active.'
          : 'The invitation code is invalid.';

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
      appBar: AppBar(title: const Text('Join Hostel Group')),
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
                  'Enter Invitation Code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: const InputDecoration(
                    labelText: 'Invitation Code',
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _joinGroup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Join Group'),
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
