import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(
    Platform.environment['LEDGER_VISUAL_OUTPUT'] ?? 'build/ui-captures',
  );
  await output.create(recursive: true);
  HttpServer? captureServer;
  final capturePort = Platform.environment['LEDGER_NATIVE_CAPTURE_PORT'];
  if (capturePort != null) {
    final device = Platform.environment['LEDGER_NATIVE_CAPTURE_DEVICE']!;
    final platform = Platform.environment['LEDGER_NATIVE_CAPTURE_PLATFORM']!;
    captureServer =
        (await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          int.parse(capturePort),
        ))..listen((request) async {
          try {
            final name = request.uri.queryParameters['name'] ?? '';
            if (!RegExp(r'^accounting-[a-z0-9-]+$').hasMatch(name)) {
              throw StateError('Invalid capture name.');
            }
            final path = '${output.path}/$name-native.png';
            if (platform == 'ios') {
              final result = await Process.run('xcrun', [
                'simctl',
                'io',
                device,
                'screenshot',
                path,
              ]);
              if (result.exitCode != 0) throw StateError('${result.stderr}');
            } else if (platform == 'android') {
              final result = await Process.run(
                Platform.environment['LEDGER_ADB'] ?? 'adb',
                ['-s', device, 'exec-out', 'screencap', '-p'],
                stdoutEncoding: null,
              );
              if (result.exitCode != 0) throw StateError('${result.stderr}');
              await File(path).writeAsBytes(result.stdout as List<int>);
            } else {
              throw StateError('Unknown native capture platform.');
            }
            request.response.write('captured');
          } on Object catch (error) {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write(error);
          } finally {
            await request.response.close();
          }
        });
  }
  try {
    await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        await File('${output.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
    );
  } finally {
    await captureServer?.close(force: true);
  }
}
