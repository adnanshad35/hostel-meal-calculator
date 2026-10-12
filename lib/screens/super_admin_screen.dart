import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/subscription_service.dart';
import '../services/super_admin_service.dart';
import '../theme/app_theme.dart';
import 'hostel_activation_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'super_admin_billing.dart';

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
  late Future<_AdminData> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  static Future<_AdminData> _load() async {
    return (
      data: await SuperAdminService.load(),
      billing: await AdminBilling.load(),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    // A block body, because setState must not be handed the future.
    setState(() {
      _snapshot = next;
    });

    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openNotices() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(groupId: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
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
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Users'),
              Tab(text: 'Hostels'),
              Tab(text: 'Payments'),
              Tab(text: 'Vouchers'),
            ],
          ),
        ),
        body: FutureBuilder<_AdminData>(
          future: _snapshot,
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

            final data = loaded.data;
            final billing = loaded.billing;

            return TabBarView(
              children: [
                _OverviewTab(
                  data: data,
                  billing: billing,
                  onRefresh: _refresh,
                  onOpenNotices: _openNotices,
                ),
                _UsersTab(data: data, onRefresh: _refresh),
                _HostelsTab(
                  data: data,
                  billing: billing,
                  onRefresh: _refresh,
                ),
                AdminPaymentsTab(billing: billing, onRefresh: _refresh),
                AdminVouchersTab(billing: billing, onRefresh: _refresh),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown date';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
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
                  icon: Icons.apartment_outlined,
                  label: 'Hostels',
                  value: '${data.hostels.length}',
                  color: const Color(0xFF4869A4),
                  background: const Color(0xFFE8EEF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.payments_outlined,
                  label: 'Payments waiting',
                  value: '${billing.pendingPayments}',
                  color: AppTheme.danger,
                  background: const Color(0xFFFCE8E8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AdminMaintenanceCard(
            config: billing.appConfig,
            onRefresh: onRefresh,
          ),
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
              subtitle: const Text(
                'Send a notice to every user of the app',
              ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
            ),
            Text(label),
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
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
        // Search, the count and sort row, the column titles, the users.
        itemCount: users.length + 3,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _SearchField(
                controller: _searchController,
                hint: 'Search name, email, phone or hostel',
                onChanged: (_) => setState(() {}),
              ),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      users.length == 1 ? '1 user' : '${users.length} users',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _oldestFirst = !_oldestFirst);
                    },
                    icon: Icon(
                      _oldestFirst
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                    ),
                    label: Text(
                      _oldestFirst ? 'Oldest first' : 'Newest first',
                    ),
                  ),
                ],
              ),
            );
          }

          if (index == 2) {
            return const _UserRowLayout(
              isHeader: true,
              name: 'Name',
              email: 'Email',
              hostel: 'Hostel',
            );
          }

          final user = users[index - 3];

          return _UserRow(
            key: ValueKey(user.id),
            data: widget.data,
            user: user,
          );
        },
      ),
    );
  }
}

/// The three columns of the user list: name, email, hostel.
class _UserRowLayout extends StatelessWidget {
  const _UserRowLayout({
    required this.name,
    required this.email,
    required this.hostel,
    this.isHeader = false,
    this.isAdmin = false,
  });

