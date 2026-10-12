import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/notifications_screen.dart';
import '../services/notification_service.dart';

/// App bar bell with an unread badge.
///
/// Without a [groupId] it shows app notices for every user and pops up
/// any notice the user has not seen yet. With a [groupId] it shows
/// that hostel's announcements and activity.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.groupId, this.isAdmin = false});

  final String? groupId;
  final bool isAdmin;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;

  bool _hasUserData = false;
  DateTime? _seenAt;
  List<AppNotification> _items = const [];

  bool _isShowingNotice = false;
  final Set<String> _shownNoticeIds = {};

  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  bool get _isGroup => widget.groupId != null;

  @override
  void initState() {
    super.initState();

    final seenField = NotificationService.seenField(isGroup: _isGroup);

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _hasUserData = true;
            _seenAt = (snapshot.data()?[seenField] as Timestamp?)?.toDate();
          });
          _showUnseenNotice();
        }, onError: (_) {});

    final stream = _isGroup
        ? NotificationService.watchGroup(widget.groupId!)
        : NotificationService.watchApp();

    _notificationsSubscription = stream.listen(
      (items) {
        setState(() => _items = items);
        _showUnseenNotice();
      },
      // Not readable (for example after leaving the hostel).
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  /// App notices are important enough to interrupt once.
  Future<void> _showUnseenNotice() async {
    if (_isGroup || !_hasUserData || _isShowingNotice || !mounted) return;

    final notice = NotificationService.newestUnseen(_items, seenAt: _seenAt);

    if (notice == null || _shownNoticeIds.contains(notice.id)) return;

    _isShowingNotice = true;
    _shownNoticeIds.add(notice.id);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.campaign_outlined, size: 36),
          title: Text(notice.title.isEmpty ? 'Notice' : notice.title),
          content: SingleChildScrollView(child: Text(notice.message)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Okay'),
            ),
          ],
        );
      },
    );

    _isShowingNotice = false;
    await NotificationService.markSeen(isGroup: false);
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          groupId: widget.groupId,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = NotificationService.unreadCount(
      _items,
      seenAt: _seenAt,
      currentUserId: _currentUserId,
    );

    return IconButton(
      tooltip: _isGroup ? 'Hostel notifications' : 'App notices',
      onPressed: _openNotifications,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_outlined, size: 26),
      ),
    );
  }
}
