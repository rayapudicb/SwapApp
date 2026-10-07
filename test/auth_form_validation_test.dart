import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/features/auth/presentation/auth_form_validation.dart';

void main() {
  test(
    'accepts international phone numbers supported by passwordless auth',
    () {
      expect(validateInternationalPhone('+1 202 555 0123'), isNull);
      expect(validateInternationalPhone('+919876543210'), isNull);
    },
  );

  test('requires a country code and valid E.164 length', () {
    expect(validateInternationalPhone(''), isNotNull);
    expect(validateInternationalPhone('2025550123'), isNotNull);
    expect(validateInternationalPhone('+0123456789'), isNotNull);
    expect(validateInternationalPhone('+1 23'), isNotNull);
  });
}
