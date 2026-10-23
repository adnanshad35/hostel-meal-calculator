import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/daily_trend.dart';
import '../theme/app_theme.dart';

enum _Measure { rate, meals, cost }

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

/// The month so far against last month, day by day: the meal rate,
/// meals or cost running up through each month. This month is the
/// filled green line, last month the dashed brass one. Tapping or
/// dragging across picks a day.
class MonthTrendChart extends StatefulWidget {
  const MonthTrendChart({
    super.key,
    required this.month,
    required this.current,
    this.previous,
  });

  /// Any date in the month shown.
  final DateTime month;
  final DailyTrend current;

  /// Last month, or null when the hostel has none.
  final DailyTrend? previous;

  @override
  State<MonthTrendChart> createState() => _MonthTrendChartState();
}

class _MonthTrendChartState extends State<MonthTrendChart> {
  _Measure _measure = _Measure.rate;

  /// The day picked, 1-based; null for the latest day of this month.
  int? _day;

  static const double _chartHeight = 150;
  static const double _axisWidth = 34;

  static const Color _currentColor = AppTheme.primary;
  static const Color _previousColor = AppTheme.accentDeep;

  int get _days => math.max(widget.current.days, widget.previous?.days ?? 0);

  int get _selectedDay {
    final latest = math.max(widget.current.days, 1);
    return (_day ?? latest).clamp(1, math.max(_days, 1));
  }

  String get _currentName => _monthShort[widget.month.month - 1];

  String get _previousName {
    final month = DateTime(widget.month.year, widget.month.month - 1);
    return _monthShort[month.month - 1];
  }

  List<double> _values(DailyTrend trend) {
    return switch (_measure) {
      _Measure.rate => [
        for (var index = 0; index < trend.days; index++) trend.rateAt(index),
      ],
      _Measure.meals => trend.meals,
      _Measure.cost => trend.cost,
    };
  }

