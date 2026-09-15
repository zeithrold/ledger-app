import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/observability/telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _MemoryTransport implements Transport {
  final events = <Object?>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    events.addAll(envelope.items.map((item) => item.originalObject));
    return envelope.header.eventId;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native initialization and Ledger navigation emit telemetry', (
    tester,
  ) async {
    final transport = _MemoryTransport();
    const config = AppConfig.fromEnvironment(
      sentryDsn: 'https://public@example.invalid/1',
    );
    await SentryFlutter.init((options) {
      configureTelemetry(options, config);
      options
        ..transport = transport
        // Keep native initialization, but never send native sessions in tests.
        ..enableAutoSessionTracking = false
        ..enableNativeCrashHandling = false;
    });
    await tester.pumpWidget(
      SentryWidget(
        child: ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(config)],
          child: const LedgerApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await Sentry.captureException(StateError('offline telemetry verification'));
    await tester.pumpWidget(const SizedBox.shrink());
    await Sentry.close();
    expect(transport.events.whereType<SentryTransaction>(), isNotEmpty);
    expect(
      transport.events.whereType<SentryEvent>().any(
        (event) => event.exceptions?.isNotEmpty ?? false,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
