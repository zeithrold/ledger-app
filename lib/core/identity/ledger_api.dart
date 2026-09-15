// Internal contract members are documented by their owning boundary.
// ignore_for_file: public_member_api_docs
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/network/ledger_transport.dart';

/// Small typed client for the current identity contract.
class LedgerApi extends LedgerTransport {
  LedgerApi({
    required super.endpoint,
    required super.client,
    required super.auth,
  });
  static const String version = LedgerTransport.version;

  Future<T> _decode<T>(
    Future<Map<String, dynamic>> response,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final data = await response;
    try {
      return decode(data);
    } on Object {
      throw const ApiFailure('invalid-response');
    }
  }

  Future<PersonalContext> me() =>
      _decode(request('GET', 'me'), PersonalContext.fromJson);
  Future<PersonalContext> bootstrap(BootstrapInput input) => _decode(
    request('POST', 'bootstrap', input.toJson()),
    PersonalContext.fromJson,
  );
  Future<List<Book>> books() => _decode(
    request('GET', 'books'),
    (json) => (json['books'] as List)
        .map((value) => Book.fromJson(value as Map<String, dynamic>))
        .toList(),
  );
  Future<Book> book(String id) => _decode(
    request('GET', 'books/${Uri.encodeComponent(id)}'),
    Book.fromJson,
  );
  Future<Preferences> preferences(Map<String, String> patch) =>
      _decode(request('PATCH', 'me/preferences', patch), Preferences.fromJson);
}
