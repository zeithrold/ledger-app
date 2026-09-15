import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/core/accounting/money.dart';

void main() {
  test('exact money retains large integers and all supported scales', () {
    for (final (input, scale, expected) in [
      ('123', 0, '123'),
      ('999999999999999999.99', 2, '999999999999999999.99'),
      ('0.001', 3, '0.001'),
      ('-1.2345', 4, '-1.2345'),
      ('-0.00', 2, '0.00'),
    ]) {
      final amount = LedgerMoney.parse(input, scale);
      expect(amount.decimal, expected);
      expect((amount + amount.negative).units, BigInt.zero);
    }
    final opening = LedgerMoney.parse('1000', 2);
    final principal = LedgerMoney.parse('100', 2);
    final fee = LedgerMoney.parse('1', 2);
    expect((opening + principal.negative + fee.negative).decimal, '899.00');
    expect(
      LedgerMoney.parse('999999999999999999.99', 2).format('USD'),
      '999,999,999,999,999,999.99 USD',
    );
  });
  test('inputs reject rounding, exponents, special values and overflows', () {
    for (final input in [
      '1.001',
      '1e2',
      'NaN',
      'Infinity',
      '+1',
      '01',
      '.2',
      '1.',
      '1000000000000000000',
      ' 1',
      '1/3',
      '',
    ]) {
      expect(() => LedgerMoney.parse(input, 2), throwsFormatException);
    }
    expect(() => LedgerMoney.parse('1.0', 0), throwsFormatException);
    expect(
      LedgerMoney.parse('1000000000000000000', 2, constrain: false).decimal,
      '1000000000000000000.00',
    );
    expect(
      () => LedgerMoney.parse('1', 2) + LedgerMoney.parse('1', 3),
      throwsArgumentError,
    );
  });
}
