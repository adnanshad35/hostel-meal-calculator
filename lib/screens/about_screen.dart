import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/feature_request_service.dart';
import '../theme/app_theme.dart';

const String _supportEmail = 'adnanshad1035@gmail.com';
const String _linkedInUrl = 'https://www.linkedin.com/in/abuadnanshad/';
const String _website = 'hostelmate.web.app';

/// About the app and the person who made it, and the place to send
/// the developer an idea.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      // Keep fallback label.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(Uri uri, {required String fallbackMessage}) async {
    var opened = false;

    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) _showMessage(fallbackMessage);
  }

  void _openWebsite() => _open(
    Uri.parse('https://$_website'),
    fallbackMessage: 'Unable to open the website.',
  );

  void _openLinkedIn() => _open(
    Uri.parse(_linkedInUrl),
    fallbackMessage: 'Unable to open LinkedIn.',
  );

  void _email() => _open(
    Uri(scheme: 'mailto', path: _supportEmail),
    fallbackMessage:
        'No email application was found. Please email $_supportEmail.',
  );

  /// The app itself in the browser, past the landing page.
  void _openWebVersion() => _open(
    Uri.parse('https://$_website/app/'),
    fallbackMessage: 'Unable to open the web version.',
  );

  /// Not out yet: the links come once the apps are published.
  void _openOtherApps() => _showMessage('Other apps are coming soon.');

  /// Takes the idea in the app and sends it straight to the developer.
  Future<void> _requestFeature() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _FeatureRequestDialog(),
    );

    if (message == null || !mounted) return;

    try {
      await FeatureRequestService.send(message);
      if (!mounted) return;
      _showMessage('Sent. Thank you for the idea.');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Your request could not be sent. Please try again later.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App and Developer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _AppRow(version: _version),
                // Both are for the phone app: the web app is already
                // in the browser, and always the newest version.
                if (!kIsWeb) ...[
                  const Divider(height: 1),
                  _Tile(
                    icon: Icons.language_rounded,
                    title: 'Web Version',
                    trailing: const Icon(Icons.open_in_new, size: 19),
                    onTap: _openWebVersion,
                  ),
                  const Divider(height: 1, indent: 56),
                ] else
                  const Divider(height: 1),
                // The landing page, about the app.
                _Tile(
                  icon: Icons.public,
                  title: 'Website',
                  trailing: const Icon(Icons.open_in_new, size: 19),
                  onTap: _openWebsite,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DeveloperCard(
            onLinkedIn: _openLinkedIn,
            onEmail: _email,
            onOtherApps: _openOtherApps,
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: _Tile(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Request a Feature',
              onTap: _requestFeature,
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's icon, name and version, then what it is for.
class _AppRow extends StatelessWidget {
  const _AppRow({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 46,
                  height: 46,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'HostelMate',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$version',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'HostelMate keeps a hostel\'s meals, shared expenses and '
            'monthly balance in one place. It helps members and managers '
            'settle every month fairly.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// The developer's photo and name, with a button for each way to
/// reach them.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({
    required this.onLinkedIn,
    required this.onEmail,
    required this.onOtherApps,
  });

  final VoidCallback onLinkedIn;
  final VoidCallback onEmail;
  final VoidCallback onOtherApps;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 42,
                backgroundColor: AppTheme.surfaceSoft,
                backgroundImage: AssetImage('assets/images/developer.jpg'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Abu Adnan Shad',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'BSc in CSE, Leading University',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.accentDeep,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ContactButton(
                  icon: const FaIcon(FontAwesomeIcons.linkedinIn, size: 19),
                  label: 'LinkedIn',
                  onTap: onLinkedIn,
                ),
                const SizedBox(width: 12),
                _ContactButton(
                  icon: const Icon(Icons.mail_outline, size: 21),
                  label: 'Email',
                  onTap: onEmail,
                ),
                const SizedBox(width: 12),
                _ContactButton(
                  icon: const Icon(Icons.apps_rounded, size: 21),
                  label: 'Other Apps',
                  onTap: onOtherApps,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Material(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 86,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  IconTheme(
                    data: const IconThemeData(color: AppTheme.primary),
                    child: icon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing:
          trailing ??
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
    );
  }
}

/// Where a user writes the idea they want to send.
class _FeatureRequestDialog extends StatefulWidget {
  const _FeatureRequestDialog();

  @override
  State<_FeatureRequestDialog> createState() => _FeatureRequestDialogState();
}

class _FeatureRequestDialogState extends State<_FeatureRequestDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _controller.text.trim().isEmpty;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('Request a Feature'),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: FeatureRequestService.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
