import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  User get _currentUser =>
      FirebaseAuth.instance.currentUser!;

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

Future<void> _requestFeature(
  BuildContext context,
) async {
  final uri = Uri(
    scheme: 'mailto',
    path: 'adnanshad1035@gmail.com',
    queryParameters: {
      'subject': 'HostelMate Feature Request',
    },
  );

  final opened = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No email application was found. '
          'Please email adnanshad1035@gmail.com.',
        ),
      ),
    );
  }
}

  Future<void> _showAbout(
    BuildContext context,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              _ProfileIconBox(
                icon: Icons.home_work_outlined,
                backgroundColor:
                    AppTheme.surfaceSoft,
                iconColor: AppTheme.primary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('About HostelMate'),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'HostelMate helps hostel members manage '
                  'meals, shared expenses, monthly meal '
                  'rates, and individual balances clearly.',
                ),
                SizedBox(height: 22),
                Text(
                  'Designed for transparency',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Every member can view meal counts, '
                  'expenses, calculations, and final '
                  'pay-or-collect amounts.',
                ),
                SizedBox(height: 22),
                Divider(),
                SizedBox(height: 16),
                Text(
                  'Developer',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Abu Adnan Shad',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Independent Flutter and Firebase project',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut(
    BuildContext context,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text(
            'Are you sure you want to sign out '
            'of HostelMate?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .snapshots(),
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
          final email =
              _currentUser.email ?? 'Not available';

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              32,
            ),
            children: [
              _ProfileHeader(
  name: name,
  email: email,
),
const SizedBox(height: 28),
const _SectionLabel(
  text: 'Help & Information',
),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    _ProfileTile(
                      icon:
                          Icons.lightbulb_outline_rounded,
                      iconBackground:
                          Color(0xFFFFF2DA),
                      iconColor: AppTheme.warning,
                      title: 'Request a Feature',
                      subtitle:
                          'Share an idea or improvement',
                      onTap: () {
                        _requestFeature(context);
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      child: Divider(),
                    ),
                    _ProfileTile(
                      icon: Icons.info_outline_rounded,
                      iconBackground:
                          Color(0xFFE8EDF8),
                      iconColor: Color(0xFF47659A),
                      title:
                          'About App & Developer',
                      subtitle:
                          'Learn more about HostelMate',
                      onTap: () {
                        _showAbout(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: _ProfileTile(
                  icon: Icons.logout_rounded,
                  iconBackground:
                      const Color(0xFFFCE8E8),
                  iconColor: AppTheme.danger,
                  title: 'Sign Out',
                  subtitle:
                      'Sign out from this device',
                  titleColor: AppTheme.danger,
                  onTap: () {
                    _signOut(context);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'M';

    if (words.length == 1) {
      return words.first[0].toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark,
            AppTheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary
                .withValues(alpha: 0.18),
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
              color: Colors.white
                  .withValues(alpha: 0.16),
              borderRadius:
                  BorderRadius.circular(21),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconBackground =
        AppTheme.surfaceSoft,
    this.iconColor = AppTheme.primary,
    this.titleColor =
        AppTheme.textPrimary,
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
      child: Icon(
        icon,
        color: iconColor,
        size: 23,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(
            color: AppTheme.textSecondary,
          ),
    );
  }
}