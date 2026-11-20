import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/auth/domain/password_rule.dart';

void main() {
  test('passwords need 8+ characters with letters and digits', () {
    expect(isStrongPassword('abc12345'), isTrue);
    expect(isStrongPassword('Kundli2026!'), isTrue);
    expect(isStrongPassword('abc1234'), isFalse);
    expect(isStrongPassword('abcdefgh'), isFalse);
    expect(isStrongPassword('12345678'), isFalse);
  });
}
