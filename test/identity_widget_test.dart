import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/device_defaults.dart';
import 'package:ledger_app/core/network/http_client.dart';
import 'package:ledger_app/core/reference/choices.dart';

import 'support/fakes.dart';
import 'support/reference_fixture.dart';
import 'support/select_helpers.dart';

Widget application(
  FakeAuth auth,
  Future<http.Response> Function(http.Request) handler,
) => ProviderScope(
  overrides: [
    referenceChoicesProvider.overrideWith((ref) async => referenceFixture()),
    appConfigProvider.overrideWithValue(
      const AppConfig.fromEnvironment(apiBaseUrl: 'https://example.com/'),
    ),
    authGatewayProvider.overrideWithValue(auth),
    httpClientProvider.overrideWithValue(MockClient(handler)),
    deviceDefaultsProvider.overrideWith(
      (ref) async =>
          const DeviceDefaults('CNY', 'Asia/Shanghai', usedFallback: false),
    ),
  ],
  child: const LedgerApp(),
);

Future<void> openBooks(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LedgerApp)),
  );
  container.read(routerProvider).go('/books');
  await tester.pumpAndSettle();
}

void main() {
  for (final tag in ['en-CA', 'zh-Hant-TW']) {
    testWidgets('identity preference restoration preserves $tag', (
      tester,
    ) async {
      await tester.pumpWidget(
        application(FakeAuth(), (request) async {
          if (request.url.path.endsWith('/me')) {
            return jsonResponse(contextJson(locale: tag));
          }
          return normalApi(request);
        }),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LedgerApp)),
      );
      expect(container.read(localeControllerProvider).toLanguageTag(), tag);
      expect(container.read(currencyLocaleProvider), tag);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('signed-out login and settings remain accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      application(
        FakeAuth(sessionKey: null),
        (_) async => throw StateError('No requests before sign in'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A little clarity, every day.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    await chooseSettingsTheme(tester, 'dark');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('returning user sees real books and detail, never bootstrap', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      application(FakeAuth(), (request) {
        paths.add(request.url.path);
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    await openBooks(tester);
    expect(find.text('Personal space: Personal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('book-book-a')));
    await tester.pumpAndSettle();
    expect(find.text('Book details'), findsOneWidget);
    expect(find.text('Main'), findsOneWidget);
    expect(paths, contains('/api/v1/books/book-a'));
    expect(paths, isNot(contains('/api/v1/bootstrap')));
    await tester.tap(find.byKey(const ValueKey('book-back')));
    await tester.pumpAndSettle();
    expect(find.text('Personal space: Personal'), findsOneWidget);
  });
  testWidgets('setup retains input on failure and succeeds on retry', (
    tester,
  ) async {
    var posts = 0;
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (request.url.path.endsWith('/me')) {
          return problem('bootstrap-required', 409);
        }
        if (request.url.path.endsWith('/bootstrap')) {
          posts++;
          expect((jsonDecode(request.body) as Map)['base_currency'], 'GBP');
          return posts == 1
              ? problem('invalid-request', 400)
              : jsonResponse(contextJson(), 201);
        }
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Make it your ledger'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('base-currency')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('choice-search')), 'GBP');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('option-GBP')));
    await tester.pumpAndSettle();
    if (find.byKey(const ValueKey('setup-next')).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('setup-next')));
      await tester.tap(find.byKey(const ValueKey('setup-next')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-space')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-space')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('failure-message')), findsOneWidget);
    expect(find.textContaining('GBP'), findsOneWidget);
    if (find.byKey(const ValueKey('setup-next')).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('setup-next')));
      await tester.tap(find.byKey(const ValueKey('setup-next')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-space')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-space')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-book')), findsOneWidget);
    expect(posts, 2);
  });
  testWidgets('setup prevents duplicate submits while loading', (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (request.method == 'POST') {
          calls++;
          return pending.future;
        }
        return problem('bootstrap-required', 409);
      }),
    );
    await tester.pumpAndSettle();
    if (find.byKey(const ValueKey('setup-next')).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('setup-next')));
      await tester.tap(find.byKey(const ValueKey('setup-next')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-space')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    if (find.byKey(const ValueKey('setup-next')).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('setup-next')));
      await tester.tap(find.byKey(const ValueKey('setup-next')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-space')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    expect(calls, 1);
    pending.complete(problem('invalid-request', 400));
    await tester.pumpAndSettle();
  });
  for (final (slug, status, message) in [
    (
      'user-disabled',
      403,
      'Your account has been disabled. Contact your instance administrator.',
    ),
    (
      'api-version-unsupported',
      400,
      'This app version is incompatible with the server. '
          'Update the app or contact the administrator.',
    ),
    (
      'service-unavailable',
      503,
      'The service is temporarily unavailable. Try again later.',
    ),
  ]) {
    testWidgets('$slug blocks user pages and permits retry or logout', (
      tester,
    ) async {
      await tester.pumpWidget(
        application(FakeAuth(), (_) async => problem(slug, status)),
      );
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('Support reference: request-test'), findsNothing);
      await tester.tap(find.text('Support details'));
      await tester.pumpAndSettle();
      expect(find.text('Support reference: request-test'), findsOneWidget);
      expect(find.byKey(const ValueKey('book-book-a')), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('A little clarity, every day.'), findsOneWidget);
    });
  }
  testWidgets('transport failure can recover with retry', (tester) async {
    var fail = true;
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (fail) throw http.ClientException('Do not expose upstream content');
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to connect. Check your connection and try again.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-book')), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });
  testWidgets('empty list and failed refresh are visible', (tester) async {
    var fail = false;
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (request.url.path.endsWith('/books')) {
          return fail
              ? problem('internal-error', 500)
              : jsonResponse({'books': <Object>[]});
        }
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    await openBooks(tester);
    expect(find.text('No ledgers yet'), findsOneWidget);
    fail = true;
    await tester.tap(find.byKey(const ValueKey('refresh-books')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('failure-message')), findsOneWidget);
  });
  testWidgets(
    'preferences apply only after save; signout resets theme and language',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        application(FakeAuth(), (request) async {
          if (request.method == 'PATCH' && fail) {
            return problem('invalid-request', 400);
          }
          return normalApi(request);
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-tab')));
      await tester.pumpAndSettle();
      await chooseSettingsTheme(tester, 'dark');
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('settings-appearance'))),
        ).brightness,
        Brightness.light,
      );
      fail = false;
      await openSettingsLanguage(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('locale-zh')));
      await tester.tap(find.byKey(const ValueKey('locale-zh')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-language')),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('简体中文'), findsOneWidget);
      expect(
        Localizations.localeOf(
          tester.element(find.byKey(const ValueKey('settings-language'))),
        ).languageCode,
        'zh',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sign-out')),
        150,
      );
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(
          tester.element(find.byKey(const ValueKey('settings-language'))),
        ).languageCode,
        'en',
      );
      await tester.tap(find.byKey(const ValueKey('home-tab')));
      await tester.pumpAndSettle();
      expect(find.text('A little clarity, every day.'), findsOneWidget);
    },
  );
  testWidgets('book detail access loss clears protected content', (
    tester,
  ) async {
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (request.url.path == '/api/v1/books/book-a') {
          return problem('user-disabled', 403);
        }
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    await openBooks(tester);
    await tester.tap(find.byKey(const ValueKey('book-book-a')));
    await tester.pumpAndSettle();
    expect(find.text('Book details'), findsNothing);
    expect(
      find.text(
        'Your account has been disabled. Contact your instance administrator.',
      ),
      findsOneWidget,
    );
  });
  for (final locale in ['en', 'zh-CN']) {
    testWidgets(
      '$locale identity layout supports small screens and large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          application(FakeAuth(), (request) async {
            if (request.url.path.endsWith('/me')) {
              return jsonResponse(contextJson(locale: locale));
            }
            return normalApi(request);
          }),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('settings-tab')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('new user keeps the selected signed-out language for setup', (
    tester,
  ) async {
    final auth = FakeAuth(sessionKey: null);
    await tester.pumpWidget(
      application(auth, (request) async {
        if (request.method == 'POST') {
          expect((jsonDecode(request.body) as Map)['locale'], 'zh');
          return jsonResponse(contextJson(locale: 'zh-CN'), 201);
        }
        if (request.url.path.endsWith('/me')) {
          return problem('bootstrap-required', 409);
        }
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LedgerApp)),
    );
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('zh'));
    await tester.pumpAndSettle();
    auth.change('new-session');
    await tester.pumpAndSettle();
    expect(find.text('设置你的账本'), findsOneWidget);
    if (find.byKey(const ValueKey('setup-next')).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('setup-next')));
      await tester.tap(find.byKey(const ValueKey('setup-next')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-space')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('create-space')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-space')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-book')), findsOneWidget);
  });

  testWidgets('timezone edit saves only on confirmation', (tester) async {
    var patches = 0;
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (request.method == 'PATCH') {
          patches++;
          expect(jsonDecode(request.body), {'timezone': 'Europe/London'});
        }
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-timezone')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('choice-search')),
      'Europe/London',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('option-Europe/London')));
    await tester.pumpAndSettle();
    expect(find.textContaining('London · UTC'), findsOneWidget);
    expect(patches, 1);
    await tester.tap(find.byKey(const ValueKey('edit-timezone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(patches, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported server locale displays English without a patch', (
    tester,
  ) async {
    var patches = 0;
    await tester.pumpWidget(
      application(FakeAuth(), (request) async {
        if (request.method == 'PATCH') patches++;
        if (request.url.path.endsWith('/me')) {
          return jsonResponse(contextJson(locale: 'fr-FR'));
        }
        return normalApi(request);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-book')), findsOneWidget);
    expect(patches, 0);
  });

  testWidgets(
    'language adapters follow app choice without replacing the router',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(FakeAuth(configured: false)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LedgerApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(routerProvider);

      container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('zh'));
      await tester.pumpAndSettle();

      expect(container.read(routerProvider), same(router));
    },
  );
}
