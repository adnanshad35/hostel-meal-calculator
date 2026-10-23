import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A green icon on a soft square, the way every row of the app starts.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.isDanger = false});

  final IconData icon;

  /// Red, for a row that deletes something.
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDanger
            ? AppTheme.danger.withValues(alpha: 0.1)
            : AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: isDanger ? AppTheme.danger : AppTheme.primary,
        size: 22,
      ),
    );
  }
}

/// The title of a row, in the weight and size every row uses.
class TileTitle extends StatelessWidget {
  const TileTitle(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? AppTheme.textPrimary,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The arrow at the end of a row that opens a page.
class TileArrow extends StatelessWidget {
  const TileArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.arrow_forward_rounded,
      size: 19,
      color: AppTheme.textSecondary,
    );
  }
}

/// One row on its own card that opens a page.
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  /// Replaces the arrow, such as with a progress mark.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 16, 4),
        leading: IconBadge(icon),
        title: TileTitle(title),
        trailing: trailing ?? const TileArrow(),
      ),
    );
  }
}

/// Rows that belong together, on one card under a short title.
class TileGroup extends StatelessWidget {
  const TileGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(
              title!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 70),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A row inside a [TileGroup] that opens a page or does something.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.enabled = true,
    this.isDanger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  /// Replaces the arrow, such as with a + or a progress mark.
  final Widget? trailing;
  final bool enabled;

  /// Red, for a row that deletes something.
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 16, 4),
      leading: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: IconBadge(icon, isDanger: isDanger),
      ),
      title: TileTitle(
        title,
        color: !enabled
            ? AppTheme.textSecondary
            : isDanger
            ? AppTheme.danger
            : null,
      ),
      trailing: trailing ?? const TileArrow(),
    );
  }
}

/// An on/off row inside a [TileGroup].
class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;

  /// Null while it cannot be changed.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    // A smaller switch than the default, so it sits evenly with the
    // arrows and icons of the rows around it.
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      leading: IconBadge(icon),
      title: TileTitle(title),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Transform.scale(
        scale: 0.78,
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// A small brass label for something that is on the way.
class ComingSoonLabel extends StatelessWidget {
  const ComingSoonLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Coming Soon',
        style: TextStyle(
          color: AppTheme.accentDeep,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
