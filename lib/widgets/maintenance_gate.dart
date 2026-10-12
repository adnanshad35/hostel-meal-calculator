import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/subscription_service.dart';
import '../services/super_admin_service.dart';
import '../theme/app_theme.dart';

/// Shows [child] unless the super admin has switched maintenance mode
/// on, in which case everyone else sees a maintenance screen. The
/// super admin keeps full access so the app can be checked meanwhile.
class MaintenanceGate extends StatefulWidget {
  const MaintenanceGate({super.key, required this.child});

  final Widget child;

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  late final Stream<AppConfig> _config;

  @override
  void initState() {
    super.initState();
    _config = SubscriptionService.watchAppConfig();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: _config,
      builder: (context, snapshot) {
        final config = snapshot.data;

        // While loading, or if the setting cannot be read, the app
        // simply opens.
        if (config == null ||
            !config.maintenance ||
            SuperAdminService.isSuperAdmin) {
          return widget.child;
        }

        return MaintenanceScreen(message: config.maintenanceMessage);
      },
    );
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    size: 50,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Under maintenance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  message.isEmpty
                      ? 'HostelMate is being updated. Please check '
                          'back in a little while.'
                      : message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
