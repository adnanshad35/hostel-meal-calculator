import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _versionLabel = 'Version 1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = 'Version ${info.version}+${info.buildNumber}';
      });
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('App and Developer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ─── App ───
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('HostelMate', style: textTheme.titleLarge),
                                Text(_versionLabel),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'HostelMate keeps a hostel\'s meals and shared '
                        'expenses in one place. Members record what they '
                        'eat and what they spend, and the app works out '
                        'the meal rate and what each person pays or gets '
                        'back at the end of the month.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _open(
                    Uri.parse('https://$_website'),
                    fallbackMessage: 'Unable to open the website.',
                  ),
                  leading: const Icon(Icons.public, color: AppTheme.primary),
                  title: const Text(
                    _website,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Developer ───
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.surfaceSoft,
                        backgroundImage: AssetImage(
                          'assets/images/developer.jpg',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Abu Adnan Shad', style: textTheme.titleLarge),
                            const Text('Developer'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _open(
                    Uri.parse(_linkedInUrl),
                    fallbackMessage: 'Unable to open LinkedIn.',
                  ),
                  leading: const FaIcon(
                    FontAwesomeIcons.linkedinIn,
                    color: AppTheme.primary,
                    size: 21,
                  ),
                  title: const Text(
                    'LinkedIn',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 19),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _open(
                    Uri(scheme: 'mailto', path: _supportEmail),
                    fallbackMessage:
                        'No email application was found. '
                        'Please email $_supportEmail.',
                  ),
                  leading: const Icon(
                    Icons.mail_outline,
                    color: AppTheme.primary,
                  ),
                  title: const Text(
                    _supportEmail,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Feedback ───
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: _requestFeature,
              leading: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.primary,
              ),
              title: const Text(
                'Request a Feature',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
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
            border: OutlineInputBorder(),
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
