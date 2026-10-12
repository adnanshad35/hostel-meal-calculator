import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const String _supportEmail = 'adnanshad1035@gmail.com';
const String _linkedInUrl = 'https://www.linkedin.com/in/abuadnanshad/';
const String _gitHubUrl = 'https://github.com/adnanshad35';

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

  Future<void> _open(Uri uri, {required String fallbackMessage}) async {
    var opened = false;

    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    }
  }

  void _requestFeature() {
    _open(
      Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {'subject': 'HostelMate Feature Request'},
      ),
      fallbackMessage: 'No email application was found. '
          'Please email $_supportEmail.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ─── App ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: AppTheme.primary,
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
                    'HostelMate helps hostel members manage meals, '
                    'shared expenses, monthly meal rates, and '
                    'individual balances clearly. Every member can '
                    'view meal counts, expenses, calculations, and '
                    'final pay-or-collect amounts.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Developer ───
          Text(
            'Developer',
            style: textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 52,
                    backgroundColor: AppTheme.surfaceSoft,
                    backgroundImage: AssetImage(
                      'assets/images/developer.jpg',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Abu Adnan Shad',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Computer Science & Engineering graduate\n'
                    'Flutter and Firebase developer',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        icon: FontAwesomeIcons.linkedinIn,
                        tooltip: 'LinkedIn',
                        color: const Color(0xFF0A66C2),
                        onPressed: () => _open(
                          Uri.parse(_linkedInUrl),
                          fallbackMessage: 'Unable to open LinkedIn.',
                        ),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        icon: FontAwesomeIcons.github,
                        tooltip: 'GitHub',
                        color: const Color(0xFF181717),
                        onPressed: () => _open(
                          Uri.parse(_gitHubUrl),
                          fallbackMessage: 'Unable to open GitHub.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Feedback ───
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: _requestFeature,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2DA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.warning,
                ),
              ),
              title: const Text(
                'Request a Feature',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('Share an idea or improvement'),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        fixedSize: const Size(52, 52),
      ),
      icon: FaIcon(icon, size: 22),
    );
  }
}
