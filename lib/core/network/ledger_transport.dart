// The shared boundary owns authentication, bounded refresh and session
// isolation.
// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ledger_app/core/auth/auth_gateway.dart';
import 'package:ledger_app/core/identity/models.dart';

class LedgerTransport {
  LedgerTransport({
    required this.endpoint,
    required this.client,
    required this.auth,
  });
  static const version = '2026-09-16';
  final Uri endpoint;
  final http.Client client;
  final AuthGateway auth;
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  ]) async {
    final session = auth.sessionKey;
    if (session == null) {
      throw const ApiFailure(
        '${ApiFailure.prefix}authentication-required',
        status: 401,
      );
    }
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = await auth
            .token(refresh: attempt == 1)
            .timeout(const Duration(seconds: 20));
        if (auth.sessionKey != session) {
          throw const ApiFailure('session-changed');
        }
        final request =
            http.Request(
                method,
                endpoint
                    .resolve('api/v1/$path')
                    .replace(queryParameters: query),
              )
              ..followRedirects = false
              ..headers.addAll({
                'Authorization': 'Bearer $token',
                'X-Ledger-API-Version': version,
                'Accept': 'application/json',
              });
        if (idempotencyKey != null) {
          request.headers['Idempotency-Key'] = idempotencyKey;
        }
        if (body != null) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        final response = await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 20));
        if (auth.sessionKey != session) {
          throw const ApiFailure('session-changed');
        }
        if (response.statusCode == 401 && attempt == 0) continue;
        Map<String, dynamic>? json;
        try {
          json = jsonDecode(response.body) as Map<String, dynamic>;
        } on Object {
          /* Proxy errors may not be JSON. */
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (json == null) throw const ApiFailure('invalid-response');
          return json;
        }
        throw ApiFailure(
          json?['type'] is String ? json!['type'] as String : 'http-error',
          status: response.statusCode,
          requestId: response.headers['x-request-id'],
          instance: json?['instance'] is String
              ? json!['instance'] as String
              : null,
          fields: json?['errors'] is List
              ? (json!['errors'] as List)
                    .whereType<Map<String, dynamic>>()
                    .map((e) => e['name'])
                    .whereType<String>()
                    .toList()
              : const [],
        );
      }
    } on ApiFailure {
      rethrow;
    } on Object {
      throw const ApiFailure('network-error');
    }
    throw const ApiFailure('invalid-response');
  }
}
