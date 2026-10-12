import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'about_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User get _currentUser => FirebaseAuth.instance.currentUser!;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .snapshots();
  }

  String _readName(Map<String, dynamic>? data) {
    final possibleNames = [
      data?['name'],
      data?['displayName'],
      data?['fullName'],
      _currentUser.displayName,
    ];

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
  }

  bool _readIsAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    final value = data['isAdmin'];
    if (value is bool) return value;
    final role = data['role'];
    if (role is String) {
      return role.toLowerCase() == 'admin';
    }
    return false;
  }

  Future<void> _editPhoneNumber(
    BuildContext context, {
    required String currentPhone,
  }) async {
    final phone = await showDialog<String>(
      context: context,
      builder: (_) => _PhoneNumberDialog(currentPhone: currentPhone),
    );

    if (phone == null || !context.mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({
        'phoneNumber': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number updated.')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to update phone number.'),
        ),
      );
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final email = _currentUser.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email is associated with this account.'),
        ),
      );
      return;
    }

    final providers =
        _currentUser.providerData.map((p) => p.providerId).toList();
    final hasPasswordProvider = providers.contains('password');

    if (!hasPasswordProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password is managed by your sign-in provider.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Text(
            'We will send a password reset link to:\n\n$email\n\n'
            'Open the email and follow the link to set a new password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link sent to $email')),
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to send reset link.'),
        ),
      );
    }
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text(
            'Are you sure you want to sign out of HostelMate?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load your profile.'),
            );
          }

          final userData = snapshot.data?.data();
          final name = _readName(userData);
          final email = _currentUser.email ?? 'Not available';
          final phone = userData?['phoneNumber'] as String? ?? '';
          final isAdmin = _readIsAdmin(userData);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _ProfileHeader(
                key: const Key('header'),
                name: name,
                email: email,
                phone: phone,
                isAdmin: isAdmin,
              ),
              const SizedBox(height: 28),

              // ─── Account ───
              Column(
                key: const Key('account-section'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionLabel(text: 'Account'),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        _ProfileTile(
                          icon: Icons.phone_outlined,
                          iconBackground: AppTheme.surfaceSoft,
                          iconColor: AppTheme.primary,
                          title: 'Phone Number',
                          subtitle: phone.trim().isEmpty
                              ? 'Add your phone number'
                              : phone,
                          trailingIcon: Icons.edit_outlined,
                          onTap: () => _editPhoneNumber(
                            context,
                            currentPhone: phone,
                          ),
                        ),
                        const _TileDivider(),
                        _ProfileTile(
                          icon: Icons.lock_outline_rounded,
                          iconBackground: AppTheme.surfaceSoft,
                          iconColor: AppTheme.primary,
                          title: 'Change Password',
                          subtitle: 'Send a reset link to your email',
                          onTap: () => _changePassword(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),

              // ─── About ───
              Card(
                key: const Key('about-section'),
                child: _ProfileTile(
                  icon: Icons.info_outline_rounded,
                  iconBackground: const Color(0xFFE8EDF8),
                  iconColor: const Color(0xFF47659A),
                  title: 'About App & Developer',
                  subtitle: 'App details, developer, and feedback',
                  onTap: () => _openAbout(context),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Sign Out ───
              Card(
                key: const Key('signout-section'),
                child: _ProfileTile(
                  icon: Icons.logout_rounded,
                  iconBackground: const Color(0xFFFCE8E8),
                  iconColor: AppTheme.danger,
                  title: 'Sign Out',
                  subtitle: 'Sign out from this device',
                  titleColor: AppTheme.danger,
                  onTap: () => _signOut(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phone number dialog
// ─────────────────────────────────────────────────────────────

/// Owns its text controller so it is disposed only after the dialog
/// has fully closed.
class _PhoneNumberDialog extends StatefulWidget {
  const _PhoneNumberDialog({required this.currentPhone});

  final String currentPhone;

  @override
  State<_PhoneNumberDialog> createState() => _PhoneNumberDialogState();
}

class _PhoneNumberDialogState extends State<_PhoneNumberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.currentPhone.trim().isEmpty
            ? 'Add Phone Number'
            : 'Update Phone Number',
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: 'Example: +8801712345678',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            final enteredPhone = value?.trim() ?? '';
            if (enteredPhone.isEmpty) {
              return 'Please enter your phone number.';
            }
            final normalized =
                enteredPhone.replaceAll(RegExp(r'[\s()-]'), '');
            if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(normalized)) {
              return 'Please enter a valid phone number.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.isAdmin,
  });

  final String name;
  final String email;
  final String phone;
  final bool isAdmin;

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'M';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const ValueKey('admin-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
                if (phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tile
// ─────────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailingIcon,
    this.iconBackground = AppTheme.surfaceSoft,
    this.iconColor = AppTheme.primary,
    this.titleColor = AppTheme.textPrimary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Replaces the default arrow shown on tappable tiles.
  final IconData? trailingIcon;
  final Color iconBackground;
  final Color iconColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: _ProfileIconBox(
        icon: icon,
        backgroundColor: iconBackground,
        iconColor: iconColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(subtitle),
      ),
      trailing: onTap == null
          ? null
          : Icon(
              trailingIcon ?? Icons.arrow_forward_ios_rounded,
              size: trailingIcon == null ? 16 : 20,
              color: AppTheme.textSecondary,
            ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1),
    );
  }
}

class _ProfileIconBox extends StatelessWidget {
  const _ProfileIconBox({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: iconColor, size: 23),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
    );
  }
}
