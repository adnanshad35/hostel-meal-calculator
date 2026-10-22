import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum _Measure { meals, expenses }

/// The month day by day on the dashboard: a column for each day so far,
/// showing the hostel's meals or what it spent. Tapping a day shows its
/// figure above the columns; today's is shown at first.
class MonthTrendCard extends StatefulWidget {
  const MonthTrendCard({
    super.key,
    required this.month,
    required this.meals,
    required this.expenses,
  });

  /// Any date in the month shown.
  final DateTime month;

  /// One figure per day, the 1st first. Null while they load.
  final List<double>? meals;
  final List<double>? expenses;

  @override
  State<MonthTrendCard> createState() => _MonthTrendCardState();
}

const _monthShort = [
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

class _MonthTrendCardState extends State<MonthTrendCard> {
  _Measure _measure = _Measure.meals;

  /// The day whose figure is shown; today until another is tapped.
  late int _selectedDay = _lastDay;

  static const double _chartHeight = 112;

  /// Columns never grow wider than this, so they stay thin.
  static const double _maxBarWidth = 14;

  int get _daysInMonth =>
      DateTime(widget.month.year, widget.month.month + 1, 0).day;

  /// Today, or the month's last day for an earlier month.
  int get _lastDay {
    final now = DateTime.now();
    final isThisMonth =
        now.year == widget.month.year && now.month == widget.month.month;
    return isThisMonth ? now.day : _daysInMonth;
  }

  static String _count(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  static String _money(double value) {
    final whole = value.round().toString();
    final grouped = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
      grouped.write(whole[index]);
    }
    return '৳$grouped';
  }

  String _format(double value) {
    return _measure == _Measure.meals
        ? '${_count(value)} ${value == 1 ? 'Meal' : 'Meals'}'
        : _money(value);
  }

  @override
  Widget build(BuildContext context) {
    final values = _measure == _Measure.meals ? widget.meals : widget.expenses;
    final selected = values == null || _selectedDay > values.length
        ? null
        : values[_selectedDay - 1];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title and switch share the width: on a narrow phone or
            // with a large font the switch shrinks a little and the
            // title shortens, instead of running off the card.
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text(
                      'This Month',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<_Measure>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity(
                          horizontal: -3,
                          vertical: -3,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: WidgetStatePropertyAll(
                          TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: _Measure.meals,
                          label: Text('Meals'),
                        ),
                        ButtonSegment(
                          value: _Measure.expenses,
                          label: Text('Expenses'),
                        ),
                      ],
                      selected: {_measure},
                      onSelectionChanged: (selection) {
                        setState(() => _measure = selection.first);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // The tapped day's figure.
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    '$_selectedDay ${_monthShort[widget.month.month - 1]}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  selected == null ? '—' : _format(selected),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (values == null)
              const SizedBox(
                height: _chartHeight + 22,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _chart(values),
          ],
        ),
      ),
    );
  }

  Widget _chart(List<double> values) {
    final days = _daysInMonth;
    final shown = math.min(_lastDay, values.length);
    final highest = values.take(shown).fold<double>(0, math.max);

    return Semantics(
      label: _measure == _Measure.meals
          ? 'Meals each day this month'
          : 'Expenses each day this month',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / days;
          // A 2px gap between neighbours, and never wider than the cap.
          final barWidth = math.max(2.0, math.min(slot - 2, _maxBarWidth));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var day = 1; day <= days; day++)
                      Expanded(
                        // The whole column is the target, not just the
                        // bar, so a short day is easy to tap.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: day <= shown
                              ? () => setState(() => _selectedDay = day)
                              : null,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _bar(
                              value: day <= shown ? values[day - 1] : 0,
                              highest: highest,
                              width: barWidth,
                              isSelected: day == _selectedDay,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // The baseline every column grows from.
              Container(height: 1, color: const Color(0xFFE3E9E5)),
              const SizedBox(height: 5),
              // A few day numbers under the columns, not one per day.
              SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    for (final day in {1, 10, 20, days})
                      Positioned(
                        left: (slot * (day - 0.5) - 12).clamp(
                          0.0,
                          constraints.maxWidth - 24,
                        ),
                        width: 24,
                        child: Text(
                          '$day',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bar({
    required double value,
    required double highest,
    required double width,
    required bool isSelected,
  }) {
    if (value <= 0 || highest <= 0) {
      // An empty day still shows where it is when picked.
      return isSelected
          ? Container(
              width: width,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : const SizedBox.shrink();
    }

    final height = math.max(3.0, _chartHeight * value / highest);
    final radius = math.min(4.0, width / 2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        // The picked day in the deep green, the rest in the brand green.
        color: isSelected
            ? AppTheme.primaryDark
            : AppTheme.primary.withValues(alpha: 0.78),
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
    );
  }
}
