import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/core/accounting/money.dart';

void main() {
  test('seeded exact-money roundtrip and inverse properties', () {
    const seed = int.fromEnvironment('PROPERTY_SEED', defaultValue: 20260916);
    final random = Random(seed);
    for (var sample = 0; sample < 2000; sample++) {
      final scale = random.nextInt(5);
      final units =
          BigInt.from(random.nextInt(1 << 30)) * BigInt.from(1 << 30) +
          BigInt.from(random.nextInt(1 << 30));
      final signed = random.nextBool() ? units : -units;
      final money = LedgerMoney(signed, scale);
      final roundtrip = LedgerMoney.parse(
        money.decimal,
        scale,
        constrain: false,
      );
      expect(
        roundtrip.units,
        signed,
        reason: 'seed=$seed sample=$sample scale=$scale',
      );
      expect((money + money.negative).units, BigInt.zero);
      expect(money.negative.negative.decimal, money.decimal);
    }
  });
  test('precision and scale boundaries never round rejected amounts', () {
    for (var scale = 0; scale <= 4; scale++) {
      expect(
        () => LedgerMoney.parse('1.${'0' * scale}1', scale),
        throwsFormatException,
      );
      expect(
        () =>
            LedgerMoney(BigInt.one, scale) + LedgerMoney(BigInt.one, scale + 1),
        throwsArgumentError,
      );
    }
    for (final invalid in [
      '',
      'NaN',
      'Infinity',
      '1e3',
      '+1',
      '01',
      '1,000',
      ' 1',
      '1 ',
    ]) {
      expect(
        () => LedgerMoney.parse(invalid, 2),
        throwsFormatException,
        reason: invalid,
      );
    }
  });
}
