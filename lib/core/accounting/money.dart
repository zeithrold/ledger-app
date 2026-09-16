/// An exact fixed-scale decimal. Binary floating point never participates.
class LedgerMoney {
  /// Constructs a value in integer minor units.
  const LedgerMoney(this.units, this.scale);

  /// Parses a canonical decimal without rounding an over-precise input.
  factory LedgerMoney.parse(String text, int scale, {bool constrain = true}) {
    if (scale < 0 ||
        scale > 4 ||
        !RegExp(r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$').hasMatch(text)) {
      throw const FormatException('Invalid decimal');
    }
    final parts = text.replaceFirst('-', '').split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    if ((constrain && parts.first.length > 18) || fraction.length > scale) {
      throw const FormatException('Amount exceeds precision or range');
    }
    var units = BigInt.parse('${parts.first}${fraction.padRight(scale, '0')}');
    if (text.startsWith('-')) units = -units;
    return LedgerMoney(units, scale);
  }

  /// Signed smallest currency units.
  final BigInt units;

  /// Decimal places defined by the currency catalog.
  final int scale;

  /// Adds values with the same scale.
  LedgerMoney operator +(LedgerMoney other) {
    if (scale != other.scale) throw ArgumentError('Different currency scales');
    return LedgerMoney(units + other.units, scale);
  }

  /// Negates the exact amount.
  LedgerMoney get negative => LedgerMoney(-units, scale);

  /// Serializes for the API, without grouping or currency symbols.
  String get decimal {
    final sign = units.isNegative ? '-' : '';
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    if (scale == 0) return '$sign$digits';
    return '$sign${digits.substring(0, digits.length - scale)}.'
        '${digits.substring(digits.length - scale)}';
  }

  /// Formats financial values without converting large integers to a double.
  String format(String currency) {
    final pieces = decimal.split('.');
    final whole = pieces.first.replaceFirst('-', '');
    final grouped = whole.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${units.isNegative ? '-' : ''}$grouped'
        '${scale > 0 ? '.${pieces.last}' : ''} $currency';
  }

  /// Converts through an exact market ratio.
  ///
  /// The destination minor units are
  /// `units * numerator * 10^destinationScale / (denominator * 10^scale)`,
  /// rounded half to even on an exact tie. Only `BigInt` arithmetic
  /// participates; binary floating point never does. A non-integer or
  /// non-positive numerator/denominator and a negative [destinationScale]
  /// raise a [FormatException].
  LedgerMoney scaledByRatio(
    String numerator,
    String denominator,
    int destinationScale,
  ) {
    if (destinationScale < 0) {
      throw const FormatException('Invalid destination scale');
    }
    final dividend =
        units *
        _positiveInteger(numerator, 'numerator') *
        BigInt.from(10).pow(destinationScale);
    final divisor =
        _positiveInteger(denominator, 'denominator') *
        BigInt.from(10).pow(scale);
    return LedgerMoney(_divideHalfEven(dividend, divisor), destinationScale);
  }

  static BigInt _positiveInteger(String text, String name) {
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
      throw FormatException('Invalid $name');
    }
    final value = BigInt.parse(text);
    if (value <= BigInt.zero) throw FormatException('Invalid $name');
    return value;
  }

  /// Rounds an exact integer division to the nearest even value on a tie.
  static BigInt _divideHalfEven(BigInt dividend, BigInt divisor) {
    final magnitude = dividend.abs();
    final quotient = magnitude ~/ divisor;
    final remainder = magnitude % divisor;
    final twice = remainder * BigInt.two;
    final rounded = twice > divisor || (twice == divisor && quotient.isOdd)
        ? quotient + BigInt.one
        : quotient;
    return dividend.isNegative ? -rounded : rounded;
  }
}
