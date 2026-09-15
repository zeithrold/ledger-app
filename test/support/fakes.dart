// Test fixtures deliberately contain no real credentials or identities.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ledger_app/core/auth/auth_gateway.dart';

class FakeAuth extends AuthGateway {
  FakeAuth({this.sessionKey = 'session-a', this.configured = true});
  @override
  bool configured;
  @override
  bool loading = false;
  @override
  bool failed = false;
  @override
  String? sessionKey;
  @override
  bool signingIn = false;
  @override
  bool signInFailed = false;
  @override
  Future<void> signIn() async => change('session-a');
  final refreshes = <bool>[];
  bool failSignOut = false;
  @override
  Future<void> initialize() async {
    loading = false;
    failed = false;
    notifyListeners();
  }

  @override
  Future<String> token({bool refresh = false}) async {
    refreshes.add(refresh);
    return refresh ? 'refreshed-test-token' : 'test-token';
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('offline');
    change(null);
  }

  void change(String? session) {
    sessionKey = session;
    notifyListeners();
  }
}

Map<String, dynamic> bookJson({String id = 'book-a'}) => {
  'id': id,
  'tenant_id': 'tenant-a',
  'name': 'Main',
  'base_currency': 'CNY',
};
Map<String, dynamic> contextJson({
  String id = 'user-a',
  String locale = 'en',
  String theme = 'system',
}) => {
  'user': {'id': id, 'display_name': '', 'status': 'active'},
  'instance_role': 'user',
  'tenant': {'id': 'tenant-a', 'name': 'Personal', 'role': 'owner'},
  'default_book': bookJson(),
  'preferences': {
    'locale': locale,
    'timezone': 'Asia/Shanghai',
    'theme': theme,
  },
};
http.Response jsonResponse(Object json, [int status = 200]) => http.Response(
  jsonEncode(json),
  status,
  headers: {'content-type': 'application/json', 'x-request-id': 'request-test'},
);
http.Response problem(String slug, int status) => jsonResponse({
  'type': 'https://ledger.ztd.me/errors/$slug',
  'title': 'Error',
  'detail': 'Test',
  'status': status,
  'instance': 'urn:uuid:test',
}, status);
Future<http.Response> normalApi(http.Request request) async {
  final resource = request.url.path.split('/').last;
  if (['accounts', 'categories', 'counterparties'].contains(resource)) {
    return jsonResponse({resource: <Object>[]});
  }
  if (resource == 'currencies') {
    return jsonResponse({
      'currencies': [
        for (final code in ['USD', 'CNY', 'GBP', 'EUR'])
          {'code': code, 'minor_units': 2},
      ],
    });
  }
  if (resource == 'transactions') {
    return jsonResponse({'transactions': <Object>[], 'links': <Object>[]});
  }
  if (resource == 'summary') {
    return jsonResponse({'totals': <Object>[], 'categories': <Object>[]});
  }
  if (request.url.path.endsWith('/books')) {
    return jsonResponse({
      'books': [bookJson()],
    });
  }
  if (request.url.path.contains('/books/')) return jsonResponse(bookJson());
  if (request.method == 'PATCH') {
    return jsonResponse({
      ...contextJson()['preferences'] as Map<String, dynamic>,
      ...jsonDecode(request.body) as Map<String, dynamic>,
    });
  }
  return jsonResponse(contextJson());
}
