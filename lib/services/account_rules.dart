/// What a new account's details must look like.
class AccountRules {
  AccountRules._();

  /// A Bangladeshi mobile number: 11 digits starting with 01.
  static const int phoneLength = 11;

  static final RegExp _phone = RegExp(r'^01[0-9]{9}$');

  /// At least 6 characters, with an upper-case letter, a lower-case
  /// letter, a digit and a special character.
  static final RegExp _password = RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).{6,}$',
  );

  static const String passwordHint =
      'At least 6 characters with A–Z, a–z, 0–9 and a symbol';

  /// Each part of the password rule, for a checklist that fills in
  /// as the password is typed.
  static List<({String label, bool isMet})> passwordChecks(String value) => [
    (label: '6+ Characters', isMet: value.length >= 6),
    (label: 'A–Z', isMet: RegExp(r'[A-Z]').hasMatch(value)),
    (label: 'a–z', isMet: RegExp(r'[a-z]').hasMatch(value)),
    (label: '0–9', isMet: RegExp(r'[0-9]').hasMatch(value)),
    (label: 'Symbol', isMet: RegExp(r'[^A-Za-z0-9]').hasMatch(value)),
  ];

  static bool isValidPhone(String phone) => _phone.hasMatch(phone.trim());

  static String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) return 'Please enter your phone number.';
    if (!isValidPhone(phone)) {
      return 'Enter an 11-digit number, such as 01712345678.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || !_password.hasMatch(value)) {
      return 'Use at least 6 characters with A–Z, a–z, 0–9 and a symbol.';
    }
    return null;
  }
}
