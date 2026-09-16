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
  test('ratio conversion rounds half to even on exact ties', () {
    for (final (units, expected) in [
      (5, '2'),
      (7, '4'),
      (15, '8'),
      (25, '12'),
      (-5, '-2'),
      (-7, '-4'),
    ]) {
      expect(
        LedgerMoney(BigInt.from(units), 0).scaledByRatio('1', '2', 0).decimal,
        expected,
      );
    }
  });
  test('ratio conversion keeps an exact repeating ratio', () {
    expect(
      LedgerMoney(BigInt.two, 0).scaledByRatio('1', '3', 2).decimal,
      '0.67',
    );
    expect(
      LedgerMoney(BigInt.from(10), 0).scaledByRatio('1', '3', 2).decimal,
      '3.33',
    );
    expect(
      LedgerMoney(
        BigInt.from(10000),
        2,
      ).scaledByRatio('67082', '10000', 2).decimal,
      '670.82',
    );
    expect(
      LedgerMoney.parse('0.00', 2).scaledByRatio('67082', '10000', 2).decimal,
      '0.00',
    );
  });
  test('ratio conversion never loses precision to a double', () {
    final source = LedgerMoney.parse('9999999999999999.99', 2);
    final converted = source.scaledByRatio('67082', '10000', 2);
    expect(converted.decimal, '67081999999999999.93');
    expect(
      converted.units,
      BigInt.parse('6708199999999999993'),
    );
    expect(converted.scale, 2);
    // The same computation through a double silently picks a different value.
    expect(
      (source.units.toDouble() * 67082 / 10000 / 100).toStringAsFixed(2),
      '67082000000000000.00',
    );
    expect(converted.decimal, isNot('67082000000000000.00'));
  });
  test('ratio conversion rejects an invalid ratio or scale', () {
    final amount = LedgerMoney.parse('1.00', 2);
    for (final (numerator, denominator, scale) in [
      ('0', '10', 2),
      ('-1', '10', 2),
      ('1.5', '10', 2),
      ('1e2', '10', 2),
      ('+1', '10', 2),
      ('', '10', 2),
      ('one', '10', 2),
      ('1', '0', 2),
      ('1', '-10', 2),
      ('1', '2.5', 2),
      ('1', 'two', 2),
      ('1', '', 2),
      ('1', '10', -1),
    ]) {
      expect(
        () => amount.scaledByRatio(numerator, denominator, scale),
        throwsFormatException,
        reason: '$numerator/$denominator at $scale',
      );
    }
  });
}
