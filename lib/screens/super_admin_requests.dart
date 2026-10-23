import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/feature_request_service.dart';
import '../theme/app_theme.dart';

/// The feature requests users sent from the app, newest first. Only
/// the super admin can load them.
class AdminRequestsTab extends StatefulWidget {
  const AdminRequestsTab({super.key});

  @override
  State<AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<AdminRequestsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<FeatureRequest>> _requests = FeatureRequestService.load();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final next = FeatureRequestService.load();
    setState(() {
      _requests = next;
    });

    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _delete(FeatureRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Request?'),
          content: const Text('This cannot be undone.'),
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

    final messenger = ScaffoldMessenger.of(context);

    try {
      await FeatureRequestService.delete(request);
      messenger.showSnackBar(const SnackBar(content: Text('Request deleted.')));
      await _refresh();
    } on FirebaseException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only the super admin can do this.'
                : error.message ?? 'Something went wrong.',
          ),
        ),
      );
    }
  }

  static String _date(DateTime? date) {
    if (date == null) return '';

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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<List<FeatureRequest>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load the requests.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? const <FeatureRequest>[];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                requests.isEmpty
                    ? 'No requests yet'
                    : requests.length == 1
                    ? '1 request'
                    : '${requests.length} requests',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              for (final request in requests) ...[
                Card(
                  key: ValueKey(request.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.message,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                [
                                  if (request.userName.isNotEmpty)
                                    request.userName,
                                  if (request.email.isNotEmpty) request.email,
                                  if (request.createdAt != null)
                                    _date(request.createdAt),
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete Request',
                          onPressed: () => _delete(request),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}
