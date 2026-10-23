import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_member.dart';
import '../services/duty_roster.dart';
import '../services/group_member_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tiles.dart';
import '../widgets/member_name_dialog.dart';
import 'duty_roster_screen.dart' show dutyDatesText;
import 'group_settings_screen.dart';
import 'hostel_activation_screen.dart';

class HostelDetailsScreen extends StatefulWidget {
  const HostelDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    this.membersOnly = false,
  });

  final String groupId;
  final String groupName;
  final bool isAdmin;

  /// True for the list of members that the About screen opens. The
  /// same screen is used, so managing members works the same in both.
  final bool membersOnly;

  @override
  State<HostelDetailsScreen> createState() => _HostelDetailsScreenState();
}

class _HostelDetailsScreenState extends State<HostelDetailsScreen> {
  late final Stream<List<GroupMember>> _membersStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _groupSubscription;

  late final Stream<HostelSubscription> _subscriptionStream;

  Set<String> _admins = {};
  String _inviteCode = '';
  DutyRoster _roster = const DutyRoster([]);

  /// App users in the hostel. Members without the app are not counted.
  Set<String> _appUserIds = {};
  bool _isBusy = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _membersStream = GroupMemberService.watch(
      widget.groupId,
      activeOnly: false,
    );
    _subscriptionStream = SubscriptionService.watch(widget.groupId);
    _groupSubscription = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .snapshots()
        .listen((snapshot) {
          final admins = snapshot.data()?['admins'] as List? ?? [];
          final memberIds = snapshot.data()?['memberIds'] as List? ?? [];
          setState(() {
            _admins = Set<String>.from(admins);
            _appUserIds = Set<String>.from(memberIds);
            _inviteCode = snapshot.data()?['inviteCode'] as String? ?? '';
            _roster = DutyRoster.fromGroupData(snapshot.data());
          });
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

  Future<void> _deleteShadowMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Member?'),
          content: Text(
            'Delete ${member.name} with all their meals and expenses? '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => GroupMemberService.deleteShadowMember(
        groupId: widget.groupId,
        member: member,
      ),
      successMessage: '${member.name} was deleted.',
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
                title: const Text('Edit Name'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Link to App User'),
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
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.danger,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.danger),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
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
      case 'delete':
        await _deleteShadowMember(member);
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
                  title: const Text('Change to Member'),
                  onTap: () => Navigator.of(sheetContext).pop('demote'),
                )
              else
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Make Administrator'),
                  onTap: () => Navigator.of(sheetContext).pop('promote'),
                ),
              if (!isCurrentUser)
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: AppTheme.danger,
                  ),
                  title: const Text(
                    'Remove from Hostel',
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

  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invitation code copied.')));
  }

  /// Members in the order of their turns on duty, first to last, with
  /// those who have no turn after them, by name.
  List<GroupMember> _byDuty(List<GroupMember> members) {
    final now = DateTime.now();
    final sorted = [...members];

    sorted.sort((a, b) {
      final first = _roster.turnOf(a.id, now)?.turn.fromDate;
      final second = _roster.turnOf(b.id, now)?.turn.fromDate;

      if (first == null && second == null) {
        return GroupMember.compareByName(a, b);
      }
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });

    return sorted;
  }

