import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const String _supportEmail = 'adnanshad1035@gmail.com';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User get _currentUser => FirebaseAuth.instance.currentUser!;

  String _versionLabel = 'Version 1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = 'Version ${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // Keep fallback label.
    }
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
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentPhone);

    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            currentPhone.trim().isEmpty
                ? 'Add Phone Number'
                : 'Update Phone Number',
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
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
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

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

  Future<void> _requestFeature(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'HostelMate Feature Request'},
    );
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No email application was found. '
            'Please email $_supportEmail.',
          ),
        ),
      );
    }
  }

  Future<void> _showAbout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              _ProfileIconBox(
                icon: Icons.home_work_outlined,
                backgroundColor: AppTheme.surfaceSoft,
                iconColor: AppTheme.primary,
              ),
              SizedBox(width: 12),
              Expanded(child: Text('About HostelMate')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HostelMate helps hostel members manage '
                  'meals, shared expenses, monthly meal '
                  'rates, and individual balances clearly.',
                ),
                const SizedBox(height: 22),
                const Text(
                  'Designed for transparency',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every member can view meal counts, '
                  'expenses, calculations, and final '
                  'pay-or-collect amounts.',
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Developer',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Abu Adnan Shad',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Independent Flutter and Firebase project',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  _versionLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .snapshots(),
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
          final groupId = userData?['groupId'] as String?;
          final isAdmin = _readIsAdmin(userData);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _ProfileHeader(
                name: name,
                email: email,
                phone: phone,
                isAdmin: isAdmin,
              ),
              const SizedBox(height: 28),

              // ─── My Group ───
              if (groupId != null && groupId.isNotEmpty) ...[
                const _SectionLabel(text: 'My Group'),
                const SizedBox(height: 10),
                _GroupCard(groupId: groupId, isAdmin: isAdmin),
                const SizedBox(height: 24),
              ],

              // ─── Account ───
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

              // ─── Help & Information ───
              const _SectionLabel(text: 'Help & Information'),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.lightbulb_outline_rounded,
                      iconBackground: const Color(0xFFFFF2DA),
                      iconColor: AppTheme.warning,
                      title: 'Request a Feature',
                      subtitle: 'Share an idea or improvement',
                      onTap: () => _requestFeature(context),
                    ),
                    const _TileDivider(),
                    _ProfileTile(
                      icon: Icons.info_outline_rounded,
                      iconBackground: const Color(0xFFE8EDF8),
                      iconColor: const Color(0xFF47659A),
                      title: 'About App & Developer',
                      subtitle: 'Learn more about HostelMate',
                      onTap: () => _showAbout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Sign Out ───
              Card(
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
// Group card — reads groups/{groupId} + live member count
// ─────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.groupId,
    required this.isAdmin,
  });

  final String groupId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          final groupData = groupSnapshot.data?.data();
          final groupName =
              (groupData?['name'] as String?)?.trim().isNotEmpty == true
                  ? (groupData!['name'] as String).trim()
                  : 'My Hostel';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('groupId', isEqualTo: groupId)
                .snapshots(),
            builder: (context, membersSnapshot) {
              final count = membersSnapshot.data?.docs.length ?? 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const _ProfileIconBox(
                  icon: Icons.home_work_outlined,
                  backgroundColor: AppTheme.surfaceSoft,
                  iconColor: AppTheme.primary,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        groupName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      const _AdminBadge(),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    count == 1
                        ? '1 member'
                        : '$count members',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Admin',
        style: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
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
    this.iconBackground = AppTheme.surfaceSoft,
    this.iconColor = AppTheme.primary,
    this.titleColor = AppTheme.textPrimary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
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
          : const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
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
