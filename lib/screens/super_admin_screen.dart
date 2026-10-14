import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/subscription_service.dart';
import '../services/super_admin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_scaffold.dart';
import '../widgets/web_layout.dart';
import 'hostel_activation_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'super_admin_billing.dart';
import 'super_admin_requests.dart';

typedef _AdminData = ({AdminSnapshot data, AdminBilling billing});

/// App-wide administration: every user and hostel, hostel activation
/// (vouchers and payments), and app notices. Only the super admin
/// account can open or load it.
class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  static const _tabs = [
    DesktopDestination(label: 'Overview', icon: Icons.dashboard_outlined),
    DesktopDestination(label: 'Users', icon: Icons.people_outline),
    DesktopDestination(label: 'Hostels', icon: Icons.apartment_outlined),
    DesktopDestination(label: 'Payments', icon: Icons.payments_outlined),
    DesktopDestination(
      label: 'Vouchers',
      icon: Icons.confirmation_number_outlined,
    ),
    DesktopDestination(
      label: 'Requests',
      icon: Icons.lightbulb_outline_rounded,
    ),
  ];

  /// The sidebar on a wide window: the tabs, then the two screens the
  /// phone opens from the app bar and the overview.
  static const _destinations = [
    ..._tabs,
    DesktopDestination(label: 'App Notices', icon: Icons.campaign_outlined),
    DesktopDestination(label: 'Profile', icon: Icons.account_circle_outlined),
  ];

  static const _noticesIndex = 6;

  /// A notifier, so the screens inside the desktop layout's own
  /// navigator also see a refresh.
  late final ValueNotifier<Future<_AdminData>> _snapshot;

  bool _isDesktop = false;
  int _section = 0;

  /// Increased to rebuild a section from its first screen when its
  /// sidebar item is chosen again.
  int _visit = 0;

  @override
  void initState() {
    super.initState();
    _snapshot = ValueNotifier(_load());
  }

  @override
  void dispose() {
    _snapshot.dispose();
    super.dispose();
  }

  static Future<_AdminData> _load() async {
    return (
      data: await SuperAdminService.load(),
      billing: await AdminBilling.load(),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    _snapshot.value = next;

    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  void _openProfile() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  void _openNotices() {
    if (_isDesktop) {
      _select(_noticesIndex);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(groupId: null),
      ),
    );
  }

  void _select(int index) {
    setState(() {
      _section = index;
      _visit++;
    });
  }

  Widget _tab(int index, _AdminData loaded) {
    final data = loaded.data;
    final billing = loaded.billing;

    return switch (index) {
      0 => _OverviewTab(
        data: data,
        billing: billing,
        onRefresh: _refresh,
        onOpenNotices: _openNotices,
      ),
      1 => _UsersTab(data: data, onRefresh: _refresh),
      2 => _HostelsTab(data: data, billing: billing, onRefresh: _refresh),
      3 => AdminPaymentsTab(billing: billing, onRefresh: _refresh),
      4 => AdminVouchersTab(billing: billing, onRefresh: _refresh),
      // Loads its own list, so it is fresh each time it is opened.
      _ => const AdminRequestsTab(),
    };
  }

  /// Shows [builder]'s widget once the admin data has loaded, and a
  /// spinner or an error until then.
  Widget _whenLoaded(Widget Function(_AdminData loaded) builder) {
    return ValueListenableBuilder<Future<_AdminData>>(
      valueListenable: _snapshot,
      builder: (context, future, _) {
        return FutureBuilder<_AdminData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final loaded = snapshot.data;

            if (snapshot.hasError || loaded == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load the admin data. Check your '
                        'connection and that this is the super admin '
                        'account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return builder(loaded);
          },
        );
      },
    );
  }

  Widget _desktopPage(int index) {
    if (index == _noticesIndex) {
      return const NotificationsScreen(groupId: null);
    }

    if (index > _noticesIndex) return const ProfileScreen();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_tabs[index].label),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _whenLoaded((loaded) => _tab(index, loaded)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDesktop = WebLayout.isDesktopOf(context);

    if (_isDesktop) {
      final section = _section;

      return DesktopScaffold(
        title: 'Super Admin',
        subtitle: SuperAdminService.email,
        destinations: _destinations,
        selectedIndex: section,
        onSelect: _select,
        content: Navigator(
          key: ValueKey('$section-$_visit'),
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => _desktopPage(section),
            );
          },
        ),
      );
    }

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Super Admin'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Profile and settings',
              onPressed: _openProfile,
              icon: const Icon(Icons.account_circle_outlined, size: 28),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in _tabs) Tab(text: tab.label)],
          ),
        ),
        body: _whenLoaded((loaded) {
          return TabBarView(
            children: [
              for (var index = 0; index < _tabs.length; index++)
                _tab(index, loaded),
            ],
          );
        }),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown date';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

