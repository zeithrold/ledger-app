import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/core/config/app_config.dart';

/// Parses an absolute HTTP(S) server base URL without credentials or suffixes.
/// Base paths are supported and normalized with a trailing slash.
Uri parseApiEndpoint(String input) {
  final value = input.trim();
  if (value.isEmpty || RegExp(r'[\s\\]').hasMatch(value)) {
    throw const FormatException('Invalid API endpoint');
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port < 1 ||
      uri.port > 65535 ||
      uri.host.contains('%')) {
    throw const FormatException('Invalid API endpoint');
  }
  final normalized = uri.normalizePath().toString().replaceFirst(
    RegExp(r'/+$'),
    '',
  );
  return Uri.parse('$normalized/');
}

/// Read-only runtime endpoint derived from public app configuration.
/// Missing or malformed configuration disables network client creation.
final apiEndpointProvider = Provider<Uri?>((ref) {
  final value = ref.watch(appConfigProvider).apiBaseUrl;
  try {
    return parseApiEndpoint(value);
  } on FormatException {
    return null;
  }
});
