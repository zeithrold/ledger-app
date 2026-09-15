import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/network/http_client.dart';
import 'package:ledger_app/features/home/home_page.dart';

void main() {
  for (final (input, expected) in [
    ('  HTTPS://Example.com:443  ', 'https://example.com/'),
    ('http://10.0.2.2:8080', 'http://10.0.2.2:8080/'),
    ('http://localhost:8080/', 'http://localhost:8080/'),
    ('https://example.com/ledger///', 'https://example.com/ledger/'),
    ('http://[::1]:8080', 'http://[::1]:8080/'),
  ]) {
    test('normalizes $input', () {
      expect(parseApiEndpoint(input).toString(), expected);
    });
  }

  for (final input in [
    '',
    'example.com',
    '/api/v1',
    'ftp://example.com',
    'https://',
    'https://user:password@example.com',
    'https://example.com?token=secret',
    'https://example.com/#fragment',
    'https://example.com:0',
    'https://example.com:65536',
    'https://example .com',
    r'https://example.com\path',
  ]) {
    test('rejects invalid endpoint $input', () {
      expect(() => parseApiEndpoint(input), throwsFormatException);
    });
  }

  for (final value in ['', 'not-a-url']) {
    test('invalid deployment configuration disables networking: $value', () {
      final container = _container(value);
      expect(container.read(apiEndpointProvider), isNull);
      expect(
        () => container.read(httpClientProvider),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('API_BASE_URL is missing or invalid'),
          ),
        ),
      );
    });
  }

  for (final code in ['en', 'zh']) {
    for (final value in ['', 'https://example.com/proxy']) {
      testWidgets('$code endpoint is read-only: $value', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = _container(value);
        container
            .read(localeControllerProvider.notifier)
            .setLocale(Locale(code));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const LedgerApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HomePage), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('settings-tab')));
        await tester.pumpAndSettle();
        final expected = value.isEmpty
            ? (code == 'en' ? 'Not configured' : '未配置')
            : 'https://example.com/proxy/';
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('current-endpoint')),
          150,
        );
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(
          container.read(apiEndpointProvider)?.toString(),
          value.isEmpty ? null : expected,
        );
        expect(find.byType(EditableText), findsNothing);
        expect(find.byKey(const ValueKey('change-endpoint')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('current-endpoint')));
        await tester.pumpAndSettle();
        expect(find.byType(EditableText), findsNothing);
        expect(tester.takeException(), isNull);
        container.read(routerProvider).go('/settings/endpoint');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('endpoint-input')), findsNothing);
        expect(
          find.text(code == 'en' ? 'Page not found' : '页面不存在'),
          findsOneWidget,
        );
      });
    }
  }
}

ProviderContainer _container(String endpoint) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromEnvironment(apiBaseUrl: endpoint),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
