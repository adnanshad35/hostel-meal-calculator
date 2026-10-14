import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One line in the details of a day: an entry, or a member's meals.
class CalendarLine {
  const CalendarLine({
    required this.title,
    required this.trailing,
    this.note,
    this.isStrong = false,
    this.onTap,
    this.action,
  });

  final String title;

  /// A short tag after the title, such as who paid.
  final String? note;
  final String trailing;

  /// Bold, for a total.
  final bool isStrong;
  final VoidCallback? onTap;

  /// A small control at the end of the line, such as a menu.
  final Widget? action;
}

/// A month of records as a calendar: one figure for the month on top,
/// the days that have an entry picked out in colour, and the details
/// of whichever day is tapped underneath.
class MonthCalendarView extends StatefulWidget {
  const MonthCalendarView({
    super.key,
    required this.month,
    required this.label,
    required this.total,
    required this.markedDays,
    required this.linesOf,
    this.emptyText = 'No entry',
  });

  /// Any date in the month to show.
  final DateTime month;

  /// What the figure is, such as "My meals".
  final String label;
  final String total;

  /// Days of the month that have an entry.
  final Set<int> markedDays;

  /// The details of one day of the month.
  final List<CalendarLine> Function(int day) linesOf;

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

class _MonthCalendarViewState extends State<MonthCalendarView> {
  late final DateTime _today = DateTime.now();
  late int _selectedDay;

  bool get _isCurrentMonth =>
      _today.year == widget.month.year && _today.month == widget.month.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _isCurrentMonth ? _today.day : 1;
  }

  /// A date as "14 Oct, Wed".
  String _dateText(DateTime date) {
    return '${date.day} ${_monthNames[date.month - 1].substring(0, 3)}, '
        '${_dayNames[date.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final lines = widget.linesOf(_selectedDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_monthNames[month.month - 1]} ${month.year}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                  ),
                ),
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
              ],
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
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateText(DateTime(month.year, month.month, _selectedDay)),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(widget.emptyText),
                  )
                else
                  for (final line in lines) _LineRow(line: line),
              ],
            ),
          ),
        ),
      ],
    );
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
          onTap: () => setState(() => _selectedDay = day),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
