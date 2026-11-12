import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/super_admin_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/super_admin_service.dart';
import 'theme/app_theme.dart';
import 'widgets/maintenance_gate.dart';
import 'widgets/onboarding.dart';
import 'widgets/update_prompt.dart';
import 'widgets/verified_session.dart';
import 'widgets/web_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const HostelMealApp());
}

class HostelMealApp extends StatelessWidget {
  const HostelMealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HostelMate',
      theme: AppTheme.light,
      builder: (context, child) => WebFrame(child: child!),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BrandLoader();
        }

        if (snapshot.hasData && snapshot.data!.emailVerified) {
          // Keyed by account, so the token is checked again whenever a
          // different user signs in.
          return VerifiedSession(
            key: ValueKey(snapshot.data!.uid),
            // The super admin manages the app instead of using a hostel.
            child: SuperAdminService.isSuperAdmin
                ? const UpdatePrompt(child: SuperAdminScreen())
                : const UpdatePrompt(
                    child: MaintenanceGate(child: HomeScreen()),
                  ),
          );
        }

        if (snapshot.hasData) {
          return const VerifyEmailScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openRegisterScreen(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _openLoginScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onCreateAccount: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Brand: fills the screen above the buttons, and
                // scrolls on a short one ───
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight -
                                _actionsHeight -
                                MediaQuery.paddingOf(context).bottom)
                            .clamp(0, double.infinity),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.heroGradient,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandMark(size: 92, onDark: true),
                            const SizedBox(height: 22),
                            const Text(
                              'HostelMate',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Hostel meals and expenses, settled fairly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 34),
                            for (final (icon, title, line) in _features)
                              _Feature(icon: icon, title: title, line: line),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ─── Actions ───
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton(
                                  onPressed: () => _openRegisterScreen(context),
                                  child: const Text('Create New Account'),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => _openLoginScreen(context),
                                  child: const Text('Sign In'),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Free to start · Phone and browser',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// About the height of the buttons below the brand.
  static const double _actionsHeight = 190;

  static const _features = [
    (Icons.restaurant_outlined, 'Meals', 'Everyone adds their own, in seconds'),
    (
      Icons.receipt_long_outlined,
      'Expenses',
      'Every taka on record, for all to see',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Balance',
      'Who pays and who collects, worked out',
    ),
  ];
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.line});

  final IconData icon;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    line,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
