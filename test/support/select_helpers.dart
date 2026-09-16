import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_harness.dart';

/// Opens a form selector and commits one catalog option.
Future<void> selectAccounting(
  WidgetTester tester,
  String key,
  String value,
) async {
  await press(tester, key);
  final search = find.byKey(const ValueKey('choice-search'));
  if (search.evaluate().isNotEmpty) {
    await tester.enterText(search, value);
    await tester.pumpAndSettle();
  }
  final option = find.byKey(ValueKey('option-$value'));
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> openSettingsLanguage(WidgetTester tester) async {
  final select = find.byKey(const ValueKey('settings-language'));
  await tester.scrollUntilVisible(
    select,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(select);
  await tester.pumpAndSettle();
  await tester.tap(select);
  await tester.pumpAndSettle();
}

Future<void> chooseSettingsTheme(WidgetTester tester, String mode) async {
  final select = find.byKey(const ValueKey('settings-appearance'));
  await tester.scrollUntilVisible(
    select,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(select);
  await tester.pumpAndSettle();
  await tester.tap(select);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('theme-$mode'));
  await tester.scrollUntilVisible(
    option,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}
