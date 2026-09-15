// Internal contract members are documented by their owning boundary.
// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ledger_app/core/auth/auth_gateway.dart';
import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/models.dart';

/// Validates the public key and optional matching frontend endpoint.
String clerkHost(AppConfig config) {
  final key = config.clerkPublishableKey.trim();
  if (!key.startsWith('pk_test_') && !key.startsWith('pk_live_')) {
    throw const FormatException('Invalid publishable key');
  }
  final decoded = utf8.decode(
    base64.decode(base64.normalize(key.substring(8))),
  );
  if (!decoded.endsWith(r'$')) {
    throw const FormatException('Invalid publishable key');
  }
  final host = decoded.substring(0, decoded.length - 1);
  final uri = Uri.tryParse('https://$host');
  if (uri == null ||
      uri.host != host ||
      !host.contains('.') ||
      uri.hasPort ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid Clerk host');
  }
  if (config.clerkApiEndpoint.trim().isNotEmpty) {
    final explicit = parseApiEndpoint(config.clerkApiEndpoint);
    if (explicit.toString() != 'https://$host/') {
      throw const FormatException(
        'Clerk endpoint does not match the publishable key',
      );
    }
  }
  return host;
}

/// Native SDKs own all credentials, browser challenges and session persistence.
class ClerkGateway extends AuthGateway {
  ClerkGateway(
    this.config, {
    MethodChannel channel = const MethodChannel('ledger/auth'),
    Stream<dynamic>? events,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _channel = channel,
       _events = events,
       _storage = storage {
    try {
      clerkHost(config);
      configured = true;
    } on Object {
      configured = false;
    }
  }
  final AppConfig config;
  final MethodChannel _channel;
  final Stream<dynamic>? _events;
  final FlutterSecureStorage _storage;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;
  int _revision = -1;
  @override
  late final bool configured;
  @override
  bool loading = false;
  @override
  bool failed = false;
  @override
  bool signingIn = false;
  @override
  bool signInFailed = false;
  @override
  String? sessionKey;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _accept(dynamic data) {
    if (_disposed || data is! Map) return;
    final revision = data['revision'];
    if (revision is! int || revision < _revision) return;
    _revision = revision;
    final user = data['userId'];
    final session = data['sessionId'];
    sessionKey =
        data['active'] == true &&
            user is String &&
            session is String &&
            user.isNotEmpty &&
            session.isNotEmpty
        ? '$user:$session'
        : null;
    _changed();
  }

  @override
  Future<void> initialize() async {
    if (!configured || loading || _disposed) return;
    loading = true;
    failed = false;
    _changed();
    try {
      // Delete only the retired Flutter SDK namespace, never other app secrets.
      for (final key in (await _storage.readAll()).keys.toList()) {
        if (key.startsWith('ledger.clerk.')) await _storage.delete(key: key);
      }
      if (_disposed) return;
      _subscription ??=
          (_events ??
                  const EventChannel(
                    'ledger/auth/events',
                  ).receiveBroadcastStream())
              .listen(
                _accept,
                onError: (Object _) {
                  failed = true;
                  _changed();
                },
              );
      _accept(
        await _channel
            .invokeMethod<Object?>('initialize', {
              'publishableKey': config.clerkPublishableKey.trim(),
            })
            .timeout(const Duration(seconds: 25)),
      );
    } on Object {
      failed = true;
    } finally {
      loading = false;
      _changed();
    }
  }

  @override
  Future<void> signIn() async {
    if (signingIn || loading || failed || !configured || _disposed) return;
    signingIn = true;
    signInFailed = false;
    _changed();
    try {
      _accept(await _channel.invokeMethod<Object?>('signIn'));
    } on PlatformException catch (error) {
      signInFailed = error.code != 'cancelled';
    } on Object {
      signInFailed = true;
    } finally {
      signingIn = false;
      _changed();
    }
  }

  @override
  Future<String> token({bool refresh = false}) async {
    final session = sessionKey;
    if (session == null) {
      throw const ApiFailure('authentication-required', status: 401);
    }
    try {
      final token = await _channel
          .invokeMethod<String>('token', {'refresh': refresh})
          .timeout(const Duration(seconds: 20));
      if (_disposed || sessionKey != session) {
        throw const ApiFailure('session-changed');
      }
      if (token == null || token.isEmpty) {
        throw const ApiFailure('authentication-error', status: 401);
      }
      return token;
    } on PlatformException {
      throw const ApiFailure('authentication-error', status: 401);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      _accept(
        await _channel
            .invokeMethod<Object?>('signOut')
            .timeout(const Duration(seconds: 20)),
      );
      if (sessionKey != null) throw const ApiFailure('signout-error');
    } on PlatformException {
      throw const ApiFailure('signout-error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final authGatewayProvider = Provider<AuthGateway>((ref) {
  final gateway = ClerkGateway(ref.watch(appConfigProvider));
  ref.onDispose(gateway.dispose);
  if (ref.watch(apiEndpointProvider) != null) {
    scheduleMicrotask(gateway.initialize);
  }
  return gateway;
});
