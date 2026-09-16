import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/ledger_api.dart';
import 'package:ledger_app/core/network/http_client.dart';

/// Display preferences owned by the application shell.
///
/// Core never imports the shell: the shell overrides this seam with its locale
/// and theme controllers, and the inert default keeps core usable on its own.
final preferenceApplierProvider = Provider<PreferenceApplier>(
  (ref) => const PreferenceApplier(),
);

/// One controller per configured authentication boundary.
final identityProvider = Provider<IdentityController>((ref) {
  final endpoint = ref.watch(apiEndpointProvider);
  final auth = ref.watch(authGatewayProvider);
  final controller = IdentityController(
    auth: auth,
    api: endpoint == null || !auth.configured
        ? null
        : LedgerApi(
            endpoint: endpoint,
            client: ref.watch(httpClientProvider),
            auth: auth,
          ),
    preferences: ref.watch(preferenceApplierProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
