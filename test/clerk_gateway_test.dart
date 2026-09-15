import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ledger/auth-test');
  final config = AppConfig.fromEnvironment(
    clerkPublishableKey:
        'pk_test_${base64Encode(utf8.encode(r'example.clerk.accounts.dev$'))}',
  );
  late StreamController<Object?> events;
  late ClerkGateway gateway;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall) handler;
  Map<String, Object?> snapshot(
    int revision, {
    bool active = true,
    String session = 's1',
  }) => {
    'revision': revision,
    'active': active,
    'userId': 'u1',
    'sessionId': session,
  };
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ledger.clerk.old': 'retired',
      'unrelated': 'keep',
    });
    calls = [];
    events = StreamController<Object?>.broadcast(sync: true);
    handler = (call) async => switch (call.method) {
      'initialize' => snapshot(1, active: false),
      'signIn' => snapshot(2),
      'signOut' => snapshot(3, active: false),
      'token' => 'fixture-jwt',
      _ => null,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
    gateway = ClerkGateway(config, channel: channel, events: events.stream);
  });
  tearDown(() async {
    gateway.dispose();
    await events.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'initialization cleans retired credentials; login activates session',
    () async {
      await gateway.initialize();
      expect(gateway.failed, isFalse);
      expect(await const FlutterSecureStorage().readAll(), {
        'unrelated': 'keep',
      });
      expect(gateway.sessionKey, isNull);
      await gateway.signIn();
      expect(gateway.sessionKey, 'u1:s1');
      expect(await gateway.token(refresh: true), 'fixture-jwt');
      expect(calls.last.arguments, {'refresh': true});
      await gateway.signOut();
      expect(gateway.sessionKey, isNull);
    },
  );
  test(
    'SDK snapshot restores only active sessions',
    () async {
      handler = (_) async => snapshot(1);
      await gateway.initialize();
      expect(gateway.sessionKey, 'u1:s1');
      events.add(snapshot(2, active: false));
      expect(gateway.sessionKey, isNull);
    },
  );
  test(
    'cancellation, retry and duplicate login handling',
    () async {
      await gateway.initialize();
      final pending = Completer<Object?>();
      handler = (_) => pending.future;
      final first = gateway.signIn();
      await gateway.signIn();
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((call) => call.method == 'signIn').length, 1);
      expect(gateway.signingIn, isTrue);
      pending.completeError(PlatformException(code: 'cancelled'));
      await first;
      expect(gateway.signInFailed, isFalse);
      expect(gateway.signingIn, isFalse);
      handler = (_) async => throw PlatformException(code: 'network');
      await gateway.signIn();
      expect(gateway.signInFailed, isTrue);
      handler = (_) async => snapshot(3);
      await gateway.signIn();
      expect(gateway.signInFailed, isFalse);
      expect(gateway.sessionKey, 'u1:s1');
    },
  );
  test(
    'late snapshots and token responses cannot restore an old account',
    () async {
      await gateway.initialize();
      events
        ..add(snapshot(4))
        ..add(snapshot(3, active: false));
      expect(gateway.sessionKey, 'u1:s1');
      final token = Completer<Object?>();
      handler = (_) => token.future;
      final request = gateway.token();
      events.add(snapshot(5, session: 's2'));
      token.complete('old-token');
      await expectLater(request, throwsA(isA<ApiFailure>()));
      expect(gateway.sessionKey, 'u1:s2');
    },
  );
  test(
    'failed sign-out retains session and initialization can retry',
    () async {
      handler = (_) async => throw PlatformException(code: 'offline');
      await gateway.initialize();
      expect(gateway.failed, isTrue);
      handler = (_) async => snapshot(1);
      await gateway.initialize();
      expect(gateway.failed, isFalse);
      expect(gateway.sessionKey, 'u1:s1');
      handler = (_) async => throw PlatformException(code: 'offline');
      await expectLater(gateway.signOut(), throwsA(isA<ApiFailure>()));
      expect(gateway.sessionKey, 'u1:s1');
    },
  );
  test('disposal ignores pending callbacks', () async {
    await gateway.initialize();
    final pending = Completer<Object?>();
    handler = (_) => pending.future;
    final operation = gateway.signIn();
    gateway.dispose();
    pending.complete(snapshot(9));
    await operation;
    expect(gateway.sessionKey, isNull);
    // Avoid disposing the same ChangeNotifier twice in the shared teardown.
    gateway = ClerkGateway(config, channel: channel, events: events.stream);
  });
}