  static String _grouped(double value) {
    final whole = value.round().toString();
    final grouped = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
      grouped.write(whole[index]);
    }
    return grouped.toString();
  }

  String _format(double value) {
    return switch (_measure) {
      _Measure.rate => '৳${value.toStringAsFixed(2)}',
      _Measure.meals => _grouped(value),
      _Measure.cost => '৳${_grouped(value)}',
    };
  }

  /// A short axis label: 12k for 12,000.
  String _tick(double value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands % 1 == 0 ? thousands.toInt() : thousands.toStringAsFixed(1)}k';
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  /// A round step so three steps cover [highest].
  static double _step(double highest) {
    if (highest <= 0) return 1;
    final rough = highest / 3;
    final power = math.pow(10, (math.log(rough) / math.ln10).floor());
    for (final factor in const [1, 2, 2.5, 5, 10]) {
      if (factor * power >= rough) return factor * power.toDouble();
    }
    return 10 * power.toDouble();
  }

  void _pick(double x, double width) {
    final plotWidth = width - _axisWidth;
    if (_days < 1 || plotWidth <= 0) return;

    final share = ((x - _axisWidth) / plotWidth).clamp(0.0, 1.0);
    final day = _days == 1 ? 1 : (share * (_days - 1)).round() + 1;
    if (day != _selectedDay) setState(() => _day = day);
  }

  @override
  Widget build(BuildContext context) {
    final current = _values(widget.current);
    final previous = widget.previous == null ? null : _values(widget.previous!);
    final day = _selectedDay;
    final currentValue = day <= current.length ? current[day - 1] : null;
    final previousValue = previous != null && day <= previous.length
        ? previous[day - 1]
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The title in the middle, with the switch under it.
            const Text(
              'Month Trend',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.accentDeep,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SegmentedButton<_Measure>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity(horizontal: -3, vertical: -3),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(value: _Measure.rate, label: Text('Rate')),
                    ButtonSegment(value: _Measure.meals, label: Text('Meals')),
                    ButtonSegment(value: _Measure.cost, label: Text('Cost')),
                  ],
                  selected: {_measure},
                  onSelectionChanged: (selection) {
                    setState(() => _measure = selection.first);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            // The picked day, with each month's figure beside its key.
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Day $day',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  flex: 4,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      children: [
                        _Key(
                          color: _currentColor,
                          label: _currentName,
                          value: currentValue == null
                              ? '—'
                              : _format(currentValue),
                        ),
                        if (previous != null) ...[
                          const SizedBox(width: 14),
                          _Key(
                            color: _previousColor,
                            isDashed: true,
                            label: _previousName,
                            value: previousValue == null
                                ? '—'
                                : _format(previousValue),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _chart(current, previous),
          ],
        ),
      ),
    );
  }

  Widget _chart(List<double> current, List<double>? previous) {
    final highest = [...current, ...?previous].fold<double>(0, math.max);
    final step = _step(highest);

    return Semantics(
      label: previous == null
          ? '$_currentName day by day'
          : '$_currentName against $_previousName day by day',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final plotWidth = width - _axisWidth;
          final days = math.max(_days, 1);

          double xOf(int day) => days == 1
              ? _axisWidth + plotWidth / 2
              : _axisWidth + plotWidth * (day - 1) / (days - 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _pick(details.localPosition.dx, width),
                onHorizontalDragUpdate: (details) =>
                    _pick(details.localPosition.dx, width),
                child: SizedBox(
                  height: _chartHeight,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      current: current,
                      previous: previous,
                      days: days,
                      top: step * 3,
                      ticks: [
                        for (var index = 0; index <= 3; index++)
                          _tick(step * index),
                      ],
                      selectedDay: _selectedDay,
                      axisWidth: _axisWidth,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // A few day numbers, not one per day.
              SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    for (final day in {1, 10, 20, days})
                      if (day <= days)
                        Positioned(
                          left: (xOf(day) - 12).clamp(0.0, width - 24),
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
}

/// A month's key: its line style, short name and figure.
class _Key extends StatelessWidget {
  const _Key({
    required this.color,
    required this.label,
    required this.value,
    this.isDashed = false,
  });

  final Color color;
  final String label;
  final String value;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 4,
          child: isDashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var index = 0; index < 3; index++)
                      Container(width: 4, height: 3, color: color),
                  ],
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.current,
    required this.previous,
    required this.days,
    required this.top,
    required this.ticks,
    required this.selectedDay,
    required this.axisWidth,
  });

  final List<double> current;
  final List<double>? previous;
  final int days;

  /// The value at the top gridline.
  final double top;

  /// Labels of the four gridlines, from the bottom.
  final List<String> ticks;
  final int selectedDay;
  final double axisWidth;

  static const double _padTop = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - axisWidth;
    final plotHeight = size.height - _padTop;

    double xOf(int day) => days == 1
        ? axisWidth + plotWidth / 2
        : axisWidth + plotWidth * (day - 1) / (days - 1);
    double yOf(double value) =>
        _padTop + plotHeight * (1 - (top <= 0 ? 0 : value / top));

    // Faint dashed gridlines with their values, the baseline solid.
    final grid = Paint()
      ..color = const Color(0xFFDDE4DF)
      ..strokeWidth = 1;
    for (var index = 0; index < ticks.length; index++) {
      final y = yOf(top * index / 3).roundToDouble() - 0.5;
      if (index == 0) {
        canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), grid);
      } else {
        for (var x = axisWidth; x < size.width; x += 7) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + 3, size.width), y),
            grid,
          );
        }
      }

      final label = TextPainter(
        text: TextSpan(
          text: ticks[index],
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 6);
      label.paint(
        canvas,
        Offset(axisWidth - 6 - label.width, y - label.height / 2),
      );
    }

    // The picked day.
    final selectedX = xOf(selectedDay);
    canvas.drawLine(
      Offset(selectedX, _padTop),
      Offset(selectedX, size.height),
      Paint()
        ..color = const Color(0xFFC9D3CD)
        ..strokeWidth = 1,
    );

    Path lineOf(List<double> values) {
      final path = Path()..moveTo(xOf(1), yOf(values.first));
      for (var day = 2; day <= values.length; day++) {
        path.lineTo(xOf(day), yOf(values[day - 1]));
      }
      return path;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Last month: dashed, behind this month.
    final previous = this.previous;
    if (previous != null && previous.isNotEmpty) {
      final dash = stroke..color = _MonthTrendChartState._previousColor;
      for (final metric in lineOf(previous).computeMetrics()) {
        for (var start = 0.0; start < metric.length; start += 9) {
          canvas.drawPath(
            metric.extractPath(start, math.min(start + 5, metric.length)),
            dash,
          );
        }
      }
    }

    // This month: a soft fill under a solid line.
    if (current.isNotEmpty) {
      final line = lineOf(current);
      final baseline = yOf(0);
      final area = Path.from(line)
        ..lineTo(xOf(current.length), baseline)
        ..lineTo(xOf(1), baseline)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _MonthTrendChartState._currentColor.withValues(alpha: 0.22),
              _MonthTrendChartState._currentColor.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTRB(0, _padTop, size.width, baseline)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = _MonthTrendChartState._currentColor,
      );
    }

    // A ringed dot on each line at the picked day.
    void dot(List<double>? values, Color color) {
      if (values == null || selectedDay > values.length) return;
      final centre = Offset(selectedX, yOf(values[selectedDay - 1]));
      canvas.drawCircle(centre, 6, Paint()..color = AppTheme.surface);
      canvas.drawCircle(centre, 4, Paint()..color = color);
    }

    dot(previous, _MonthTrendChartState._previousColor);
    dot(current, _MonthTrendChartState._currentColor);
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) => true;
}
