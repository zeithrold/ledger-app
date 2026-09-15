import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/core/config/app_config.dart';

void main() {
  test('dotenv values populate client configuration', () {
    final env = DotEnv()
      ..loadFromString(
        envString: '''
API_BASE_URL=https://api.example.test
CLERK_API_ENDPOINT=https://clerk.example.test
CLERK_PUBLISHABLE_KEY=pk_test_example
SENTRY_DSN=https://public@example.test/1
''',
      );
    final config = AppConfig.fromDotEnv(env.env, defines: {});
    expect(config.apiBaseUrl, 'https://api.example.test');
    expect(config.clerkApiEndpoint, 'https://clerk.example.test');
    expect(config.clerkPublishableKey, 'pk_test_example');
    expect(config.sentryDsn, 'https://public@example.test/1');
  });

  test('empty configuration leaves integrations disabled', () {
    final env = DotEnv()..loadFromString(isOptional: true);
    final config = AppConfig.fromDotEnv(env.env, defines: {});
    expect(config.sentryDsn, isEmpty);
    expect(config.apiBaseUrl, isEmpty);
    expect(config.clerkApiEndpoint, isEmpty);
    expect(config.clerkPublishableKey, isEmpty);
  });

  test('explicit defines override local values and can disable Sentry', () {
    final config = AppConfig.fromDotEnv(
      {
        'API_BASE_URL': 'https://local.example.test',
        'CLERK_API_ENDPOINT': 'https://local.clerk.example.test',
        'CLERK_PUBLISHABLE_KEY': 'pk_test_example',
        'SENTRY_DSN': 'https://public@example.test/1',
      },
      defines: {
        'API_BASE_URL': 'https://override.example.test',
        'CLERK_API_ENDPOINT': 'https://override.clerk.example.test',
        'SENTRY_DSN': '',
      },
    );
    expect(config.apiBaseUrl, 'https://override.example.test');
    expect(config.sentryDsn, isEmpty);
    expect(config.clerkApiEndpoint, 'https://override.clerk.example.test');
    expect(config.clerkPublishableKey, 'pk_test_example');
  });
}
