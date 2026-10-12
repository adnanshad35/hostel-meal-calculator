import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/notification_bell.dart';
import 'create_group_screen.dart';
import 'hostel_dashboard_screen.dart';
import 'join_group_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openCreateGroup(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
  }

  Future<void> _openJoinGroup(BuildContext context) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const JoinGroupScreen()));
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  String _readUserName(User user, Map<String, dynamic>? userData) {
    final possibleNames = [
      userData?['name'],
      userData?['displayName'],
      userData?['fullName'],
      user.displayName,
    ];

    for (final value in possibleNames) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting &&
            !userSnapshot.hasData) {
          return _page(
            context,
            const Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError) {
          return _page(
            context,
            const _PageMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load account',
            ),
          );
        }

        final userData = userSnapshot.data?.data();

        final groupId = userData?['groupId'] as String?;

        final role = userData?['role'] as String? ?? 'member';

        final name = _readUserName(user, userData);

        if (groupId == null || groupId.isEmpty) {
          return _page(
            context,
            _NoHostelView(
              onCreateGroup: () {
                _openCreateGroup(context);
              },
              onJoinGroup: () {
                _openJoinGroup(context);
              },
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .snapshots(),
          builder: (context, groupSnapshot) {
            if (groupSnapshot.connectionState == ConnectionState.waiting &&
                !groupSnapshot.hasData) {
              return _page(
                context,
                const Center(child: CircularProgressIndicator()),
              );
            }

            if (groupSnapshot.hasError ||
                !groupSnapshot.hasData ||
                !groupSnapshot.data!.exists) {
              return _page(
                context,
                const _PageMessage(
                  icon: Icons.apartment_outlined,
                  title: 'Hostel not found',
                ),
              );
            }

            final group = groupSnapshot.data!.data()!;

            // A member belongs to one hostel, so the app opens straight
            // into it.
            return HostelDashboardScreen(
              key: ValueKey(groupId),
              groupId: groupId,
              groupName: group['name'] as String? ?? 'Hostel Group',
              inviteCode: group['inviteCode'] as String? ?? '',
              memberName: name,
              role: role,
              isHome: true,
            );
          },
        );
      },
    );
  }

  /// The standard home page: app bar with notices and profile.
  Widget _page(BuildContext context, Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [_AppLogo(), SizedBox(width: 11), Text('HostelMate')],
        ),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              _openProfile(context);
            },
            icon: const Icon(Icons.account_circle_outlined, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _NoHostelView extends StatelessWidget {
  const _NoHostelView({required this.onCreateGroup, required this.onJoinGroup});

  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E9E5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 38,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Hostel Yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a hostel or join with a code.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreateGroup,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Hostel'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onJoinGroup,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Join Hostel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.home_work_rounded,
        color: AppTheme.primary,
        size: 21,
      ),
    );
  }
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
