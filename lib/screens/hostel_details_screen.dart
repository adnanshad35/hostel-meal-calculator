import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/group_member_service.dart';
import '../theme/app_theme.dart';
import '../widgets/member_name_dialog.dart';
import 'group_settings_screen.dart';

class HostelDetailsScreen extends StatefulWidget {
  const HostelDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
  });

  final String groupId;
  final String groupName;
  final bool isAdmin;

  @override
  State<HostelDetailsScreen> createState() => _HostelDetailsScreenState();
}

class _HostelDetailsScreenState extends State<HostelDetailsScreen> {
  late final Stream<List<GroupMember>> _membersStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _groupSubscription;

  Set<String> _admins = {};
  bool _isBusy = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _membersStream = GroupMemberService.watch(
      widget.groupId,
      activeOnly: false,
    );
    _groupSubscription = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .snapshots()
        .listen((snapshot) {
          final admins = snapshot.data()?['admins'] as List? ?? [];
          setState(() => _admins = Set<String>.from(admins));
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _isBusy = true);

    try {
      await action();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'You do not have permission to change members.'
                : error.message ?? 'Unable to update members.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _renameMember(GroupMember member) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          MemberNameDialog(title: 'Edit Name', initialName: member.name),
    );

    if (name == null || name == member.name || !mounted) return;

    await _run(
      () => GroupMemberService.rename(
        groupId: widget.groupId,
        memberId: member.id,
        name: name,
      ),
      successMessage: 'Name updated.',
    );
  }

