import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_member.dart';
import '../services/group_member_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tiles.dart';

/// Members an admin made alumni. Their profile and records are kept,
/// and they can be restored: a member without the app at once, an app
/// user by joining again with the Hostel Code.
class AlumniScreen extends StatefulWidget {
  const AlumniScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<AlumniScreen> createState() => _AlumniScreenState();
}

class _AlumniScreenState extends State<AlumniScreen> {
  late final Stream<List<GroupMember>> _members;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _members = GroupMemberService.watch(widget.groupId, activeOnly: false);
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'You do not have permission to change members.'
                : error.message ?? 'Unable to update members.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restore(GroupMember member) async {
    if (member.isAppUser) {
      await _showRejoinCode(member);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Member?'),
          content: Text(
            '${member.name} becomes an active member again. Their old '
            'records stay as they are, and new meals count from today.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => GroupMemberService.restoreShadowMember(
        groupId: widget.groupId,
        member: member,
      ),
      successMessage: '${member.name} is an active member again.',
    );
  }

  /// An app user rejoins on their own phone, with the Hostel Code; an
  /// admin cannot put them in a hostel for them.
  Future<void> _showRejoinCode(GroupMember member) async {
    String code = '';
    try {
      final group = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      code = group.data()?['inviteCode'] as String? ?? '';
    } on FirebaseException {
      code = '';
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${member.name} uses the app, so they rejoin with the '
                'Hostel Code. Their old records stay, and they are '
                'active again as soon as they join.',
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(
                  code,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (code.isNotEmpty)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hostel Code copied.')),
                  );
                },
                child: const Text('Copy Code'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Okay'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permanently Delete?'),
          content: Text(
            '${member.name} is taken off the Alumni list. Their records '
            'stay in past months.',
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
      () => GroupMemberService.deleteAlumni(
        groupId: widget.groupId,
        member: member,
      ),
      successMessage: '${member.name} was deleted.',
    );
  }

  static String _leftOn(String? dateKey) {
    if (dateKey == null) return '';
    final parts = dateKey.split('-');
    if (parts.length != 3) return '';

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
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return '';

    return 'Left ${int.tryParse(parts[2]) ?? parts[2]} '
        '${months[month - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alumni')),
      body: StreamBuilder<List<GroupMember>>(
        stream: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load members.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alumni = snapshot.data!
              .where((member) => member.isAlumni)
              .toList();

          if (alumni.isEmpty) {
            return const Center(child: Text('No Alumni'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (_isBusy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              TileGroup(
                title: alumni.length == 1
                    ? '1 Alumni'
                    : '${alumni.length} Alumni',
                children: [
                  for (final member in alumni)
                    ListTile(
                      key: ValueKey(member.id),
                      leading: const IconBadge(Icons.school_outlined),
                      title: TileTitle(member.name),
                      subtitle: _leftOn(member.leftOn).isEmpty
                          ? null
                          : Text(_leftOn(member.leftOn)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _isBusy ? null : () => _restore(member),
                            child: const Text('Restore'),
                          ),
                          IconButton(
                            tooltip: 'Permanently Delete',
                            onPressed: _isBusy ? null : () => _delete(member),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
