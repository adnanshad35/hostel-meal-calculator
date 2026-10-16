import 'package:shared_preferences/shared_preferences.dart';

/// Stops sign-in for a while after too many wrong passwords in a row.
/// Kept on the device, so closing the app does not reset it.
class SignInLimiter {
  SignInLimiter._();

  static const int maxAttempts = 3;
  static const Duration lockDuration = Duration(minutes: 5);

  static const String _failuresKey = 'signIn.failures';
  static const String _lockedUntilKey = 'signIn.lockedUntil';

  /// When sign-in opens again, or null when it is open now.
  static Future<DateTime?> lockedUntil() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final until = preferences.getInt(_lockedUntilKey);
      if (until == null) return null;

      final time = DateTime.fromMillisecondsSinceEpoch(until);
      if (time.isAfter(DateTime.now())) return time;

      await preferences.remove(_lockedUntilKey);
    } catch (_) {
      // Without storage there is no limit; Firebase still has its own.
    }
    return null;
  }

  /// Counts a wrong password. Returns when sign-in opens again if this
  /// one used up the attempts, otherwise null.
  static Future<DateTime?> recordFailure() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final failures = (preferences.getInt(_failuresKey) ?? 0) + 1;

      if (failures < maxAttempts) {
        await preferences.setInt(_failuresKey, failures);
        return null;
      }

      final until = DateTime.now().add(lockDuration);
      await preferences.setInt(_failuresKey, 0);
      await preferences.setInt(_lockedUntilKey, until.millisecondsSinceEpoch);
      return until;
    } catch (_) {
      return null;
    }
  }

  /// How many tries are left before sign-in is stopped.
  static Future<int> attemptsLeft() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return maxAttempts - (preferences.getInt(_failuresKey) ?? 0);
    } catch (_) {
      return maxAttempts;
    }
  }

  static Future<void> reset() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_failuresKey);
      await preferences.remove(_lockedUntilKey);
    } catch (_) {}
  }
}
