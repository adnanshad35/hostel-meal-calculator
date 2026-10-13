import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'web_layout.dart';

/// One entry in a [DesktopScaffold]'s sidebar.
class DesktopDestination {
  const DesktopDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The wide-window layout shared by the hostel and the super admin
/// panel: a sidebar on the left and a content panel beside it.
///
/// While it is on screen it claims the whole browser window, so the
/// app is not confined to the phone-width column.
class DesktopScaffold extends StatefulWidget {
  const DesktopScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.content,
    this.headerAction,
    this.actions,
    this.contentWidth = 860,
  });

  /// Shown under the app name, for example the hostel's name.
  final String title;
  final String subtitle;

  final List<DesktopDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// The screen for the selected destination.
  final Widget content;

  /// A small widget beside the app name, such as a notices bell.
  final Widget? headerAction;

  /// Buttons shown above the destinations.
  final Widget? actions;

  final double contentWidth;

  @override
  State<DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<DesktopScaffold> {
  @override
  void initState() {
    super.initState();
    WebLayout.claimWindow();
  }

  @override
  void dispose() {
    WebLayout.releaseWindow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE9EFEB),
      body: Row(
        children: [
          _Sidebar(scaffold: widget),
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: widget.contentWidth),
                margin: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDDE5E0)),
                ),
                // Screens measure themselves against the content area,
                // not the whole window.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return MediaQuery(
                      data: media.copyWith(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                      ),
                      child: widget.content,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.scaffold});

  final DesktopScaffold scaffold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B3D2C), Color(0xFF0A2F22)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 12, 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'HostelMate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (scaffold.headerAction != null)
                    IconTheme(
                      data: const IconThemeData(color: Colors.white),
                      child: scaffold.headerAction!,
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scaffold.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    scaffold.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (scaffold.actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: scaffold.actions,
              )
            else
              const SizedBox(height: 14),
            Divider(
              height: 16,
              indent: 22,
              endIndent: 22,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (
                    var index = 0;
                    index < scaffold.destinations.length;
                    index++
                  )
                    _NavItem(
                      destination: scaffold.destinations[index],
                      isSelected: index == scaffold.selectedIndex,
                      onTap: () => scaffold.onSelect(index),
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

/// A translucent button for the sidebar's action row.
class DesktopSidebarButton extends StatelessWidget {
  const DesktopSidebarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final DesktopDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(destination.icon, size: 21, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
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
}
