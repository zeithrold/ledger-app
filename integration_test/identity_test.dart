import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/device_defaults.dart';
import 'package:ledger_app/core/network/http_client.dart';

import '../test/support/fakes.dart';

import '../test/support/select_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native auth channel is registered without using credentials', (
    tester,
  ) async {
    // An unknown method must reach the native handler, not initialize Clerk.
    await expectLater(
      const MethodChannel('ledger/auth').invokeMethod<void>('unsupported'),
      throwsA(isA<MissingPluginException>()),
    );
    // Token access before SDK initialization must be a safe native failure.
    await expectLater(
      const MethodChannel('ledger/auth').invokeMethod<String>('token'),
      throwsA(isA<PlatformException>()),
    );
  });

  testWidgets('legacy credential storage can be removed without other keys', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'ledger.acceptance.old', value: 'fixture');
    expect(await storage.read(key: 'ledger.acceptance.old'), 'fixture');
    await storage.delete(key: 'ledger.acceptance.old');
    expect(await storage.read(key: 'ledger.acceptance.old'), isNull);
  });

  testWidgets('device returns a usable IANA timezone', (tester) async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    final defaults = inferDefaults(
      const Locale('en', 'US'),
      timezone.identifier,
    );
    expect(defaults.usedFallback, isFalse);
    expect(defaults.timezone, timezone.identifier);
  });

  testWidgets('fake login setup books preferences logout on a device', (
    tester,
  ) async {
    final auth = FakeAuth(sessionKey: null);
    var initialized = false;
    var preferences = <String, dynamic>{
      'locale': 'en',
      'timezone': 'UTC',
      'theme': 'system',
    };
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/me') && !initialized) {
        return problem('bootstrap-required', 409);
      }
      if (request.method == 'POST') initialized = true;
      if (request.method == 'PATCH') {
        preferences = {...preferences, 'theme': 'dark'};
        return jsonResponse(preferences);
      }
      return normalApi(request);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig.fromEnvironment(apiBaseUrl: 'https://example.com/'),
          ),
          authGatewayProvider.overrideWithValue(auth),
          httpClientProvider.overrideWithValue(client),
        ],
        child: const LedgerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A little clarity, every day.'), findsOneWidget);
    auth.change('fake-device-session');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('setup-next')));
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-space')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
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
    expect(find.text('Personal space: Personal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('book-book-a')));
    await tester.pumpAndSettle();
    expect(find.text('Book details'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    await chooseSettingsTheme(tester, 'dark');
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('settings-appearance'))),
      ).brightness,
      Brightness.dark,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sign-out')),
      150,
    );
    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-tab')));
    await tester.pumpAndSettle();
    expect(find.text('A little clarity, every day.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    client.close();
  });
}
