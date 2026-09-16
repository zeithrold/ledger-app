import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/features/accounting/detail.dart';
import 'package:ledger_app/features/accounting/entry_editor.dart';

import '../test/support/accounting_fixture.dart';
import '../test/support/design_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'zh']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language ${mode.name} transaction action menu', (
        tester,
      ) async {
        final requests = <String>[];
        final container = await pumpDesignApp(
          tester,
          initialLocation: '/transactions/fee',
          language: language,
          mode: mode,
          handler: (request) {
            requests.add(request.method);
            return accountingFixture(request);
          },
        );
        if (Platform.isAndroid &&
            const bool.fromEnvironment('CAPTURE_VISUALS')) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        final router = container.read(routerProvider);
        Future<void> startAtTop() async {
          // Each action starts from a known reading position. A previous
          // capture may have lazily disposed the controls above the viewport.
          final scrollable = find
              .descendant(
                of: find.byType(CustomScrollView).last,
                matching: find.byType(Scrollable),
              )
              .first;
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
        }

        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          for (final group in [
            'transaction-actions',
            'transaction-action-sheet',
          ]) {
            await startAtTop();
            if (group == 'transaction-action-sheet') {
              await press(tester, 'transaction-more');
            } else {
              await reveal(tester, group);
            }
            if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
              await binding.takeScreenshot(
                'buttons-$language-${mode.name}-${scale.toInt()}-$group',
              );
            }
            expect(tester.takeException(), isNull);
            if (group == 'transaction-action-sheet') {
              await press(tester, 'close-transaction-actions');
            }
          }
          for (final (key, target) in [
            ('transaction-edit', '/entry?edit=fee'),
            ('transaction-refund', '/entry?original=fee'),
            ('transaction-add-fee', '/entry?fee_for=fee'),
            ('transaction-link', '/link-transaction?source=fee&kind=related'),
            ('transaction-link-fee', '/link-transaction?source=fee&kind=fee'),
          ]) {
            await startAtTop();
            if (key != 'transaction-edit') {
              await press(tester, 'transaction-more');
            }
            await press(tester, key);
            final destination = find.byType(
              target.startsWith('/entry') ? EntryEditor : LinkTransactionPage,
            );
            expect(destination, findsOneWidget);
            expect(
              GoRouterState.of(tester.element(destination)).uri.toString(),
              target,
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(destination, findsNothing);
            expect(
              router.routeInformationProvider.value.uri.path,
              '/transactions/fee',
            );
            expect(tester.takeException(), isNull);
          }
        }
        expect(requests, everyElement('GET'));
      });
    }
  }
}
