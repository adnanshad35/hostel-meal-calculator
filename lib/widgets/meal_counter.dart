import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A lunch or dinner quantity that can be changed with the − and +
/// buttons (half a meal at a time) or typed directly.
class MealCounter extends StatefulWidget {
  const MealCounter({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// The largest quantity that can be entered for one meal.
  static const double maxValue = 99;

  final String title;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// Turns typed text into a quantity: a number from 0 to [maxValue],
  /// rounded to the nearest half meal. Returns null for anything else.
  static double? parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value.isNaN || value < 0) return null;

    final rounded = (value * 2).round() / 2;
    return rounded > maxValue ? maxValue : rounded;
  }

  static String format(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  State<MealCounter> createState() => _MealCounterState();
}

class _MealCounterState extends State<MealCounter> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: MealCounter.format(widget.value));
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(MealCounter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Leave the text alone while it is being typed ("1." is on its way
    // to "1.5"); otherwise show the current value.
    if (!_focusNode.hasFocus) {
      _showValue();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showValue() {
    final text = MealCounter.format(widget.value);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Typing replaces the number instead of adding digits to it.
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _showValue();
    }
  }

  void _onTyped(String text) {
    // An emptied field counts as zero.
    final value = text.trim().isEmpty ? 0.0 : MealCounter.parse(text);
    if (value != null && value != widget.value) {
      widget.onChanged(value);
    }
  }

  void _step(double amount) {
    final value = (widget.value + amount)
        .clamp(0, MealCounter.maxValue)
        .toDouble();

    _focusNode.unfocus();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Row(
      children: [
        Icon(widget.icon, size: 24, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          tooltip: 'Decrease ${widget.title.toLowerCase()}',
          onPressed: widget.enabled && widget.value > 0
              ? () => _step(-0.5)
              : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            textAlign: TextAlign.center,
            style: textStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              border: UnderlineInputBorder(),
              enabledBorder: UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(),
              disabledBorder: UnderlineInputBorder(),
            ),
            onChanged: _onTyped,
            onSubmitted: (_) => _focusNode.unfocus(),
          ),
        ),
        IconButton.filled(
          visualDensity: VisualDensity.compact,
          tooltip: 'Increase ${widget.title.toLowerCase()}',
          onPressed: widget.enabled && widget.value < MealCounter.maxValue
              ? () => _step(0.5)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
