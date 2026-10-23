import 'package:flutter/material.dart';

import '../services/month_archive.dart';
import '../theme/app_theme.dart';

/// One line in the details of a day: an entry, or a member's meals.
class CalendarLine {
  const CalendarLine({
    required this.title,
    required this.trailing,
    this.values,
    this.note,
    this.isStrong = false,
    this.isHeader = false,
    this.onTap,
    this.action,
  });

  final String title;

  /// A short tag after the title, such as who paid.
  final String? note;
  final String trailing;

  /// Figures in fixed columns at the end of the line, such as lunch and
  /// dinner. Replaces [trailing] when given, so the columns line up.
  final List<String>? values;

  /// Bold, for a total.
  final bool isStrong;

  /// A column title row, such as Lunch and Dinner.
  final bool isHeader;
  final VoidCallback? onTap;

  /// A small control at the end of the line, such as a menu.
  final Widget? action;
}

/// A month of records as a calendar: one figure for the month on top,
/// the days that have an entry picked out in colour, and underneath a
/// small card for each day, from the 1st up to today. Tapping a day in
/// the calendar brings its card into view.
class MonthCalendarView extends StatefulWidget {
  const MonthCalendarView({
    super.key,
    required this.month,
    required this.label,
    required this.total,
    required this.markedDays,
    required this.linesOf,
    this.shortLinesOf,
    this.emptyText = 'No entry',
    this.showMonthOption = false,
    this.newestFirst = false,
    this.belowCalendar,
    this.onTotalTap,
    this.onPreviousMonth,
    this.onNextMonth,
  });

  /// Step to the month before or after. With either given, arrows sit
  /// beside the month's name; a null one shows its arrow faded.
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  /// Makes the month's figure on top open something, such as each
  /// member's share of it.
  final VoidCallback? onTotalTap;

  /// When true, a switch under the calendar picks between the details
  /// of the selected day (the default) and the month, with one short
  /// line per day. Off, every day's card is listed below the calendar.
  final bool showMonthOption;

  /// Lists the day cards from the latest day down to the 1st.
  final bool newestFirst;

  /// Something to show right under the calendar, such as a link to
  /// another view of the month.
  final Widget? belowCalendar;

  /// Any date in the month to show.
  final DateTime month;

  /// What the figure is, such as "My meals".
  final String label;
  final String total;

  /// Days of the month that have an entry.
  final Set<int> markedDays;

  /// The details of one day of the month.
  final List<CalendarLine> Function(int day) linesOf;

  /// A shorter version of a day's details, such as just its total, for
  /// the cards of the days not picked. Without it every card shows the
  /// full details.
  final List<CalendarLine> Function(int day)? shortLinesOf;

  /// Shown for a day with nothing to list.
  final String emptyText;

  @override
  State<MonthCalendarView> createState() => _MonthCalendarViewState();
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

enum _ListMode { selectedDay, thisMonth }

/// How far back the month arrows go: last month is the only earlier
/// one whose meals and expenses are kept.
const monthsOfHistory = 1;

/// The month [delta] months from [month], or null when that is after
/// the current month or more than [monthsOfHistory] months back.
DateTime? shiftMonth(DateTime month, int delta) {
  final now = DateTime.now();
  final current = DateTime(now.year, now.month);
  final target = DateTime(month.year, month.month + delta);
  final earliest = DateTime(now.year, now.month - monthsOfHistory);

  if (target.isAfter(current) || target.isBefore(earliest)) return null;
  return target;
}

/// True when [month] is the month we are in now.
bool isCurrentMonth(DateTime month) {
  final now = DateTime.now();
  return month.year == now.year && month.month == now.month;
}

/// True while [month]'s meals and expenses may still be changed.
bool isEditableMonth(DateTime month) {
  return MonthLock.canEdit(month, DateTime.now());
}

class _MonthCalendarViewState extends State<MonthCalendarView> {
  late final DateTime _today = DateTime.now();
  late int _selectedDay;
  _ListMode _mode = _ListMode.selectedDay;

  /// One key per day card, to scroll to it.
  final Map<int, GlobalKey> _dayKeys = {};

  bool get _isCurrentMonth =>
      _today.year == widget.month.year && _today.month == widget.month.month;

  @override
  void initState() {
    super.initState();
    // Today, or the last day of an earlier month.
    _selectedDay = _isCurrentMonth
        ? _today.day
        : DateTime(widget.month.year, widget.month.month + 1, 0).day;
  }

