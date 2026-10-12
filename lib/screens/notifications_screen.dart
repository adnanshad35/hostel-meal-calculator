import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Without a [groupId]: app notices for every user. With one: that
/// hostel's announcements and activity, where admins can announce.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.groupId,
    this.isAdmin = false,
  });

  final String? groupId;
  final bool isAdmin;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<AppNotification>> _stream;

  bool get _isGroup => widget.groupId != null;

  bool get _canAnnounce =>
      _isGroup ? widget.isAdmin : NotificationService.isDeveloper;

  @override
  void initState() {
    super.initState();
    _stream = _isGroup
        ? NotificationService.watchGroup(widget.groupId!)
        : NotificationService.watchApp();
    NotificationService.markSeen(isGroup: _isGroup);
  }

  @override
  void dispose() {
    // Anything that arrived while the list was open has been seen too.
    NotificationService.markSeen(isGroup: _isGroup);
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final clock = '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';

    final isToday = time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
    if (isToday) return 'Today, $clock';

    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month/${time.year}, $clock';
  }

  void _showError(Object error, String fallback) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is FirebaseException && error.code == 'permission-denied'
              ? 'You do not have permission to do this.'
              : error is FirebaseException
                  ? error.message ?? fallback
                  : fallback,
        ),
      ),
    );
  }

  Future<void> _announce() async {
    final announcement = await showDialog<({String title, String message})>(
      context: context,
      builder: (_) => _AnnouncementDialog(isGroup: _isGroup),
    );

    if (announcement == null || !mounted) return;

    try {
      if (_isGroup) {
        await NotificationService.sendGroupAnnouncement(
          groupId: widget.groupId!,
          message: announcement.message,
        );
      } else {
        await NotificationService.sendAppNotice(
          title: announcement.title,
          message: announcement.message,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isGroup
                ? 'Announcement sent to the hostel.'
                : 'Notice sent to all users.',
          ),
        ),
      );
    } catch (error) {
      _showError(error, 'Unable to send the announcement.');
    }
  }

  Future<void> _delete(AppNotification item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete?'),
          content: const Text(
            'It will be removed for everyone. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      if (_isGroup) {
        await NotificationService.deleteGroupNotification(
          groupId: widget.groupId!,
          id: item.id,
        );
      } else {
        await NotificationService.deleteAppNotice(item.id);
      }
    } catch (error) {
      _showError(error, 'Unable to delete it.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGroup ? 'Hostel Notifications' : 'App Notices'),
      ),
      floatingActionButton: _canAnnounce
          ? FloatingActionButton.extended(
              onPressed: _announce,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Announce'),
            )
          : null,
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load notifications.'),
            );
          }

          final items = snapshot.data ?? const <AppNotification>[];

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _isGroup
                      ? 'No hostel notifications yet.'
                      : 'No notices yet. Updates and important news '
                          'about the app will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                key: ValueKey(item.id),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onLongPress: _canAnnounce ? () => _delete(item) : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.isAnnouncement
                          ? const Color(0xFFFFF2DA)
                          : AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.isAnnouncement
                          ? Icons.campaign_outlined
                          : Icons.receipt_long_outlined,
                      color: item.isAnnouncement
                          ? AppTheme.warning
                          : AppTheme.primary,
                    ),
                  ),
                  title: Text(
                    item.title.isEmpty ? 'Notification' : item.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${item.message}\n${_formatTime(item.createdAt)}',
                    ),
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

/// Owns its text controllers so they are disposed only after the
/// dialog has fully closed.
///
/// A hostel announcement is a single message of limited length; an
/// app notice also has a title.
class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.isGroup});

  final bool isGroup;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Keeps the word counter current.
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop((
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const maxWords = NotificationService.maxAnnouncementWords;
    final words = NotificationService.wordCount(_messageController.text);

    return AlertDialog(
      title: Text(widget.isGroup ? 'New Announcement' : 'New App Notice'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isGroup
                    ? 'Every member of this hostel will see it.'
                    : 'Every user of the app will see this.',
              ),
              const SizedBox(height: 16),
              if (!widget.isGroup) ...[
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _messageController,
                autofocus: widget.isGroup,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  counterText: widget.isGroup
                      ? '$words / $maxWords words'
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message.';
                  }
                  if (widget.isGroup && words > maxWords) {
                    return 'Please keep it within $maxWords words.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Send'),
        ),
      ],
    );
  }
}
