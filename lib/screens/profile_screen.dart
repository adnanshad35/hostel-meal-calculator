import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
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

  /// The member's full name, as they registered it.
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setNickname(String current) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameDialog(current: current),
    );

    if (nickname == null || nickname == current || !mounted) return;

    try {
      await ProfileService.saveNickname(nickname);
      if (!mounted) return;
      _showMessage(nickname.isEmpty ? 'Nickname removed.' : 'Nickname saved.');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? 'Unable to save the nickname.');
    }
  }

  Future<void> _changePassword() async {
    final email = _currentUser.email;
    if (email == null || email.isEmpty) {
      _showMessage('No email is associated with this account.');
      return;
    }

    final hasPassword = _currentUser.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    if (!hasPassword) {
      _showMessage('Password is managed by your sign-in provider.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Text(
            'We will send a password reset link to:\n\n$email\n\n'
            'Open the email and follow the link to set a new password. '
            'If it is not in your inbox, check the spam folder too.',
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

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showMessage('Reset link sent to $email');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? 'Unable to send reset link.');
    }
  }

  void _openAbout() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AboutScreen()));
  }

  Future<void> _signOut() async {
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
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load your profile.'));
          }

          final userData = snapshot.data?.data();
          final name = _readName(userData);
          final nickname = (userData?['nickname'] as String? ?? '').trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _ProfileHeader(name: name, email: _currentUser.email ?? ''),
              const SizedBox(height: 20),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.badge_outlined,
                      title: 'Set Nickname',
                      // The nickname itself, once there is one.
                      value: nickname.isEmpty ? null : nickname,
                      onTap: () => _setNickname(nickname),
                    ),
                    const _TileDivider(),
                    _ProfileTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      onTap: _changePassword,
                    ),
                    const _TileDivider(),
                    _ProfileTile(
                      icon: Icons.info_outline_rounded,
                      title: 'App and Developer',
                      onTap: _openAbout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                clipBehavior: Clip.antiAlias,
                child: _ProfileTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  color: AppTheme.danger,
                  onTap: _signOut,
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
// Nickname dialog
// ─────────────────────────────────────────────────────────────

/// Owns its text controller so it is disposed only after the dialog
/// has fully closed.
class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.current});

  final String current;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = ProfileService.validateNickname(_controller.text);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Nickname'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: ProfileService.nicknameLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Nickname',
          errorText: _error,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header: initials, full name, email
// ─────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});

  final String name;
  final String email;

  String get _initials {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        boxShadow: AppTheme.heroShadow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13.5,
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
// A row of the profile: an icon, a title, and where it has one, its
// current value
// ─────────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.color = AppTheme.primary,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// Shown at the end of the row, such as the nickname in use.
  final String? value;

  /// The icon's colour, and the title's too when it is not the usual
  /// green.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color == AppTheme.primary ? AppTheme.textPrimary : color,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(
              value!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppTheme.textSecondary,
          ),
        ],
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
