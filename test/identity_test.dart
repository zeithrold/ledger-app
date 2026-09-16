import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/app_config.dart';
import 'package:ledger_app/core/identity/device_defaults.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/ledger_api.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'support/fakes.dart';

void main() {
  test('headers and base paths match the versioned contract', () async {
    final auth = FakeAuth();
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.com/prefix/api/v1/me');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['X-Ledger-API-Version'], LedgerApi.version);
      expect(request.followRedirects, isFalse);
      return jsonResponse(contextJson());
    });
    final api = LedgerApi(
      endpoint: Uri.parse('https://example.com/prefix/'),
      client: client,
      auth: auth,
    );
    final context = await api.me();
    expect(context.defaultBook.baseCurrency, 'CNY');
    expect(context.tenantRole, 'owner');
    expect(context.userStatus, 'active');
  });
  for (final succeeds in [true, false]) {
    test('401 refreshes at most once, success=$succeeds', () async {
      final auth = FakeAuth();
      var calls = 0;
      final api = LedgerApi(
        endpoint: Uri.parse('https://example.com/'),
        auth: auth,
        client: MockClient((request) async {
          calls++;
          if (calls == 1 || !succeeds) return problem('invalid-token', 401);
          expect(
            request.headers['Authorization'],
            'Bearer refreshed-test-token',
          );
          return jsonResponse(contextJson());
        }),
      );
      if (succeeds) {
        await api.me();
      } else {
        await expectLater(
          api.me(),
          throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
        );
      }
      expect(calls, 2);
      expect(auth.refreshes, [false, true]);
    });
  }
  test(
    'rejects malformed success, handles non-JSON proxy failure safely',
    () async {
      var status = 200;
      final api = LedgerApi(
        endpoint: Uri.parse('https://example.com/'),
        auth: FakeAuth(),
        client: MockClient(
          (_) async => http.Response('private proxy content', status),
        ),
      );
      await expectLater(
        api.me(),
        throwsA(
          isA<ApiFailure>().having((e) => e.type, 'type', 'invalid-response'),
        ),
      );
      status = 502;
      await expectLater(
        api.me(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.toString().contains('private'),
            'safe error',
            false,
          ),
        ),
      );
    },
  );
  test('all endpoint methods and patch payloads match the contract', () async {
    final paths = <String>[];
    final api = LedgerApi(
      endpoint: Uri.parse('https://example.com/'),
      auth: FakeAuth(),
      client: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'base_currency': 'CNY',
            'timezone': 'Asia/Shanghai',
            'locale': 'zh-CN',
          });
          return jsonResponse(contextJson(), 201);
        }
        return normalApi(request);
      }),
    );
    await api.bootstrap(
      const BootstrapInput(
        baseCurrency: 'CNY',
        timezone: 'Asia/Shanghai',
        locale: 'zh-CN',
      ),
    );
    expect((await api.books()).single.id, 'book-a');
    expect((await api.book('book-a')).name, 'Main');
    expect((await api.preferences({'theme': 'dark'})).theme, 'dark');
    expect(paths, [
      'POST /api/v1/bootstrap',
      'GET /api/v1/books',
      'GET /api/v1/books/book-a',
      'PATCH /api/v1/me/preferences',
    ]);
  });
  test(
    'problem types are compared as full URIs and retain correlation',
    () async {
      final api = LedgerApi(
        endpoint: Uri.parse('https://example.com/'),
        auth: FakeAuth(),
        client: MockClient((_) async => problem('user-disabled', 403)),
      );
      await expectLater(
        api.me(),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.isType('user-disabled'), 'disabled', true)
              .having((e) => e.requestId, 'reference', 'request-test'),
        ),
      );
      expect(
        const ApiFailure(
          'https://other.example/user-disabled',
        ).isType('user-disabled'),
        isFalse,
      );
    },
  );
  test('device defaults use region and fail visibly to USD/UTC', () {
    expect(
      inferDefaults(const Locale('zh', 'CN'), 'Asia/Shanghai').currency,
      'CNY',
    );
    expect(
      inferDefaults(const Locale('en', 'GB'), 'Europe/London').currency,
      'GBP',
    );
    final fallback = inferDefaults(const Locale('en'), 'Local');
    expect(fallback.currency, 'USD');
    expect(fallback.timezone, 'UTC');
    expect(fallback.usedFallback, isTrue);
    expect(
      inferDefaults(const Locale('en', 'US'), 'America/New_York').usedFallback,
      isFalse,
    );
  });
  test('Clerk endpoint must agree with the publishable key host', () {
    final key =
        'pk_test_${base64Encode(utf8.encode(r'example.clerk.accounts.dev$'))}';
    expect(
      clerkHost(AppConfig.fromEnvironment(clerkPublishableKey: key)),
      'example.clerk.accounts.dev',
    );
    expect(
      () => clerkHost(
        AppConfig.fromEnvironment(
          clerkPublishableKey: key,
          clerkApiEndpoint: 'https://other.example',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => clerkHost(
        const AppConfig.fromEnvironment(clerkPublishableKey: 'sk_test_secret'),
      ),
      throwsFormatException,
    );
  });
  test(
    'identity bootstrap is explicit and errors retain onboarding state',
    () async {
      final auth = FakeAuth();
      var posts = 0;
      final identity = controller(auth, (request) async {
        if (request.method == 'GET') return problem('bootstrap-required', 409);
        posts++;
        return posts == 1
            ? problem('invalid-request', 400)
            : jsonResponse(contextJson(), 201);
      });
      addTearDown(identity.dispose);
      await flush();
      expect(identity.phase, IdentityPhase.onboarding);
      expect(posts, 0);
      const input = BootstrapInput(
        baseCurrency: 'CNY',
        timezone: 'Asia/Shanghai',
        locale: 'en',
      );
      await identity.bootstrap(input);
      expect(identity.phase, IdentityPhase.onboarding);
      expect(identity.saving, isFalse);
      await identity.bootstrap(input);
      expect(identity.phase, IdentityPhase.ready);
      expect(posts, 2);
    },
  );
  test(
    'preference saves serialize and apply only successful responses',
    () async {
      final auth = FakeAuth();
      final pending = Completer<http.Response>();
      var calls = 0;
      Preferences? applied;
      final identity = controller(auth, (request) async {
        if (request.method == 'PATCH') {
          calls++;
          return pending.future;
        }
        return jsonResponse(contextJson());
      }, apply: (value) => applied = value);
      addTearDown(identity.dispose);
      await flush();
      final first = identity.savePreferences({'theme': 'dark'});
      await identity.savePreferences({'locale': 'zh-CN'});
      await flush();
      expect(calls, 1);
      expect(applied!.theme, 'system');
      pending.complete(problem('invalid-request', 400));
      await first;
      expect(applied!.theme, 'system');
      expect(identity.context!.preferences.theme, 'system');
      expect(identity.saving, isFalse);
    },
  );
  test('switching account during me discards the old response', () async {
    final auth = FakeAuth();
    final first = Completer<http.Response>();
    var calls = 0;
    final identity = controller(auth, (_) async {
      calls++;
      return calls == 1
          ? first.future
          : jsonResponse(contextJson(id: 'user-b'));
    });
    addTearDown(identity.dispose);
    await flush();
    auth.change('session-b');
    await flush();
    expect(identity.context!.userId, 'user-b');
    first.complete(jsonResponse(contextJson()));
    await flush();
    expect(identity.context!.userId, 'user-b');
  });
  test(
    'signout clears pending preference responses and resets display',
    () async {
      final auth = FakeAuth();
      final pending = Completer<http.Response>();
      var resets = 0;
      final identity = controller(
        auth,
        (request) async => request.method == 'PATCH'
            ? pending.future
            : jsonResponse(contextJson()),
        reset: () => resets++,
      );
      addTearDown(identity.dispose);
      await flush();
      final saving = identity.savePreferences({'theme': 'dark'});
      await flush();
      await identity.signOut();
      pending.complete(
        jsonResponse({'locale': 'zh-CN', 'timezone': 'UTC', 'theme': 'dark'}),
      );
      await saving;
      expect(identity.context, isNull);
      expect(identity.phase, IdentityPhase.signedOut);
      expect(resets, greaterThan(0));
    },
  );
  test(
    'SDK notifications do not repeatedly bootstrap or retry disabled accounts',
    () async {
      final auth = FakeAuth();
      var calls = 0;
      final identity = controller(auth, (_) async {
        calls++;
        return problem('user-disabled', 403);
      });
      addTearDown(identity.dispose);
      await flush();
      auth.change('session-a');
      await flush();
      expect(calls, 1);
      expect(identity.phase, IdentityPhase.error);
    },
  );
}

IdentityController controller(
  FakeAuth auth,
  Future<http.Response> Function(http.Request) handler, {
  void Function(Preferences)? apply,
  VoidCallback? reset,
}) => IdentityController(
  auth: auth,
  api: LedgerApi(
    endpoint: Uri.parse('https://example.com/'),
    client: MockClient(handler),
    auth: auth,
  ),
  preferences: PreferenceApplier(
    apply: apply ?? (_) {},
    reset: reset ?? () {},
  ),
);
Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 10));