  void _openMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostelDetailsScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          isAdmin: widget.isAdmin,
          membersOnly: true,
        ),
      ),
    );
  }

  void _openActivation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostelActivationScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
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

  /// True when the signed-in admin is the only app user in the hostel.
  /// They cannot leave, because a hostel needs an admin, so they are
  /// offered deletion instead.
  bool get _isAloneAsAdmin =>
      _admins.contains(_currentUserId) &&
      _appUserIds.length == 1 &&
      _appUserIds.contains(_currentUserId);

  Future<void> _deleteHostel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Hostel?'),
          content: Text(
            'Delete ${widget.groupName} and everything recorded in it? '
            'You are its only member with an account.\n\n'
            'This cannot be undone. Afterwards you can create or join '
            'another hostel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Hostel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);

    try {
      await GroupMemberService.deleteHostel(widget.groupId);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseException
                ? error.code == 'permission-denied'
                      ? 'This hostel cannot be deleted while other '
                            'members with accounts are in it.'
                      : error.message ?? 'Unable to delete the hostel.'
                : error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.membersOnly ? 'Members' : 'Hostel Details'),
      ),
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
              if (!widget.membersOnly) ...[
                // Its activation is read here, so the card shows it.
                StreamBuilder<HostelSubscription>(
                  stream: _subscriptionStream,
                  builder: (context, snapshot) {
                    final isLoading = !snapshot.hasData && !snapshot.hasError;

                    return _HostelHeader(
                      groupName: widget.groupName,
                      isAdmin: widget.isAdmin,
                      subscription: isLoading ? null : snapshot.data,
                      inviteCode: _inviteCode,
                      onCopyCode: _copyInviteCode,
                      onOpenActivation:
                          widget.isAdmin &&
                              !isLoading &&
                              snapshot.data?.accessDisabled != true &&
                              !_isBusy
                          ? _openActivation
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TileGroup(
                  children: [
                    GroupTile(
                      icon: Icons.groups_outlined,
                      title: 'Members',
                      onTap: _openMembers,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${activeMembers.length}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const TileArrow(),
                        ],
                      ),
                    ),
                    // Only admins get the settings.
                    if (widget.isAdmin)
                      GroupTile(
                        icon: Icons.settings_outlined,
                        title: 'Admin Settings',
                        onTap: _isBusy ? null : _openGroupSettings,
                      ),
                  ],
                ),
              ],
              if (widget.membersOnly) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeMembers.length == 1
                            ? '1 Member'
                            : '${activeMembers.length} Members',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final member in _byDuty(activeMembers)) ...[
                  _MemberCard(
                    key: ValueKey(member.id),
                    member: member,
                    isGroupAdmin: _admins.contains(member.id),
                    isCurrentUser: member.id == _currentUserId,
                    duty: _roster.turnOf(member.id, DateTime.now()),
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
                  const SizedBox(height: 6),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _isBusy
                                  ? null
                                  : () => _reactivateMember(member),
                              child: const Text('Reactivate'),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: _isBusy
                                  ? null
                                  : () => _deleteShadowMember(member),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
              if (!widget.membersOnly) ...[
                const SizedBox(height: 28),
                // Kept apart from everything else, and quiet, so it is
                // not tapped by mistake.
                Center(
                  child: TextButton.icon(
                    onPressed: _isBusy
                        ? null
                        : _isAloneAsAdmin
                        ? _deleteHostel
                        : _leaveHostel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                    icon: Icon(
                      _isAloneAsAdmin
                          ? Icons.delete_outline
                          : Icons.exit_to_app,
                      size: 20,
                    ),
                    label: Text(
                      _isAloneAsAdmin ? 'Delete Hostel' : 'Leave Hostel',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The top of the page: the hostel's name and the signed-in member's
/// role, then whether the hostel is active and the code new members
/// join with.
class _HostelHeader extends StatelessWidget {
  const _HostelHeader({
    required this.groupName,
    required this.isAdmin,
    required this.subscription,
    required this.inviteCode,
    required this.onCopyCode,
    required this.onOpenActivation,
  });

  final String groupName;
  final bool isAdmin;

  /// Null while it loads.
  final HostelSubscription? subscription;
  final String inviteCode;
  final VoidCallback onCopyCode;

  /// Null for members: only an admin activates the hostel.
  final VoidCallback? onOpenActivation;

  /// What the activation row says, and its icon.
  (String, IconData) _activation() {
    final subscription = this.subscription;
    final now = DateTime.now();

    if (subscription == null) return ('Checking…', Icons.hourglass_empty);
    if (subscription.accessDisabled) return ('Suspended', Icons.block);
    if (subscription.editingDisabled) {
      return ('Read-only', Icons.lock_outline);
    }

    final until = subscription.activeUntil;
    if (subscription.isActive(now)) {
      return (
        until == null ? 'Active' : 'Active · ${subscription.timeLeftText(now)}',
        Icons.verified_outlined,
      );
    }
    return (until == null ? 'Not Activated' : 'Expired', Icons.lock_outline);
  }

  /// One line under the name: an icon, a label, its value, and what
  /// tapping it does.
  Widget _row({
    required IconData icon,
    required String label,
    required Widget value,
    required VoidCallback? onTap,
    IconData? action,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: value),
              ),
              if (action != null) ...[
                const SizedBox(width: 6),
                Icon(
                  action,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (activation, activationIcon) = _activation();
    const valueStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        boxShadow: AppTheme.heroShadow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: AppTheme.accent,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          color: isAdmin ? AppTheme.ink : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row(
            icon: activationIcon,
            label: 'Activation',
            value: Text(
              activation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
            onTap: onOpenActivation,
            action: onOpenActivation == null ? null : Icons.chevron_right,
          ),
          if (inviteCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            _row(
              icon: Icons.key_outlined,
              label: 'Hostel Code',
              value: Text(
                inviteCode,
                style: valueStyle.copyWith(letterSpacing: 2),
              ),
              onTap: onCopyCode,
              action: Icons.copy_rounded,
            ),
          ],
        ],
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
    required this.duty,
    required this.canEdit,
    this.onTap,
    this.onLongPress,
  });

  final GroupMember member;
  final bool isGroupAdmin;
  final bool isCurrentUser;

  /// Their turn on duty and whether it is over, running or still to
  /// come. Null for a member with no turn.
  final ({DutyTurn turn, DutyStatus status})? duty;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // One slim line per member: who, when they are on duty, and for
    // an admin the menu.
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE3E9E5)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
          child: Row(
            children: [
              _MemberAvatar(member: member),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isCurrentUser
                                ? '${member.name} (You)'
                                : member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isGroupAdmin) ...[
                          const SizedBox(width: 6),
                          const _Tag('Admin', isStrong: true),
                        ],
                        if (!member.isAppUser) ...[
                          const SizedBox(width: 6),
                          const _Tag('No App'),
                        ],
                      ],
                    ),
                    if (member.phone.isNotEmpty)
                      Text(
                        member.phone,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (duty != null) ...[
                const SizedBox(width: 8),
                // A finished turn keeps its dates, ticked and faded;
                // the one running now is in green.
                if (duty!.status == DutyStatus.done)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 15,
                      color: Color(0xFFA3ABA7),
                    ),
                  ),
                Text(
                  dutyDatesText(duty!.turn),
                  style: TextStyle(
                    color: switch (duty!.status) {
                      DutyStatus.done => const Color(0xFFA3ABA7),
                      DutyStatus.current => AppTheme.primary,
                      DutyStatus.upcoming => AppTheme.textSecondary,
                    },
                    fontSize: 12.5,
                    fontWeight: duty!.status == DutyStatus.current
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ],
              if (canEdit)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                )
              else
                const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small label beside a member's name: green for Admin, grey for
/// anything else.
class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.isStrong = false});

  final String text;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isStrong ? const Color(0xFFD8F2E5) : const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isStrong ? AppTheme.primaryDark : AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A member's initials. Green for someone with the app, faded for a
/// member who was added without it.
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: member.isAppUser
            ? AppTheme.surfaceSoft
            : const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        member.initials,
        style: TextStyle(
          color: member.isAppUser ? AppTheme.primary : const Color(0xFFA3ABA7),
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
