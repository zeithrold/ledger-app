import 'package:integration_test/integration_test.dart';

import '../test/session_recovery_test.dart' as regression;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regression.sessionRecoveryTests(
    nativeSurface: true,
    capture: (name) async {
      if (const bool.fromEnvironment('CAPTURE_VISUALS')) {
        await binding.takeScreenshot(name);
      }
    },
  );
}
