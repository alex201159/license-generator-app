import 'package:flutter_test/flutter_test.dart';
import 'package:license_generator_app/currency.dart';

void main() {
  test('Parses reais exactly into cents', () {
    const amounts = {
      '150': 15000,
      '150,00': 15000,
      '150.50': 15050,
      '1.234,56': 123456,
      '1.234': 123400,
      '1.234.567,89': 123456789,
      'R\$ 150,5': 15050,
      ' 0,01 ': 1,
      '0': 0,
    };
    amounts.forEach((input, expected) {
      expect(parseAmountCents(input), expected, reason: input);
    });
  });

  test('Rejects negative, malformed, or imprecise amounts', () {
    for (final input in [
      '',
      '-150',
      'abc',
      '1e3',
      '1,234',
      '12.34,56',
      '150,00,00',
      'NaN',
      '90071992547409,92',
      '99999999999999999999999999',
    ]) {
      expect(parseAmountCents(input), isNull, reason: input);
    }
  });

  test('Formats reais with Brazilian separators', () {
    expect(formatAmountCents(0), 'R\$ 0,00');
    expect(formatAmountCents(1), 'R\$ 0,01');
    expect(formatAmountCents(15050), 'R\$ 150,50');
    expect(formatAmountCents(123456789), 'R\$ 1.234.567,89');
  });
}
