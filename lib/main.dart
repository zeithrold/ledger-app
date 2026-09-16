import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/app.dart';
import 'package:ledger_app/app/preferences.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/observability/telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Inter'],
      await rootBundle.loadString('assets/fonts/inter/OFL.txt'),
    );
  });
  var config = const AppConfig.fromEnvironment();
  if (kDebugMode) {
    await dotenv.load(fileName: '.env.local', isOptional: true);
    config = AppConfig.fromDotEnv(dotenv.env);
  }
  validateTelemetryEnvironment(config);
  final app = ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      shellPreferenceOverride,
      shellCurrencyLocaleOverride,
    ],
    child: config.sentryDsn.trim().isEmpty
        ? const LedgerApp()
        : SentryWidget(child: const LedgerApp()),
  );
  if (config.sentryDsn.trim().isEmpty) {
    runApp(app);
    return;
  }
  await SentryFlutter.init(
    (options) => configureTelemetry(options, config),
    appRunner: () => runApp(app),
  );
}