  final String name;
  final String email;
  final String hostel;
  final bool isHeader;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isHeader ? 12 : 13,
      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
      color: isHeader ? AppTheme.textSecondary : AppTheme.textPrimary,
    );

    Widget cell(String text, int flex, {TextStyle? textStyle}) {
      return Expanded(
        flex: flex,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle ?? style,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5EAE7)),
        ),
      ),
      child: Row(
        children: [
          cell(
            name,
            5,
            textStyle: isHeader
                ? style
                : style.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isAdmin ? AppTheme.primary : null,
                  ),
          ),
          const SizedBox(width: 8),
          cell(email, 7),
          const SizedBox(width: 8),
          cell(hostel, 5),
        ],
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
                  value: hostel?.name ??
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

    return InkWell(
      onTap: () => _showDetails(context),
      child: _UserRowLayout(
        name: user.name,
        email: user.email.isNotEmpty ? user.email : user.phone,
        hostel: hostel?.name ?? (user.groupId == null ? '—' : 'Unknown'),
        // Hostel admins are shown in green.
        isAdmin: user.isHostelAdmin,
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
      message: 'Activate or extend ${hostel.name} without a voucher '
          'or payment.',
    );

    if (days == null || !mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.grantDays(
        groupId: hostel.id,
        days: days,
      ),
      successMessage: '$days days were added to ${hostel.name}.',
      onDone: widget.onRefresh,
    );
  }

  Future<void> _setDaysLeft(AdminHostel hostel) async {
    final current =
        widget.billing.subscriptionOf(hostel.id).daysLeft(DateTime.now());

    final days = await askForDays(
      context,
      title: 'Set Days Left',
      message: '${hostel.name} has $current days left. Enter the new '
          'number, counted from today. Use 0 to end its period now.',
      initialDays: current,
      label: 'Days left',
      confirmLabel: 'Save',
      allowZero: true,
    );

    if (days == null || !mounted) return;

    await runAdminAction(
      context,
      action: () => SubscriptionService.setDaysLeft(
        groupId: hostel.id,
        days: days,
      ),
      successMessage: days == 0
          ? 'The period of ${hostel.name} has ended.'
          : '${hostel.name} now has $days days left.',
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

  void _showDetails(AdminHostel hostel) {
    final members = widget.data.membersOf(hostel);
    final subscription = widget.billing.subscriptionOf(hostel.id);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  hostel.name,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SubscriptionStatusCard(subscription: subscription),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _setDaysLeft(hostel);
                        },
                        child: const Text('Set Days Left'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _addDays(hostel);
                        },
                        child: const Text('Add Days'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AdminHostelControls(
                  subscription: subscription,
                  onEditingChanged: (allow) {
                    Navigator.of(sheetContext).pop();
                    _setControl(hostel, allowEditing: allow);
                  },
                  onAccessChanged: (allow) {
                    Navigator.of(sheetContext).pop();
                    _setControl(hostel, allowAccess: allow);
                  },
                ),
                const Divider(height: 20),
                _DetailRow(
                  icon: Icons.event_outlined,
                  label: 'Created',
                  value: _formatDate(hostel.createdAt),
                ),
                _DetailRow(
                  icon: Icons.key_outlined,
                  label: 'Invitation code',
                  value: hostel.inviteCode,
                  canCopy: true,
                ),
                const SizedBox(height: 12),
                Text(
                  members.length == 1
                      ? '1 app user'
                      : '${members.length} app users',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text('Members without the app are not listed here.'),
                const SizedBox(height: 8),
                for (final member in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Avatar(text: _initials(member.name)),
                    title: Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        member.email.isEmpty ? null : Text(member.email),
                    trailing: hostel.adminIds.contains(member.id)
                        ? const _Chip(text: 'Admin')
                        : null,
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
                hostels.length == 1
                    ? '1 hostel'
                    : '${hostels.length} hostels',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            );
          }

          final hostel = hostels[index - 2];
          final memberCount = hostel.memberIds.length;
          final now = DateTime.now();
          final subscription = widget.billing.subscriptionOf(hostel.id);
          final daysLeft = subscription.daysLeft(now);
          final status = subscription.accessDisabled
              ? 'Suspended'
              : subscription.editingDisabled
                  ? 'Read-only · editing switched off'
                  : subscription.isActive(now)
                      ? 'Active · '
                          '${daysLeft == 1 ? '1 day' : '$daysLeft days'} left'
                      : 'Read-only · not active';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              key: ValueKey(hostel.id),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => _showDetails(hostel),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: const _Avatar(icon: Icons.apartment_outlined),
                title: Text(
                  hostel.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '$status\n'
                    '${memberCount == 1 ? '1 app user' : '$memberCount app users'}'
                    ' • Created ${_formatDate(hostel.createdAt)}',
                  ),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small shared pieces
// ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({this.text, this.icon});

  final String? text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: icon != null
          ? Icon(icon, color: AppTheme.primary)
          : Text(
              text ?? '',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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
