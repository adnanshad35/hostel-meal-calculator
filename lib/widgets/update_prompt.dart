import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

/// Shows [child] and, once per app launch, requires the user to
/// update when a newer version has been released.
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  static bool _checkedThisLaunch = false;

  @override
  void initState() {
    super.initState();

    if (!_checkedThisLaunch) {
      _checkedThisLaunch = true;
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService.check();
    if (update == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(update: update),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Stays open until the new version is installed: it has no dismiss
/// action and ignores the back button.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.update});

  final AppUpdate update;

  Future<void> _openDownload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(update.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open the download page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: const Text('Update required'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HostelMate ${update.version} is ready. Please update '
                'your app to continue. It only takes a moment, and '
                'you will get the latest features and fixes.',
              ),
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'What\'s new',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(update.notes),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => _openDownload(context),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
