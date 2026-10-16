import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/account_rules.dart';

void main() {
  test('a phone number is 11 digits starting with 01', () {
    expect(AccountRules.validatePhone('01712345678'), isNull);
    expect(AccountRules.validatePhone(''), isNotNull);
    expect(AccountRules.validatePhone('0171234567'), isNotNull);
    expect(AccountRules.validatePhone('017123456789'), isNotNull);
    expect(AccountRules.validatePhone('+8801712345'), isNotNull);
    expect(AccountRules.validatePhone('11712345678'), isNotNull);
  });

  test('a password needs upper, lower, digit and symbol, 6 or more', () {
    expect(AccountRules.validatePassword('Abc12!'), isNull);
    expect(AccountRules.validatePassword('Ab1!'), isNotNull);
    expect(AccountRules.validatePassword('abc123!'), isNotNull);
    expect(AccountRules.validatePassword('ABC123!'), isNotNull);
    expect(AccountRules.validatePassword('Abcdef!'), isNotNull);
    expect(AccountRules.validatePassword('Abc1234'), isNotNull);
    expect(AccountRules.validatePassword(null), isNotNull);
  });
}
