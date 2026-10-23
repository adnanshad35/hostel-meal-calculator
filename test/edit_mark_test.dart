import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/edit_mark.dart';

void main() {
  final saved = DateTime(2026, 10, 20, 22);

  test('a change more than a minute after saving is marked', () {
    expect(
      isEdited(
        createdAt: saved,
        updatedAt: saved.add(const Duration(minutes: 2)),
      ),
      isTrue,
    );
  });

  test('a fix within the first minute is not', () {
    expect(
      isEdited(
        createdAt: saved,
        updatedAt: saved.add(const Duration(seconds: 40)),
      ),
      isFalse,
    );
  });

  test('a first save, even of an earlier day, is not an edit', () {
    expect(isEdited(createdAt: saved, updatedAt: saved), isFalse);
  });

  test('an entry without its saved times is never marked', () {
    expect(isEdited(createdAt: null, updatedAt: saved), isFalse);
  });
}