  /// A small round arrow for stepping between months.
  Widget _monthArrow(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Material(
        color: AppTheme.surfaceSoft,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            size: 21,
            color: onTap == null
                ? AppTheme.textSecondary.withValues(alpha: 0.35)
                : AppTheme.primary,
          ),
        ),
      ),
    );
  }

  /// A date as "14 Oct, Wed".
  String _dateText(DateTime date) {
    return '${date.day} ${_monthNames[date.month - 1].substring(0, 3)}, '
        '${_dayNames[date.weekday - 1]}';
  }

  void _select(int day) {
    setState(() => _selectedDay = day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _dayKeys[day]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Past to present: the 1st up to today, or the whole of an earlier
    // month. A later day appears too once it is picked.
    final lastDay = _isCurrentMonth ? _today.day : daysInMonth;
    final monthView = widget.showMonthOption && _mode == _ListMode.thisMonth;

    // Which cards are listed. Off, the days with something to show.
    // Selected Day, only the picked day. This Month, every day with
    // something to show, and the picked day even when it is empty.
    bool listed(int day) {
      if (!widget.showMonthOption) {
        return _linesFor(day, false).isNotEmpty;
      }
      if (!monthView) return day == _selectedDay;

      return day == _selectedDay || _linesFor(day, true).isNotEmpty;
    }

    final oldestFirst = [
      for (var day = 1; day <= lastDay; day++)
        if (listed(day)) day,
      if (_selectedDay > lastDay && listed(_selectedDay)) _selectedDay,
    ];
    final days = widget.newestFirst
        ? oldestFirst.reversed.toList()
        : oldestFirst;
    final hasMonthNav =
        widget.onPreviousMonth != null || widget.onNextMonth != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTotalTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                widget.onTotalTap == null ? 18 : 10,
                16,
              ),
              child: Row(
                children: [
                  if (hasMonthNav) ...[
                    _monthArrow(
                      Icons.chevron_left_rounded,
                      widget.onPreviousMonth,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shrinks on a narrow phone rather than wrap.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_monthNames[month.month - 1]} ${month.year}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_isCurrentMonth) ...[
                          const SizedBox(height: 2),
                          Text(
                            _dateText(_today),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasMonthNav) ...[
                    const SizedBox(width: 8),
                    _monthArrow(
                      Icons.chevron_right_rounded,
                      widget.onNextMonth,
                    ),
                  ],
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.total,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                  if (widget.onTotalTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: _grid(),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.belowCalendar != null) ...[
          widget.belowCalendar!,
          const SizedBox(height: 12),
        ],
        if (widget.showMonthOption) ...[
          SegmentedButton<_ListMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _ListMode.selectedDay,
                label: Text('Selected Day'),
              ),
              ButtonSegment(
                value: _ListMode.thisMonth,
                label: Text('This Month'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 2),
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(widget.emptyText, textAlign: TextAlign.center),
          )
        else
          for (final day in days)
            Padding(
              key: _dayKeys.putIfAbsent(day, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: 8),
              child: _DayCard(
                date: _dateText(DateTime(month.year, month.month, day)),
                lines: day == _selectedDay || widget.shortLinesOf == null
                    ? widget.linesOf(day)
                    : widget.shortLinesOf!(day),
                emptyText: widget.emptyText,
                isSelected: day == _selectedDay,
                onTap: day == _selectedDay ? null : () => _select(day),
              ),
            ),
      ],
    );
  }

  /// The lines of a day: the short ones for the month view, when given.
  List<CalendarLine> _linesFor(int day, bool monthView) {
    if (monthView && widget.shortLinesOf != null) {
      return widget.shortLinesOf!(day);
    }

    return widget.linesOf(day);
  }

  Widget _grid() {
    final month = widget.month;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday is 1, so this is how many blank cells come first.
    final leading = DateTime(month.year, month.month).weekday - 1;
    final cellCount = ((leading + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final name in _dayNames)
              Expanded(
                child: Center(
                  child: Text(
                    name.substring(0, 1),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var start = 0; start < cellCount; start += 7)
          Row(
            children: [
              for (var cell = start; cell < start + 7; cell++)
                Expanded(
                  child: cell < leading || cell >= leading + daysInMonth
                      ? const SizedBox(height: 44)
                      : _dayCell(cell - leading + 1),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(int day) {
    final isSelected = day == _selectedDay;
    final isMarked = widget.markedDays.contains(day);
    final isToday = _isCurrentMonth && day == _today.day;

    final Color background;
    final Color foreground;

    if (isSelected) {
      background = AppTheme.primary;
      foreground = Colors.white;
    } else if (isMarked) {
      // A day with an entry.
      background = const Color(0xFFD8F2E5);
      foreground = AppTheme.primaryDark;
    } else {
      background = Colors.transparent;
      foreground = AppTheme.textSecondary;
    }

    return SizedBox(
      height: 44,
      child: Center(
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _select(day),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primary, width: 1.6)
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: isMarked || isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day's details in a small card: the date, then its lines.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.lines,
    required this.emptyText,
    required this.isSelected,
    this.onTap,
  });

  final String date;
  final List<CalendarLine> lines;

  /// Shown when the day has nothing to list.
  final String emptyText;
  final bool isSelected;

  /// Picks the day, for a card that shows only its short details.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : const Color(0xFFE3E9E5),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The date on a tinted label, so each day stands apart
              // from the lines under it.
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : const Color(0xFFD8F2E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primaryDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final line in lines) _LineRow(line: line),
              if (lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final CalendarLine line;

  @override
  Widget build(BuildContext context) {
    final weight = line.isStrong ? FontWeight.w800 : FontWeight.w600;

    return InkWell(
      onTap: line.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: line.title,
                  children: [
                    if (line.note != null)
                      TextSpan(
                        text: '  ${line.note}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: weight,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (line.values != null)
              for (final value in line.values!)
                SizedBox(
                  width: 64,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: line.isHeader
                        ? const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          )
                        : TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: line.isStrong
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                  ),
                )
            else
              Text(
                line.trailing,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: line.isStrong ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            // A pencil marks a line that opens for editing when tapped.
            if (line.action != null)
              line.action!
            else if (line.onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 10, right: 6),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
