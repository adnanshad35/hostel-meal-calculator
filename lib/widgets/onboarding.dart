import 'package:flutter/material.dart';

import '../services/account_rules.dart';
import '../theme/app_theme.dart';

/// The HostelMate logo, as on the phone's home screen.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.onDark = false});

  final double size;

  /// On a green background: a light ring keeps the green logo clear.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: onDark ? const EdgeInsets.all(3) : null,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.9) : null,
        borderRadius: BorderRadius.circular(size * 0.24 + (onDark ? 3 : 0)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// The top of each sign-in page: the logo, a title and one short line.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const BrandMark(size: 64),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// The password rules as chips that turn green as each one is met.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final check in AccountRules.passwordChecks(password))
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
            decoration: BoxDecoration(
              color: check.isMet ? AppTheme.surfaceSoft : AppTheme.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: check.isMet
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : const Color(0xFFDDE4E0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  check.isMet
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: check.isMet
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  check.label,
                  style: TextStyle(
                    color: check.isMet
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A gentle full-page loader with the logo, while the app starts.
class BrandLoader extends StatelessWidget {
  const BrandLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 84),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
