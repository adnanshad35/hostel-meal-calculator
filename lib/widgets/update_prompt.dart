import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Shows [child] and, once per app launch, offers a newer version
/// when one is out, or says what is new right after an update.
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
    if (!mounted) return;

    if (update != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.isRequired,
        builder: (_) => UpdateDialog(update: update),
      );
      return;
    }

    final notes = await UpdateService.notesAfterUpdate();
    if (notes == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => WhatsNewDialog(notes: notes),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Offers the new version and installs it from inside the app. A
/// required update has no way to close it and ignores the back button.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.update});

  final AppUpdate update;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  StreamSubscription<OtaEvent>? _download;

  /// Download progress from 0 to 1, or null before it starts.
  double? _progress;
  bool _isInstalling = false;
  String? _error;

  bool get _isBusy => _progress != null && !_isInstalling && _error == null;

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  /// Downloads the APK into the app's own storage, then hands it to
  /// Android's installer.
  void _install() {
    // Only Android can install an APK; anywhere else, the browser
    // downloads it.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _openInBrowser();
      return;
    }

    setState(() {
      _progress = 0;
      _isInstalling = false;
      _error = null;
    });

    try {
      _download = OtaUpdate()
          .execute(
            widget.update.downloadUrl,
            destinationFilename: 'HostelMate.apk',
          )
          .listen(_onEvent, onError: (_) => _fail());
    } catch (_) {
      _fail();
    }
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;

    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final percent = double.tryParse(event.value ?? '') ?? 0;
        setState(() => _progress = percent / 100);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() {
          _progress = 1;
          _isInstalling = true;
        });
      case OtaStatus.ALREADY_RUNNING_ERROR:
        break;
      case OtaStatus.CANCELED:
        setState(() => _progress = null);
      default:
        _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _error = 'The download did not finish.');
  }

  Future<void> _openInBrowser() async {
    final messenger = ScaffoldMessenger.of(context);

    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(widget.update.downloadUrl),
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
    final update = widget.update;

    return PopScope(
      canPop: !update.isRequired && !_isBusy,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: Text(update.isRequired ? 'Update Required' : 'Update Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                update.isRequired
                    ? 'HostelMate ${update.version} is ready. Please update '
                          'your app to continue. It only takes a moment, and '
                          'you will get the latest features and fixes.'
                    : 'HostelMate ${update.version} is ready, with the '
                          'latest features and fixes.',
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
              if (_progress != null) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ??
                      (_isInstalling
                          ? 'Opening the installer…'
                          : 'Downloading ${((_progress ?? 0) * 100).round()}%'),
                  style: TextStyle(
                    color: _error != null
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!update.isRequired && !_isBusy)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          // After a failed download, the browser is the way round it.
          if (_error != null)
            TextButton(
              onPressed: _openInBrowser,
              child: const Text('Use Browser'),
            ),
          FilledButton(
            onPressed: _isBusy ? null : _install,
            child: Text(
              _error != null
                  ? 'Try Again'
                  : _isInstalling
                  ? 'Install'
                  : 'Update',
            ),
          ),
        ],
      ),
    );
  }
}

/// What changed, shown once, the first time a new version opens.
class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key, required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.auto_awesome_rounded,
        size: 34,
        color: AppTheme.accentDeep,
      ),
      title: const Text('What\'s New'),
      content: SingleChildScrollView(child: Text(notes)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got It'),
        ),
      ],
    );
  }
}
