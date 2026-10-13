import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
import 'widgets/update_prompt.dart';
import 'widgets/verified_session.dart';

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
      builder: (context, child) => _WebFrame(child: child!),
      home: const AuthGate(),
    );
  }
}

/// In a browser on a wide screen, shows the app as a phone-width
/// column in the centre of the page. The screens were designed for
/// phones and would otherwise stretch edge to edge.
class _WebFrame extends StatelessWidget {
  const _WebFrame({required this.child});

  static const double _maxWidth = 520;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    if (!kIsWeb || media.size.width <= _maxWidth) return child;

    return ColoredBox(
      color: const Color(0xFFE3EBE6),
      child: Center(
        child: Container(
          width: _maxWidth,
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 40,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRect(
            // Screens measure themselves against this width, not the
            // browser window's.
            child: MediaQuery(
              data: media.copyWith(size: Size(_maxWidth, media.size.height)),
              child: child,
            ),
          ),
        ),
      ),
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - 120,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 54,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'HostelMate',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 14),
                Text(
                  'A clear and simple way to manage '
                  'shared meals, expenses, and monthly balances.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 44),
                FilledButton(
                  onPressed: () => _openLoginScreen(context),
                  child: const Text('Sign In'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _openRegisterScreen(context),
                  child: const Text('Create New Account'),
                ),
                const SizedBox(height: 28),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 17,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Securely powered by Firebase',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