  Future<void> _deactivateMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Member?'),
          content: Text(
            '${member.name} will no longer appear in meal entry, '
            'expenses, or new calculations.\n\n'
            'Their previous meals and expenses will remain in '
            'the hostel records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => GroupMemberService.setActive(
        groupId: widget.groupId,
        memberId: member.id,
        active: false,
      ),
      successMessage: '${member.name} was deactivated.',
    );
  }

  Future<void> _reactivateMember(GroupMember member) async {
    await _run(
      () => GroupMemberService.setActive(
        groupId: widget.groupId,
        memberId: member.id,
        active: true,
      ),
      successMessage: '${member.name} is active again.',
    );
  }

  Future<void> _linkMember(
    GroupMember shadow,
    List<GroupMember> appUsers,
  ) async {
    if (appUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app users are available to link.')),
      );
      return;
    }

    final appUser = await showDialog<GroupMember>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('Link ${shadow.name} to'),
          children: [
            for (final candidate in appUsers)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(candidate),
                child: Row(
                  children: [
                    _MemberAvatar(member: candidate),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        candidate.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (appUser == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Link to App User?'),
          content: Text(
            'All meals and expenses recorded for ${shadow.name} '
            'will be moved to ${appUser.name}, and ${shadow.name} '
            'will be removed from the member list.\n\n'
            'If both have a meal entry on the same day, the entry '
            'of ${appUser.name} is kept. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Link'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => GroupMemberService.linkToAppUser(
        groupId: widget.groupId,
        shadow: shadow,
        appUser: appUser,
      ),
      successMessage: '${shadow.name} was linked to ${appUser.name}.',
    );
  }

  Future<void> _showOptions(
    GroupMember member,
    List<GroupMember> appUsers,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit name'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Link to app user'),
                onTap: () => Navigator.of(sheetContext).pop('link'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_off_outlined,
                  color: AppTheme.danger,
                ),
                title: const Text(
                  'Deactivate',
                  style: TextStyle(color: AppTheme.danger),
                ),
                onTap: () => Navigator.of(sheetContext).pop('deactivate'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'rename':
        await _renameMember(member);
      case 'link':
        await _linkMember(member, appUsers);
      case 'deactivate':
        await _deactivateMember(member);
    }
  }

  Future<void> _changeAdminRole(
    GroupMember member, {
    required bool makeAdmin,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(makeAdmin ? 'Promote Member' : 'Remove Admin Role'),
          content: Text(
            makeAdmin
                ? 'Promote ${member.name} to administrator?'
                : 'Change ${member.name} from administrator to member?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(makeAdmin ? 'Promote' : 'Demote'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => GroupMemberService.setAdminRole(
        groupId: widget.groupId,
        memberId: member.id,
        makeAdmin: makeAdmin,
      ),
      successMessage: makeAdmin
          ? '${member.name} is now an administrator.'
          : '${member.name} is now a member.',
    );
  }

  Future<void> _removeAppUser(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Member?'),
          content: Text(
            'Remove ${member.name} from this hostel?\n\n'
            'Their previous meals and expenses will remain in '
            'the hostel records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove Member'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => GroupMemberService.removeAppUser(
        groupId: widget.groupId,
        member: member,
      ),
      successMessage: '${member.name} was removed from the hostel.',
    );
  }

  Future<void> _showAppUserOptions(GroupMember member) async {
    final isMemberAdmin = _admins.contains(member.id);
    final isCurrentUser = member.id == _currentUserId;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMemberAdmin)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Change to member'),
                  onTap: () => Navigator.of(sheetContext).pop('demote'),
                )
              else
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Make administrator'),
                  onTap: () => Navigator.of(sheetContext).pop('promote'),
                ),
              if (!isCurrentUser)
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: AppTheme.danger,
                  ),
                  title: const Text(
                    'Remove from hostel',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'promote':
        await _changeAdminRole(member, makeAdmin: true);
      case 'demote':
        await _changeAdminRole(member, makeAdmin: false);
      case 'remove':
        await _removeAppUser(member);
    }
  }

  void _openGroupSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
  }

  Future<void> _leaveHostel() async {
    final isOnlyAdmin = _admins.contains(_currentUserId) && _admins.length <= 1;

    if (isOnlyAdmin) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cannot Leave Hostel'),
            content: const Text(
              'You are the only administrator. Promote another '
              'member to administrator before leaving.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Okay'),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Hostel?'),
          content: Text(
            'Are you sure you want to leave ${widget.groupName}?\n\n'
            'Your previous meals and expenses will remain in the '
            'hostel records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave Hostel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);

    try {
      await GroupMemberService.leaveGroup(widget.groupId);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseException
                ? error.message ?? 'Unable to leave the hostel.'
                : error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroupAdmin = widget.isAdmin || _admins.contains(_currentUserId);

    return Scaffold(
      appBar: AppBar(title: const Text('Hostel Details')),
      body: StreamBuilder<List<GroupMember>>(
        stream: _membersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load members.'));
          }

          final members = snapshot.data ?? [];
          final activeMembers = members
              .where((member) => member.active)
              .toList();
          final appUsers = activeMembers
              .where((member) => member.isAppUser)
              .toList();
          final deactivatedMembers = widget.isAdmin
              ? members
                    .where(
                      (member) =>
                          !member.active &&
                          !member.isAppUser &&
                          member.linkedTo == null,
                    )
                    .toList()
              : <GroupMember>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (_isBusy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              _HostelCard(groupName: widget.groupName, isAdmin: isGroupAdmin),
              if (widget.isAdmin) ...[
                const SizedBox(height: 10),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: _isBusy ? null : _openGroupSettings,
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: AppTheme.primary,
                    ),
                    title: const Text(
                      'Group Settings',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Add members, control joining, reset a month',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                activeMembers.length == 1
                    ? '1 member'
                    : '${activeMembers.length} members',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              for (final member in activeMembers) ...[
                _MemberCard(
                  key: ValueKey(member.id),
                  member: member,
                  isGroupAdmin: _admins.contains(member.id),
                  isCurrentUser: member.id == _currentUserId,
                  canEdit: widget.isAdmin && !_isBusy,
                  onTap: !widget.isAdmin || _isBusy
                      ? null
                      : member.isAppUser
                      ? () => _showAppUserOptions(member)
                      : () => _showOptions(member, appUsers),
                  onLongPress: widget.isAdmin && !member.isAppUser && !_isBusy
                      ? () => _linkMember(member, appUsers)
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              if (widget.isAdmin) ...[
                const SizedBox(height: 4),
                const Text(
                  'Tap a member to manage them. Long-press a member '
                  'without the app to link them to their app account.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
              if (deactivatedMembers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Deactivated',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                for (final member in deactivatedMembers) ...[
                  Card(
                    key: ValueKey(member.id),
                    child: ListTile(
                      leading: _MemberAvatar(member: member),
                      title: Text(member.name),
                      subtitle: const Text('Deactivated'),
                      trailing: TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => _reactivateMember(member),
                        child: const Text('Reactivate'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 24),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: _isBusy ? null : _leaveHostel,
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: AppTheme.danger,
                  ),
                  title: const Text(
                    'Leave Hostel',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Leave this hostel group.'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The hostel's name and the signed-in member's position in it.
class _HostelCard extends StatelessWidget {
  const _HostelCard({required this.groupName, required this.isAdmin});

  final String groupName;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceSoft,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(
          Icons.apartment_outlined,
          color: AppTheme.primary,
          size: 30,
        ),
        title: Text(
          groupName,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            isAdmin ? 'You are an administrator' : 'You are a member',
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    super.key,
    required this.member,
    required this.isGroupAdmin,
    required this.isCurrentUser,
    required this.canEdit,
    this.onTap,
    this.onLongPress,
  });

  final GroupMember member;
  final bool isGroupAdmin;
  final bool isCurrentUser;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String get _subtitle {
    final type = !member.isAppUser
        ? 'Shadow Member'
        : isGroupAdmin
        ? 'Administrator'
        : 'App User';
    final date = member.addedAt;
    if (date == null) return type;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final verb = member.isAppUser ? 'Joined' : 'Added';

    return '$type • $verb ${date.day} ${months[date.month - 1]} '
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _MemberAvatar(member: member),
        title: Row(
          children: [
            Flexible(
              child: Text(
                isCurrentUser ? '${member.name} (You)' : member.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (member.isAppUser) ...[
              const SizedBox(width: 8),
              const _AppUserChip(),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(_subtitle),
        ),
        trailing: canEdit
            ? Icon(
                member.isAppUser
                    ? Icons.more_vert_rounded
                    : Icons.edit_outlined,
                color: AppTheme.textSecondary,
              )
            : null,
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        member.initials,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppUserChip extends StatelessWidget {
  const _AppUserChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'App User',
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
