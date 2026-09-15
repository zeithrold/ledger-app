import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/observability/telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _MemoryTransport implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }
}

void main() {
  for (final environment in ['stage', 'production']) {
    test('$environment follows Go sampling and privacy policy', () {
      final options = SentryFlutterOptions();
      configureTelemetry(
        options,
        AppConfig.fromEnvironment(environment: environment),
      );
      final rate = environment == 'stage' ? 1.0 : 0.5;
      expect(options.environment, environment);
      expect(options.isTracingEnabled(), isTrue);
      expect(options.tracesSampleRate, rate);
      expect(
        options.tracesSampler!(
          SentrySamplingContext.forTransaction(
            SentryTransactionContext(
              'test',
              'test',
              parentSamplingDecision: SentryTracesSamplingDecision(false),
            ),
          ),
        ),
        rate,
      );
      expect(options.sampleRate, 1);
      expect(options.sendDefaultPii, isFalse);
      expect(options.attachStacktrace, isTrue);
    });
  }

  test('environment defaults, define precedence and validation', () {
    expect(AppConfig.fromDotEnv({}, defines: {}).environment, 'stage');
    expect(
      AppConfig.fromDotEnv(
        {'APP_ENV': 'production'},
        defines: {'APP_ENV': 'stage'},
      ).environment,
      'stage',
    );
    expect(
      () => validateTelemetryEnvironment(
        const AppConfig.fromEnvironment(environment: 'typo'),
      ),
      throwsFormatException,
    );
  });

  test('HTTP spans reach transport and headers only reach the API', () async {
    final transport = _MemoryTransport();
    final options = SentryFlutterOptions();
    configureTelemetry(
      options,
      const AppConfig.fromEnvironment(
        sentryDsn: 'https://public@example.invalid/1',
        apiBaseUrl: 'https://api.example.test',
      ),
    );
    options.transport = transport;
    final hub = Hub(options);
    addTearDown(hub.close);
    final requests = <http.Request>[];
    final client = SentryHttpClient(
      hub: hub,
      captureFailedRequests: false,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    final transaction = hub.startTransaction(
      'home',
      'navigation',
      bindToScope: true,
    );
    await client.get(
      Uri.parse('https://api.example.test/api/v1/me?token=secret'),
    );
    await client.get(Uri.parse('https://api.example.test.evil.test/'));
    await transaction.finish();
    expect(requests.first.headers['sentry-trace'], isNotNull);
    expect(requests.first.headers['baggage'], isNotNull);
    expect(requests.last.headers['sentry-trace'], isNull);
    expect(requests.last.headers['baggage'], isNull);
    expect(transport.envelopes, isNotEmpty);
    final event =
        transport.envelopes.last.items.first.originalObject!
            as SentryTransaction;
    expect(
      event.spans.where((span) => span.toJson()['op'] == 'http.client'),
      hasLength(2),
    );
    expect(event.spans.first.data.containsKey('http.query'), isFalse);
    expect(event.toJson().toString(), isNot(contains('secret')));
  });
}
