import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Lazily creates a client owned by the current endpoint configuration.
/// Switching endpoints disposes the previous client. Identity owns requests.
/// Consumers can override this provider with a fake client in tests.
final httpClientProvider = Provider<http.Client>((ref) {
  final endpoint = ref.watch(apiEndpointProvider);
  if (endpoint == null) throw StateError('API_BASE_URL is missing or invalid');
  final enabled = ref.watch(appConfigProvider).sentryDsn.trim().isNotEmpty;
  final client = enabled
      ? SentryHttpClient(captureFailedRequests: false)
      : http.Client();
  ref.onDispose(client.close);
  return client;
});
