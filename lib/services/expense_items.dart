/// One line of an itemwise expense: "Rice · 5 kg · ৳350".
class ExpenseItem {
  const ExpenseItem({
    required this.name,
    this.quantity = '',
    required this.price,
  });

  final String name;

  /// Free text, such as "5 kg"; may be empty.
  final String quantity;
  final double price;
}

/// An itemwise expense is saved as a normal expense: the item names
/// are its name, the prices add up to its amount, and the items are
/// written into its description, one per line. No new field, so every
/// app version reads it, and older ones show the list as the note.
class ExpenseItems {
  const ExpenseItems._();

  static const separator = ' · ';

  /// The longest description an expense may have.
  static const maxDescription = 600;

  /// "Rice, Oil, Onion".
  static String nameOf(List<ExpenseItem> items) =>
      items.map((item) => item.name).join(', ');

  static double totalOf(List<ExpenseItem> items) =>
      items.fold(0, (total, item) => total + item.price);

  static String describe(List<ExpenseItem> items) => items
      .map(
        (item) => [
          item.name,
          if (item.quantity.isNotEmpty) item.quantity,
          '৳${plain(item.price)}',
        ].join(separator),
      )
      .join('\n');

  /// Removes what would break a saved line.
  static String clean(String text) =>
      text.replaceAll('·', '-').replaceAll('\n', ' ').trim();

  /// The items of a saved expense, or null when it was not saved
  /// itemwise, or was changed since in a way that no longer matches.
  static List<ExpenseItem>? parse({
    required String name,
    required String description,
    required double amount,
  }) {
    final lines = description
        .trim()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final pattern = RegExp(r'^(.+?) · ৳(\d+(?:\.\d+)?)$');
    final items = <ExpenseItem>[];
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match == null) return null;

      final head = match.group(1)!;
      final at = head.indexOf(separator);
      items.add(
        ExpenseItem(
          name: at < 0 ? head : head.substring(0, at),
          quantity: at < 0 ? '' : head.substring(at + separator.length),
          price: double.parse(match.group(2)!),
        ),
      );
    }

    if (nameOf(items) != name.trim()) return null;
    if ((totalOf(items) - amount).abs() > 0.005) return null;
    return items;
  }

  static String plain(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}
