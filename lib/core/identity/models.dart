// Internal contract members are documented by their owning boundary.
// ignore_for_file: public_member_api_docs

/// Typed wire models for the 2026-09-16 identity contract.
class Book {
  const Book({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.baseCurrency,
  });
  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    tenantId: json['tenant_id'] as String,
    name: json['name'] as String,
    baseCurrency: json['base_currency'] as String,
  );
  final String id;
  final String tenantId;
  final String name;
  final String baseCurrency;
}

class Preferences {
  const Preferences({
    required this.locale,
    required this.timezone,
    required this.theme,
  });
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    locale: json['locale'] as String,
    timezone: json['timezone'] as String,
    theme: json['theme'] as String,
  );
  final String locale;
  final String timezone;
  final String theme;
}

class PersonalContext {
  const PersonalContext({
    required this.userId,
    required this.displayName,
    required this.userStatus,
    required this.instanceRole,
    required this.tenantId,
    required this.tenantName,
    required this.tenantRole,
    required this.defaultBook,
    required this.preferences,
  });
  factory PersonalContext.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final tenant = json['tenant'] as Map<String, dynamic>;
    return PersonalContext(
      userId: user['id'] as String,
      displayName: user['display_name'] as String,
      userStatus: user['status'] as String,
      instanceRole: json['instance_role'] as String,
      tenantId: tenant['id'] as String,
      tenantName: tenant['name'] as String,
      tenantRole: tenant['role'] as String,
      defaultBook: Book.fromJson(json['default_book'] as Map<String, dynamic>),
      preferences: Preferences.fromJson(
        json['preferences'] as Map<String, dynamic>,
      ),
    );
  }
  final String userId;
  final String displayName;
  final String userStatus;
  final String instanceRole;
  final String tenantId;
  final String tenantName;
  final String tenantRole;
  final Book defaultBook;
  final Preferences preferences;
  PersonalContext withPreferences(Preferences value) => PersonalContext(
    userId: userId,
    displayName: displayName,
    userStatus: userStatus,
    instanceRole: instanceRole,
    tenantId: tenantId,
    tenantName: tenantName,
    tenantRole: tenantRole,
    defaultBook: defaultBook,
    preferences: value,
  );
}

class BootstrapInput {
  const BootstrapInput({
    required this.baseCurrency,
    required this.timezone,
    required this.locale,
  });
  final String baseCurrency;
  final String timezone;
  final String locale;
  Map<String, String> toJson() => {
    'base_currency': baseCurrency,
    'timezone': timezone,
    'locale': locale,
  };
}

/// Sanitized error: raw responses and credentials are never retained.
class ApiFailure implements Exception {
  const ApiFailure(
    this.type, {
    this.status,
    this.requestId,
    this.instance,
    this.fields = const [],
  });
  static const prefix = 'https://ledger.ztd.me/errors/';
  final String type;
  final int? status;
  final String? requestId;
  final String? instance;
  final List<String> fields;
  bool isType(String slug) => type == '$prefix$slug';
  bool get deniesAccess => status == 401 || status == 403;
  @override
  String toString() => 'ApiFailure($type, $status)';
}
