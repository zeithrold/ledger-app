import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public client configuration from Dart Define and local `.env.local`.
/// Backend secrets must never be embedded in a mobile application.
class AppConfig {
  /// Reads build-time values. Empty values keep integrations disabled.
  const AppConfig.fromEnvironment({
    this.environment = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'stage',
    ),
    this.apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.clerkPublishableKey = const String.fromEnvironment(
      'CLERK_PUBLISHABLE_KEY',
    ),
    this.clerkApiEndpoint = const String.fromEnvironment('CLERK_API_ENDPOINT'),
    this.sentryDsn = const String.fromEnvironment('SENTRY_DSN'),
  });

  /// Resolves explicit build defines before local values, including empty ones.
  factory AppConfig.fromDotEnv(
    Map<String, String> values, {
    Map<String, String>? defines,
  }) {
    final overrides =
        defines ??
        {
          if (const bool.hasEnvironment('APP_ENV'))
            'APP_ENV': const String.fromEnvironment('APP_ENV'),
          if (const bool.hasEnvironment('API_BASE_URL'))
            'API_BASE_URL': const String.fromEnvironment('API_BASE_URL'),
          if (const bool.hasEnvironment('CLERK_PUBLISHABLE_KEY'))
            'CLERK_PUBLISHABLE_KEY': const String.fromEnvironment(
              'CLERK_PUBLISHABLE_KEY',
            ),
          if (const bool.hasEnvironment('CLERK_API_ENDPOINT'))
            'CLERK_API_ENDPOINT': const String.fromEnvironment(
              'CLERK_API_ENDPOINT',
            ),
          if (const bool.hasEnvironment('SENTRY_DSN'))
            'SENTRY_DSN': const String.fromEnvironment('SENTRY_DSN'),
        };
    String resolve(String key) => overrides[key] ?? values[key] ?? '';
    return AppConfig.fromEnvironment(
      environment: overrides['APP_ENV'] ?? values['APP_ENV'] ?? 'stage',
      apiBaseUrl: resolve('API_BASE_URL'),
      clerkPublishableKey: resolve('CLERK_PUBLISHABLE_KEY'),
      clerkApiEndpoint: resolve('CLERK_API_ENDPOINT'),
      sentryDsn: resolve('SENTRY_DSN'),
    );
  }

  /// Deployment environment, independent of Flutter build mode.
  final String environment;

  /// Deployment-configured API base URL; users cannot edit it in the app.
  final String apiBaseUrl;

  /// Public Clerk publishable key; never a backend secret key.
  final String clerkPublishableKey;

  /// Optional public Clerk origin; must match the publishable key host.
  final String clerkApiEndpoint;

  /// An empty DSN disables Sentry initialization.
  final String sentryDsn;
}

/// Public client configuration, overridable without real services in tests.
final appConfigProvider = Provider<AppConfig>((ref) {
  return const AppConfig.fromEnvironment();
});
