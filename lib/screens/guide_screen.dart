import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One part of the guide: a heading and the steps under it.
class GuideSection {
  const GuideSection({
    required this.icon,
    required this.title,
    required this.points,
    this.isAdminOnly = false,
  });

  final IconData icon;
  final String title;

  /// Each point is a short title and what to do.
  final List<(String, String)> points;

  /// Marks a part only hostel admins need.
  final bool isAdminOnly;
}

/// Everything the guide covers, in the order a new member meets it.
///
/// In the text, `{b:…}` is a button or a name in the app, shown in
/// green; `{g:…}` is a change, in gold; `{r:…}` is a deletion, in red.
/// The same colours mean the same things on the app's own pages.
const guideSections = [
  GuideSection(
    icon: Icons.rocket_launch_outlined,
    title: 'Getting Started',
    points: [
      (
        'Create an Account',
        'Sign up with your email and a password, then open the link we '
            'email you to verify it.',
      ),
      (
        'Create a Hostel',
        'Tap {b:Create Hostel} and enter its name. The name cannot be '
            'changed later. You become its admin and get a {b:Hostel Code} '
            'for your members.',
      ),
      (
        'Join a Hostel',
        'Ask your admin for the {b:Hostel Code} and enter it under '
            '{b:Join Hostel}. The admin must keep {b:Allow New Members} on.',
      ),
      (
        'Activate the Hostel',
        'An admin activates it from {b:Hostel Details → Activation}, with '
            'a voucher or bKash.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.home_outlined,
    title: 'Home',
    points: [
      (
        'Top Card',
        'Your hostel, who is on duty today, and the {b:Hostel Details} '
            'button.',
      ),
      ('Update', 'Tap {b:+} on Meals or Expenses to add one in a few seconds.'),
      (
        'Bell',
        'Announcements from your admins, notices from HostelMate, and when '
            'a member will be away.',
      ),
      (
        'Bottom Bar',
        '{b:Home}, {b:Meals}, {b:Expenses} and {b:Balance}, always one tap '
            'away.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.restaurant_outlined,
    title: 'Adding Meals',
    points: [
      (
        'Meal Entry',
        'Tap {b:+} on Meals in Home, pick the day, and set how many lunches '
            'and dinners you had, guests included.',
      ),
      (
        'Meal Plan',
        'In the same form, open {b:Meal Plan} and set what you usually eat '
            'from a date. Days you leave empty are counted from it.',
      ),
      (
        'Auto',
        'A day counted from your meal plan is marked {b:Auto}. Saving an '
            'entry for that day replaces it.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.calendar_month_outlined,
    title: 'Meals Page',
    points: [
      ('Month', 'Use the arrows to move between this month and last month.'),
      (
        'My Meals and Total Meals',
        'Tap {b:My Meals} for your month day by day, or {b:Total Meals} for '
            'each member\'s total.',
      ),
      (
        'Calendar',
        'Days with meals are shaded green. Tap a day to see its table. '
            'Days still to come are faded and cannot be picked.',
      ),
      (
        'Table',
        'Your row comes first. Tap a row with a pencil to change it: your '
            'own, or anyone\'s if you are an admin. A changed entry is '
            'marked {g:Edited}.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.receipt_long_outlined,
    title: 'Expenses',
    points: [
      (
        'Add an Expense',
        'Tap {b:+} on Expenses in Home and enter the item, the amount and '
            'the day. The calculator helps add up a long bazar list.',
      ),
      (
        'Paid By',
        'An expense counts for the member who paid. Admins can record one '
            'for any member.',
      ),
      (
        'Expenses Page',
        'Tap {b:My Expenses} for what you paid, or {b:Total Expenses} for '
            'each member. Tap a day to see its items.',
      ),
      (
        'Change or Delete',
        'Tap your own expense to change it; it is then marked {g:Edited}. '
            'Only admins can {r:delete} one, from the ⋮ menu.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Balance',
    points: [
      (
        'Meal Rate',
        'All expenses plus the shop due, divided by the meals charged.',
      ),
      (
        'Your Balance',
        'What you paid, minus your meals times the meal rate. A positive '
            'figure is what you get back; a negative one is what you pay.',
      ),
      (
        'Min Meals',
        'Every member is charged at least this many meals, even if they '
            'ate fewer.',
      ),
      (
        'Shop Due',
        'What the hostel still owes the shop. It is added to the month\'s '
            'cost.',
      ),
      (
        'Month Trend',
        'Compares this month with last month day by day. Switch between '
            '{b:Rate}, {b:Meals} and {b:Cost}, and tap or drag to pick a day.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.lock_clock_outlined,
    title: 'Month Lock',
    points: [
      (
        'Until the 7th',
        'A month\'s meals and expenses can be added or changed until the '
            '7th of the next month, by everyone, admins included.',
      ),
      (
        'Last Month',
        'After that, last month is closed: every detail stays visible, but '
            'nothing can be changed.',
      ),
      (
        'Older Months',
        'Only the summary is kept: meal rate, total meals, total expense '
            'and each member\'s figures.',
      ),
      (
        'Edited',
        'A meal or expense changed more than a minute after it was saved is '
            'marked {g:Edited}, whoever changed it.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.verified_user_outlined,
    title: 'Accountability',
    points: [
      (
        'Where',
        'Open {b:Hostel Details → Accountability}. A red dot shows when '
            'someone else changed something since you last looked.',
      ),
      (
        'What It Records',
        'Who did what and when, with the old and new figures, such as '
            '{g:Lunch 1 → 2}.',
      ),
      (
        'Colours',
        '{b:Added} is green, {g:changed} is gold, and {r:deleted} or '
            '{r:removed} is red.',
      ),
      (
        'Filters',
        '{b:Meals}, {b:Expenses}, {b:Admin} and {b:All}. Admin holds Min '
            'Meals, Shop Due, resets, members and activation.',
      ),
      (
        'Cannot Be Hidden',
        'No one, not even an admin, can change or delete a record.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.apartment_outlined,
    title: 'Hostel Details',
    points: [
      (
        'Activation',
        'Shows whether the hostel is active and for how long. Admins tap it '
            'to renew.',
      ),
      ('Hostel Code', 'Tap it to copy, then send it to a new member.'),
      (
        'Members',
        'Everyone in the hostel. {b:Admin} and {b:No App} tags show who is '
            'who.',
      ),
      (
        'Leave Hostel',
        'Your past meals and expenses stay in the hostel\'s records. The '
            'only admin must first make another member admin.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Admin Settings',
    isAdminOnly: true,
    points: [
      (
        'Members',
        '{b:Members} to make an admin or remove someone, {b:Allow New '
            'Members}, {b:Add Member Without App}, {b:Duty Roster} and '
            '{b:Send Announcement}.',
      ),
      (
        'Member Permissions',
        'Whether members can {b:Add Meals}, {b:Add Expenses}, and {b:Edit '
            'Their Entries} afterwards.',
      ),
      (
        'Month End',
        'Min Meals and Shop Due open from the 25th to the 5th of the next '
            'month. {b:Min Meals & Shop Due Any Day} opens them always.',
      ),
      (
        'Danger Zone',
        '{r:Reset This Month} deletes every meal and expense of the month. '
            'It cannot be undone, and it is recorded in Accountability.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.campaign_outlined,
    title: 'Announcements',
    points: [
      (
        'For Everyone',
        'The bell on Home lists announcements, notices from HostelMate, and '
            'who will be away.',
      ),
      (
        'For Admins',
        '{b:Send Announcement} in Admin Settings, or {b:Announce} in the '
            'bell\'s page, sends a message to every member.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.person_outline_rounded,
    title: 'Profile',
    points: [
      ('Nickname', 'The name your hostel sees for you.'),
      ('Change Password', 'We email you a link to set a new password.'),
      (
        'Check for Updates',
        'Shows a new version when there is one and installs it inside the '
            'app.',
      ),
      (
        'App and Developer',
        'What HostelMate is, the {b:Web Version}, the {b:Website}, the '
            'developer\'s contacts, and {b:Request a Feature}.',
      ),
    ],
  ),
];

/// How to use HostelMate, as one long page with a menu on top that
/// jumps to any part of it.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _scroll = ScrollController();
  final _keys = [for (final _ in guideSections) GlobalKey()];

  /// The part being read, shown in the menu.
  int _current = 0;
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the menu on the part at the top of the screen.
  void _onScroll() {
    var current = 0;
    for (var index = 0; index < _keys.length; index++) {
      final box = _keys[index].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;

      final viewport = context.findRenderObject() as RenderBox?;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top <= 160) current = index;
    }

    final showTop = _scroll.offset > 400;
    if (current != _current || showTop != _showTop) {
      setState(() {
        _current = current;
        _showTop = showTop;
      });
    }
  }

  void _jumpTo(int index) {
    final target = _keys[index].currentContext;
    if (target == null) return;

    setState(() => _current = index);
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HostelMate Guide')),
      floatingActionButton: _showTop
          ? FloatingActionButton.small(
              tooltip: 'Back to Top',
              onPressed: () => _scroll.animateTo(
                0,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
              ),
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _JumpMenu(current: _current, onSelected: _jumpTo),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuickStart(onOpen: _jumpTo),
                  const SizedBox(height: 16),
                  for (final (index, section) in guideSections.indexed) ...[
                    _SectionCard(
                      key: _keys[index],
                      number: index + 1,
                      section: section,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The menu that lists every part of the guide and jumps to one.
class _JumpMenu extends StatelessWidget {
  const _JumpMenu({required this.current, required this.onSelected});

  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE3E9E5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: current,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.primary),
          menuMaxHeight: 420,
          onChanged: (index) {
            if (index != null) onSelected(index);
          },
          items: [
            for (final (index, section) in guideSections.indexed)
              DropdownMenuItem(
                value: index,
                child: Row(
                  children: [
                    Icon(section.icon, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        section.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (section.isAdminOnly) ...[
                      const SizedBox(width: 8),
                      const _AdminTag(),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The app in three steps, each opening its part of the guide.
class _QuickStart extends StatelessWidget {
  const _QuickStart({required this.onOpen});

  /// Opens the part at this index.
  final ValueChanged<int> onOpen;

  static const _steps = [
    (Icons.group_add_outlined, 'Join or Create', 0),
    (Icons.edit_note_rounded, 'Add Meals & Expenses', 2),
    (Icons.account_balance_wallet_outlined, 'See Balance', 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          children: [
            const Text(
              'Quick Start',
              style: TextStyle(
                color: AppTheme.accentDeep,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, (icon, label, part)) in _steps.indexed) ...[
                  if (index > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  Expanded(
                    child: InkWell(
                      onTap: () => onOpen(part),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                icon,
                                size: 20,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One part of the guide: its number and title, then each point.
/// [text] with its marked words coloured: `{b:…}` green for a button
/// or a name in the app, `{g:…}` gold for a change, `{r:…}` red for a
/// deletion.
List<TextSpan> _marked(String text) {
  final spans = <TextSpan>[];
  var start = 0;

  for (final match in RegExp(r'\{([bgr]):([^}]*)\}').allMatches(text)) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
    }
    final color = switch (match.group(1)) {
      'g' => AppTheme.accentDeep,
      'r' => AppTheme.danger,
      _ => AppTheme.primary,
    };
    spans.add(
      TextSpan(
        text: match.group(2),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
    start = match.end;
  }

  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.number, required this.section});

  final int number;
  final GuideSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  // Brass for the part only admins need.
                  decoration: BoxDecoration(
                    color: section.isAdminOnly
                        ? AppTheme.accent.withValues(alpha: 0.22)
                        : AppTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    section.icon,
                    color: section.isAdminOnly
                        ? AppTheme.accentDeep
                        : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Part $number',
                        style: const TextStyle(
                          color: AppTheme.accentDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        section.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (section.isAdminOnly) const _AdminTag(),
              ],
            ),
            const SizedBox(height: 10),
            for (final (title, text) in section.points)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 4, right: 12),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: AppTheme.accent,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$title\n',
                              style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            ),
                            ..._marked(text),
                          ],
                        ),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
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

class _AdminTag extends StatelessWidget {
  const _AdminTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Admin',
        style: TextStyle(
          color: AppTheme.ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
