// Internal contract members are documented by their owning boundary.
// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ledger_app/core/auth/auth_gateway.dart';
import 'package:ledger_app/core/identity/ledger_api.dart';
import 'package:ledger_app/core/identity/models.dart';

enum IdentityPhase {
  configuration,
  authentication,
  signedOut,
  loading,
  onboarding,
  ready,
  error,
}

/// Owns the user context and discards all work from previous sessions.
class IdentityController extends ChangeNotifier {
  IdentityController({
    required this.auth,
    required this.api,
    required this.applyPreferences,
    required this.resetPreferences,
  }) {
    auth.addListener(_authChanged);
    scheduleMicrotask(_authChanged);
  }
  final AuthGateway auth;
  final LedgerApi? api;
  final void Function(Preferences) applyPreferences;
  final VoidCallback resetPreferences;
  IdentityPhase phase = IdentityPhase.authentication;
  PersonalContext? context;
  ApiFailure? error;
  Map<String, String>? pendingPreferences;
  bool saving = false;
  bool signingOut = false;
  String? _session;
  int _generation = 0;
  bool _disposed = false;
  bool _current(int generation) => !_disposed && generation == _generation;

  void _authChanged() {
    if (_disposed) return;
    final next = auth.sessionKey;
    if (next != _session) {
      final hadSession = _session != null;
      _generation++;
      _session = next;
      phase = IdentityPhase.authentication;
      context = null;
      error = null;
      pendingPreferences = null;
      saving = false;
      if (hadSession) {
        resetPreferences();
      }
    }
    if (!auth.configured || api == null) {
      phase = IdentityPhase.configuration;
    } else if (auth.loading) {
      phase = IdentityPhase.authentication;
    } else if (auth.failed) {
      phase = IdentityPhase.error;
      error = const ApiFailure('authentication-error');
    } else if (next == null) {
      phase = IdentityPhase.signedOut;
    } else if (context == null &&
        (phase == IdentityPhase.authentication ||
            phase == IdentityPhase.signedOut) &&
        !signingOut) {
      unawaited(load());
      return;
    }
    notifyListeners();
  }

  Future<void> load() async {
    if (api == null || auth.sessionKey == null || signingOut) return;
    final generation = ++_generation;
    context = null;
    error = null;
    pendingPreferences = null;
    phase = IdentityPhase.loading;
    notifyListeners();
    try {
      final value = await api!.me();
      if (!_current(generation)) return;
      _ready(value);
    } on ApiFailure catch (failure) {
      if (!_current(generation)) return;
      error = failure.isType('bootstrap-required') ? null : failure;
      phase = failure.isType('bootstrap-required')
          ? IdentityPhase.onboarding
          : IdentityPhase.error;
    }
    if (_current(generation)) notifyListeners();
  }

  void _ready(PersonalContext value) {
    context = value;
    phase = IdentityPhase.ready;
    error = null;
    pendingPreferences = null;
    applyPreferences(value.preferences);
  }

  Future<void> bootstrap(BootstrapInput input) async {
    if (saving || phase != IdentityPhase.onboarding || api == null) return;
    final generation = _generation;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final value = await api!.bootstrap(input);
      if (_current(generation)) _ready(value);
    } on ApiFailure catch (failure) {
      if (_current(generation)) handleFailure(failure);
    } finally {
      if (_current(generation)) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> savePreferences(Map<String, String> patch) async {
    if (saving || phase != IdentityPhase.ready || api == null) return;
    final generation = _generation;
    pendingPreferences = Map<String, String>.unmodifiable(patch);
    saving = true;
    error = null;
    notifyListeners();
    try {
      final value = await api!.preferences(patch);
      if (_current(generation) && context != null) {
        context = context!.withPreferences(value);
        applyPreferences(value);
        pendingPreferences = null;
      }
    } on ApiFailure catch (failure) {
      if (_current(generation)) handleFailure(failure);
    } finally {
      if (_current(generation)) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryPreferences() async {
    final patch = pendingPreferences;
    if (patch != null) await savePreferences(patch);
  }

  void handleFailure(ApiFailure failure) {
    error = failure;
    if (failure.deniesAccess ||
        failure.isType('api-version-unsupported') ||
        failure.isType('api-major-version-unsupported')) {
      context = null;
      phase = IdentityPhase.error;
      pendingPreferences = null;
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (auth.failed) {
      await auth.initialize();
    } else {
      await load();
    }
  }

  Future<void> signOut() async {
    if (signingOut) return;
    _generation++;
    context = null;
    saving = false;
    error = null;
    pendingPreferences = null;
    signingOut = true;
    phase = IdentityPhase.authentication;
    resetPreferences();
    notifyListeners();
    try {
      await auth.signOut();
    } on Object {
      if (!_disposed) {
        error = const ApiFailure('signout-error');
        phase = IdentityPhase.error;
      }
    } finally {
      if (!_disposed) {
        signingOut = false;
        if (error == null) _authChanged();
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
