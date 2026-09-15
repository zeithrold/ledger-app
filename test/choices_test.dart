import 'package:flutter_test/flutter_test.dart';
import 'support/reference_fixture.dart';

void main() {
  final catalog = referenceFixture();
  test('offline currencies contain ISO codes and both language labels', () {
    for (final language in ['en', 'zh']) {
      final choices = catalog.currencyChoices(language);
      expect(choices.length, greaterThan(100));
      expect(choices.map((c) => c.value).toSet().length, choices.length);
      expect(choices.any((c) => c.value == 'CNY'), isTrue);
      expect(choices.any((c) => c.value == 'GBP'), isTrue);
      expect(
        choices.any(
          (c) => ['SLE', 'VES', 'XCG', 'ZWG', 'MRU'].contains(c.value),
        ),
        isFalse,
      );
    }
    expect(
      catalog.currencyChoices('zh').firstWhere((c) => c.value == 'CNY').label,
      contains('人民币'),
    );
  });
  test('timezones use IANA identifiers and date-aware daylight saving', () {
    final winter = catalog.timezoneChoices('en', at: DateTime.utc(2026));
    final summer = catalog.timezoneChoices('zh', at: DateTime.utc(2026, 7));
    expect(
      winter.firstWhere((c) => c.value == 'America/New_York').subtitle,
      contains('UTC-05:00'),
    );
    expect(
      summer.firstWhere((c) => c.value == 'America/New_York').subtitle,
      contains('UTC-04:00'),
    );
    expect(
      summer.firstWhere((c) => c.value == 'Asia/Shanghai').label,
      equals('上海'),
    );
    expect(
      summer.firstWhere((c) => c.value == 'Asia/Shanghai').subtitle,
      'UTC+08:00 · Asia/Shanghai',
    );
    expect(summer.any((c) => c.value == 'UTC'), isTrue);
  });
}
