import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  User get _currentUser =>
      FirebaseAuth.instance.currentUser!;

  DocumentReference<Map<String, dynamic>>
      get _userReference => FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _readName(Map<String, dynamic>? data) {
    final possibleNames = [
      data?['name'],
      data?['displayName'],
      data?['fullName'],
      _currentUser.displayName,
    ];

    for (final value in possibleNames) {
      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
  }

  void _startEditing(String currentName) {
    _nameController.text = currentName;

    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _nameController.clear();

    setState(() => _isEditing = false);
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter at least 2 characters.',
          ),
        ),
      );
      return;
    }

    if (name.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The name cannot exceed 50 characters.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _currentUser.updateDisplayName(name);

      await _userReference.set({
        'name': name,
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _currentUser.reload();

      if (!mounted) return;

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your name was updated successfully.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Unable to update your name.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Unable to update your profile.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _roleLabel(String? role) {
    return role == 'admin'
        ? 'Administrator'
        : 'Member';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SafeArea(
        child: StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userReference.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load your profile.',
                ),
              );
            }

            final userData = snapshot.data?.data();
            final name = _readName(userData);
            final email = _currentUser.email ?? '';
            final role =
                userData?['role'] as String?;
            final groupId =
                userData?['groupId'] as String?;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      Color(0xFFC8E6C9),
                  child: Icon(
                    Icons.person_outline,
                    size: 52,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge,
                ),
                const SizedBox(height: 28),
                if (_isEditing)
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Edit Name',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller:
                                _nameController,
                            enabled: !_isSaving,
                            textCapitalization:
                                TextCapitalization.words,
                            textInputAction:
                                TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isSaving) {
                                _saveName();
                              }
                            },
                            decoration:
                                const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(
                                Icons.person_outline,
                              ),
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : _cancelEditing,
                                  child:
                                      const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isSaving
                                      ? null
                                      : _saveName,
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                          ),
                                        )
                                      : const Text(
                                          'Save',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.badge_outlined,
                          ),
                          title:
                              const Text('Full name'),
                          subtitle: Text(name),
                          trailing: IconButton(
                            tooltip: 'Edit name',
                            onPressed: () {
                              _startEditing(name);
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.email_outlined,
                          ),
                          title: const Text(
                            'Email address',
                          ),
                          subtitle: Text(email),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons
                                .admin_panel_settings_outlined,
                          ),
                          title: const Text('Role'),
                          subtitle: Text(
                            groupId == null ||
                                    groupId.isEmpty
                                ? 'Not in a hostel'
                                : _roleLabel(role),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Card(
                  color: Color(0xFFE8F5E9),
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Your email address is connected to '
                      'Firebase Authentication and cannot be '
                      'changed from this version of the app.',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}