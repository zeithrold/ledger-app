import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledger_app/core/auth/auth_gateway.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/network/ledger_transport.dart';

import 'support/fakes.dart';

LedgerTransport transport(
  Future<http.Response> Function(http.Request) handler, {
  AuthGateway? auth,
}) => LedgerTransport(
  endpoint: Uri.parse('https://example.com/'),
  client: MockClient(handler),
  auth: auth ?? FakeAuth(),
);

void main() {
  test('an empty successful body decodes as an empty object', () async {
    for (final status in [200, 204]) {
      final response = await transport(
        (request) async => http.Response('', status),
      ).request('POST', 'api/v1/example');
      expect(response, isEmpty, reason: 'status $status');
    }
  });

  test('a successful body that is not a JSON object is rejected', () async {
    for (final body in ['not json', '[1,2]']) {
      await expectLater(
        transport(
          (request) async => http.Response(body, 200),
        ).request('GET', 'api/v1/example'),
        throwsA(
          isA<ApiFailure>().having((f) => f.type, 'type', 'invalid-response'),
        ),
        reason: body,
      );
    }
  });

  test('a problem body maps to a typed failure', () async {
    await expectLater(
      transport(
        (request) async => http.Response(
          jsonEncode({
            'type': '${ApiFailure.prefix}accounting-conflict',
            'instance': 'urn:uuid:abc',
            'errors': [
              {'name': 'amount'},
            ],
          }),
          409,
          headers: {'x-request-id': 'request-1'},
        ),
      ).request('POST', 'api/v1/example'),
      throwsA(
        isA<ApiFailure>()
            .having(
              (f) => f.type,
              'type',
              '${ApiFailure.prefix}accounting-conflict',
            )
            .having((f) => f.status, 'status', 409)
            .having((f) => f.requestId, 'requestId', 'request-1')
            .having((f) => f.instance, 'instance', 'urn:uuid:abc')
            .having((f) => f.fields, 'fields', ['amount'])
            .having((f) => f.isType('accounting-conflict'), 'isType', isTrue),
      ),
    );
  });

  test('a request without a session never reaches the network', () async {
    var called = false;
    await expectLater(
      transport((request) async {
        called = true;
        return http.Response('{}', 200);
      }, auth: FakeAuth(sessionKey: null)).request('GET', 'api/v1/example'),
      throwsA(
        isA<ApiFailure>().having(
          (f) => f.type,
          'type',
          '${ApiFailure.prefix}authentication-required',
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('the negotiated contract revision is sent', () async {
    String? sent;
    await transport((request) async {
      sent = request.headers['X-Ledger-API-Version'];
      return http.Response('{}', 200);
    }).request('GET', 'api/v1/example');
    expect(sent, LedgerTransport.version);
  });
}