// ─────────────────────────────────────────────────────────────
// Overview
// ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.data,
    required this.billing,
    required this.onRefresh,
    required this.onOpenNotices,
  });

  final AdminSnapshot data;
  final AdminBilling billing;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenNotices;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_outline,
                  label: 'Total users',
                  value: '${data.users.length}',
                  color: AppTheme.primary,
                  background: const Color(0xFFE4F3EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.how_to_reg_outlined,
                  label: 'Users in hostels',
                  value: '${data.usersInHostels}',
                  color: const Color(0xFF7956A8),
                  background: const Color(0xFFF0E9F8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.apartment_outlined,
                  label: 'Hostels',
                  value: '${data.hostels.length}',
                  color: const Color(0xFF4869A4),
                  background: const Color(0xFFE8EEF8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.verified_outlined,
                  label: 'Active hostels',
                  // Counted over existing hostels, so a deleted hostel's
                  // leftover period is not included.
                  value:
                      '${data.hostels.where((hostel) => billing.subscriptionOf(hostel.id).canEdit(DateTime.now())).length}',
                  color: AppTheme.success,
                  background: const Color(0xFFE4F3EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.payments_outlined,
                  label: 'Payments waiting',
                  value: '${billing.pendingPayments}',
                  color: AppTheme.danger,
                  background: const Color(0xFFFCE8E8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'New this week',
                  value: '${data.newUsers(DateTime.now())}',
                  color: const Color(0xFFD78116),
                  background: const Color(0xFFFFF1DB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AdminMaintenanceCard(config: billing.appConfig, onRefresh: onRefresh),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: onOpenNotices,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const Icon(
                Icons.campaign_outlined,
                color: AppTheme.warning,
                size: 30,
              ),
              title: const Text(
                'App Notices',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Send a notice to every user of the app'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pull down or tap refresh to load the latest data.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
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

// ─────────────────────────────────────────────────────────────
// Search field shared by the Users and Hostels tabs
// ─────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Users
// ─────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.data, required this.onRefresh});

  final AdminSnapshot data;
  final Future<void> Function() onRefresh;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  bool _oldestFirst = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final users = widget.data.searchUsers(
      _searchController.text,
      oldestFirst: _oldestFirst,
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        // Search, the count and sort row, then the users.
        itemCount: users.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SearchField(
              controller: _searchController,
              hint: 'Search name, email, phone or hostel',
              onChanged: (_) => setState(() {}),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      users.length == 1 ? '1 user' : '${users.length} users',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _oldestFirst = !_oldestFirst);
                    },
                    icon: Icon(
                      _oldestFirst ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 18,
                    ),
                    label: Text(_oldestFirst ? 'Oldest first' : 'Newest first'),
                  ),
                ],
              ),
            );
          }

          final user = users[index - 2];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _UserRow(
              key: ValueKey(user.id),
              data: widget.data,
              user: user,
            ),
          );
        },
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({super.key, required this.data, required this.user});

  final AdminSnapshot data;
  final AdminUser user;

  void _showDetails(BuildContext context) {
    final hostel = data.hostelOf(user);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: user.email,
                  canCopy: true,
                ),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: user.phone,
                  canCopy: true,
                ),
                _DetailRow(
                  icon: Icons.apartment_outlined,
                  label: 'Hostel',
                  value:
                      hostel?.name ??
                      (user.groupId == null ? '' : 'Unknown hostel'),
                  emptyText: 'Not in a hostel',
                ),
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Position',
                  value: user.groupId == null
                      ? ''
                      : user.isHostelAdmin
                      ? 'Hostel administrator'
                      : 'Member',
                  emptyText: 'None',
                ),
                _DetailRow(
                  icon: Icons.event_outlined,
                  label: 'Joined',
                  value: _formatDate(user.createdAt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostel = data.hostelOf(user);
    final contact = user.email.isNotEmpty ? user.email : user.phone;
    final place =
        hostel?.name ??
        (user.groupId == null ? 'Not in a hostel' : 'Unknown hostel');

    // The super admin's own account stands out from everyone else's.
    final isSuperAdmin = user.email.toLowerCase() == SuperAdminService.email;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSuperAdmin ? const Color(0xFFFFF6DF) : null,
      shape: isSuperAdmin
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.secondary, width: 1.4),
            )
          : null,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Name on the left, with the admin tag when it applies.
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isSuperAdmin)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: _Chip(
                          text: 'Super Admin',
                          icon: Icons.shield_outlined,
                          color: Color(0xFF9A6A00),
                        ),
                      ),
                    if (user.isHostelAdmin)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: _Chip(text: 'Admin'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Email over hostel on the right.
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.isEmpty ? 'No email' : contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hostel == null
                            ? AppTheme.textSecondary
                            : AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hostels
// ─────────────────────────────────────────────────────────────
class _HostelsTab extends StatefulWidget {
  const _HostelsTab({
    required this.data,
    required this.billing,
    required this.onRefresh,
  });

  final AdminSnapshot data;
  final AdminBilling billing;
  final Future<void> Function() onRefresh;

  @override
  State<_HostelsTab> createState() => _HostelsTabState();
}

class _HostelsTabState extends State<_HostelsTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addDays(AdminHostel hostel) async {
    final days = await askForDays(
      context,
      title: 'Add Days',
      message:
          'Activate or extend ${hostel.name} without a voucher '
          'or payment.',
    );

    if (days == null || !mounted) return;

    await runAdminAction(
      context,
      action: () =>
          SubscriptionService.grantDays(groupId: hostel.id, days: days),
      successMessage: '$days days were added to ${hostel.name}.',
      onDone: widget.onRefresh,
    );
  }

  Future<void> _setDaysLeft(AdminHostel hostel) async {
    final current = widget.billing
        .subscriptionOf(hostel.id)
        .daysLeft(DateTime.now());

    final days = await askForDays(
      context,
      title: 'Set Days Left',
      message:
          '${hostel.name} has $current days left. Enter the new '
          'number, counted from today. Use 0 to end its period now.',
      initialDays: current,
      label: 'Days left',
      confirmLabel: 'Save',
      allowZero: true,
    );

    if (days == null || !mounted) return;

    await runAdminAction(
      context,
      action: () =>
          SubscriptionService.setDaysLeft(groupId: hostel.id, days: days),
      successMessage: days == 0
          ? 'The period of ${hostel.name} has ended.'
          : '${hostel.name} now has $days days left.',
      onDone: widget.onRefresh,
    );
  }

  Future<void> _deleteHostel(AdminHostel hostel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteHostelDialog(
        hostel: hostel,
        userCount: widget.data.membersOf(hostel).length,
      ),
    );

    if (confirmed != true || !mounted) return;

    await runAdminAction(
      context,
      action: () => SuperAdminService.deleteHostel(hostel),
      successMessage: '${hostel.name} was deleted.',
      onDone: widget.onRefresh,
    );
  }

  Future<void> _setControl(
    AdminHostel hostel, {
    bool? allowEditing,
    bool? allowAccess,
  }) {
    final String message;

    if (allowAccess != null) {
      message = allowAccess
          ? '${hostel.name} is open to its members again.'
          : '${hostel.name} is suspended.';
    } else {
      message = allowEditing == true
          ? 'Editing is allowed again in ${hostel.name}.'
          : '${hostel.name} is now read-only.';
    }

    return runAdminAction(
      context,
      action: () => SubscriptionService.setHostelControls(
        hostel.id,
        editingDisabled: allowEditing == null ? null : !allowEditing,
        accessDisabled: allowAccess == null ? null : !allowAccess,
      ),
      successMessage: message,
      onDone: widget.onRefresh,
    );
  }

  /// One line describing a hostel's state, and its colour.
  static (String, Color) _statusOf(HostelSubscription subscription) {
    final now = DateTime.now();
    final daysLeft = subscription.daysLeft(now);

    if (subscription.accessDisabled) {
      return ('Suspended', AppTheme.danger);
    }
    if (subscription.editingDisabled) {
      return ('Read-only · editing off', AppTheme.warning);
    }
    if (subscription.isActive(now)) {
      return (
        'Active · ${daysLeft == 1 ? '1 day' : '$daysLeft days'} left',
        AppTheme.success,
      );
    }
    return ('Read-only · not active', AppTheme.warning);
  }

  void _showDetails(AdminHostel hostel) {
    final members = widget.data.membersOf(hostel);
    final subscription = widget.billing.subscriptionOf(hostel.id);
    final (status, statusColor) = _statusOf(subscription);
    final until = subscription.activeUntil;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;

        void close() => Navigator.of(sheetContext).pop();

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  hostel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  until == null || !subscription.isActive(DateTime.now())
                      ? status
                      : '$status · until ${formatSubscriptionDate(until)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          close();
                          _setDaysLeft(hostel);
                        },
                        child: const Text('Set Days'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          close();
                          _addDays(hostel);
                        },
                        child: const Text('Add Days'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _SwitchLine(
                  label: 'Allow editing',
                  value: !subscription.editingDisabled,
                  onChanged: (allow) {
                    close();
                    _setControl(hostel, allowEditing: allow);
                  },
                ),
                _SwitchLine(
                  label: 'Allow access',
                  value: !subscription.accessDisabled,
                  onChanged: (allow) {
                    close();
                    _setControl(hostel, allowAccess: allow);
                  },
                ),
                const Divider(height: 16),
                _InfoLine(
                  label: 'Invitation code',
                  value: hostel.inviteCode,
                  canCopy: true,
                ),
                _InfoLine(
                  label: 'Created',
                  value: _formatDate(hostel.createdAt),
                ),
                _InfoLine(label: 'App users', value: '${members.length}'),
                const Divider(height: 16),
                for (final member in members)
                  _MemberLine(
                    name: member.name,
                    email: member.email,
                    isAdmin: hostel.adminIds.contains(member.id),
                  ),
                if (members.isEmpty) const Text('No app users in this hostel.'),
                const Divider(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                  ),
                  onPressed: () {
                    close();
                    _deleteHostel(hostel);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Hostel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hostels = widget.data.searchHostels(_searchController.text);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: hostels.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SearchField(
              controller: _searchController,
              hint: 'Search hostel name',
              onChanged: (_) => setState(() {}),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                hostels.length == 1 ? '1 hostel' : '${hostels.length} hostels',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            );
          }

          final hostel = hostels[index - 2];
          final memberCount = hostel.memberIds.length;
          final (status, statusColor) = _statusOf(
            widget.billing.subscriptionOf(hostel.id),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: ValueKey(hostel.id),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showDetails(hostel),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hostel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        memberCount == 1 ? '1 user' : '$memberCount users',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Confirms deleting a hostel. The hostel's name has to be typed, so
/// it cannot be deleted by a stray tap.
class _DeleteHostelDialog extends StatefulWidget {
  const _DeleteHostelDialog({required this.hostel, required this.userCount});

  final AdminHostel hostel;
  final int userCount;

  @override
  State<_DeleteHostelDialog> createState() => _DeleteHostelDialogState();
}

class _DeleteHostelDialogState extends State<_DeleteHostelDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _nameMatches {
    return _nameController.text.trim().toLowerCase() ==
        widget.hostel.name.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.userCount;

    return AlertDialog(
      title: const Text('Delete Hostel?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This deletes ${widget.hostel.name} and all of its meals, '
              'expenses, monthly settings and members. It cannot be '
              'undone.',
            ),
            const SizedBox(height: 10),
            Text(
              users == 0
                  ? 'No app users are in this hostel.'
                  : users == 1
                  ? 'Its 1 user keeps their account and will no longer '
                        'be in a hostel.'
                  : 'Its $users users keep their accounts and will no '
                        'longer be in a hostel.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Type the hostel name to confirm',
                hintText: widget.hostel.name,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: _nameMatches
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// A label with a switch, on one line.
class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A label and its value, on one line.
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.canCopy = false,
  });

  final String label;
  final String value;
  final bool canCopy;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await Clipboard.setData(ClipboardData(text: value));
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasValue ? value : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canCopy && hasValue)
            IconButton(
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
        ],
      ),
    );
  }
}

/// One member of a hostel: name, email, and an admin tag, on one line.
class _MemberLine extends StatelessWidget {
  const _MemberLine({
    required this.name,
    required this.email,
    required this.isAdmin,
  });

  final String name;
  final String email;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            const _Chip(text: 'Admin'),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small shared pieces
// ─────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.icon, this.color = AppTheme.primary});

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emptyText = 'Not provided',
    this.canCopy = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String emptyText;
  final bool canCopy;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await Clipboard.setData(ClipboardData(text: value));
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  hasValue ? value : emptyText,
                  style: TextStyle(
                    color: hasValue
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canCopy && hasValue)
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_outlined, size: 20),
            ),
        ],
      ),
    );
  }
}
