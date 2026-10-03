import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'create_group_screen.dart';
import 'hostel_dashboard_screen.dart';
import 'join_group_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openCreateGroup(
    BuildContext context,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CreateGroupScreen(),
      ),
    );
  }

  Future<void> _openJoinGroup(
    BuildContext context,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const JoinGroupScreen(),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  String _readUserName(
    User user,
    Map<String, dynamic>? userData,
  ) {
    final possibleNames = [
      userData?['name'],
      userData?['displayName'],
      userData?['fullName'],
      user.displayName,
    ];

    for (final value in possibleNames) {
      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            _AppLogo(),
            SizedBox(width: 11),
            Text('HostelMate'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              _openProfile(context);
            },
            icon: const Icon(
              Icons.account_circle_outlined,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (userSnapshot.hasError) {
              return const _PageMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load account',
              );
            }

            final userData =
                userSnapshot.data?.data();

            final groupId =
                userData?['groupId'] as String?;

            final role =
                userData?['role'] as String? ??
                    'member';

            final name =
                _readUserName(user, userData);

            if (groupId == null ||
                groupId.isEmpty) {
              return _NoHostelView(
                onCreateGroup: () {
                  _openCreateGroup(context);
                },
                onJoinGroup: () {
                  _openJoinGroup(context);
                },
              );
            }

            return StreamBuilder<
                DocumentSnapshot<
                    Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .snapshots(),
              builder: (context, groupSnapshot) {
                if (groupSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !groupSnapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (groupSnapshot.hasError ||
                    !groupSnapshot.hasData ||
                    !groupSnapshot.data!.exists) {
                  return const _PageMessage(
                    icon:
                        Icons.apartment_outlined,
                    title: 'Hostel not found',
                  );
                }

                final group =
                    groupSnapshot.data!.data()!;

                final groupName =
                    group['name'] as String? ??
                        'Hostel Group';

                final inviteCode =
                    group['inviteCode']
                            as String? ??
                        '';

                final memberIds =
                    List<String>.from(
                  group['memberIds'] as List? ??
                      [],
                );

                return _HostelView(
                  groupName: groupName,
                  memberCount:
                      memberIds.length,
                  onOpenHostel: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            HostelDashboardScreen(
                          groupId: groupId,
                          groupName: groupName,
                          inviteCode:
                              inviteCode,
                          memberName: name,
                          role: role,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NoHostelView extends StatelessWidget {
  const _NoHostelView({
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 460,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius:
                BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E9E5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius:
                      BorderRadius.circular(22),
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
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a hostel or join with a code.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreateGroup,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label:
                      const Text('Create Hostel'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onJoinGroup,
                  icon: const Icon(
                    Icons.group_add_outlined,
                  ),
                  label:
                      const Text('Join Hostel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostelView extends StatelessWidget {
  const _HostelView({
    required this.groupName,
    required this.memberCount,
    required this.onOpenHostel,
  });

  final String groupName;
  final int memberCount;
  final VoidCallback onOpenHostel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(26),
              onTap: onOpenHostel,
              child: Ink(
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    begin: Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryDark,
                      AppTheme.primary,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary
                          .withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 28,
                      offset:
                          const Offset(0, 14),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration:
                                BoxDecoration(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.15,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(19),
                            ),
                            child: const Icon(
                              Icons
                                  .apartment_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.14,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(20),
                            ),
                            child: Text(
                              '$memberCount '
                              '${memberCount == 1 ? 'member' : 'members'}',
                              style:
                                  const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        groupName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(
                            alpha: 0.13,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Enter Hostel',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            Spacer(),
                            Icon(
                              Icons
                                  .arrow_forward_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
  const _PageMessage({
    required this.icon,
    required this.title,
  });

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
            Icon(
              icon,
              size: 48,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}