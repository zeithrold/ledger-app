import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Matches the backend's deployment environment contract.
void validateTelemetryEnvironment(AppConfig config) {
  if (!{'stage', 'production'}.contains(config.environment)) {
    throw const FormatException('APP_ENV must be stage or production');
  }
}

/// Configures SDK sampling without initializing a client or sending events.
void configureTelemetry(SentryFlutterOptions options, AppConfig config) {
  validateTelemetryEnvironment(config);
  final rate = config.environment == 'production' ? 0.5 : 1.0;
  options
    ..dsn = config.sentryDsn.trim()
    ..environment = config.environment
    ..sampleRate = 1.0
    ..tracesSampleRate = rate
    // Like Go, the deployment policy takes precedence over parent sampling.
    ..tracesSampler = ((_) => rate)
    ..attachStacktrace = true
    ..sendDefaultPii = false
    ..recordHttpBreadcrumbs = false
    ..beforeSend = (event, hint) {
      event.request = null;
      return event;
    }
    ..beforeSendTransaction = (transaction, hint) {
      transaction.request = null;
      for (final span in transaction.spans) {
        span.data.remove('http.query');
        span.data.remove('http.fragment');
      }
      return transaction;
    };
  // Only propagate trace headers to the configured Ledger API.
  options.tracePropagationTargets.clear();
  try {
    final endpoint = parseApiEndpoint(config.apiBaseUrl);
    options.tracePropagationTargets.add(
      '^${RegExp.escape(endpoint.origin)}(?:/|\$)',
    );
  } on FormatException {
    // Invalid endpoint configuration already disables the API client.
  }
}
