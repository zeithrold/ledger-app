import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/core/auth/clerk_gateway.dart';
import 'package:ledger_app/core/config/api_endpoint.dart';
import 'package:ledger_app/core/identity/identity_controller.dart';
import 'package:ledger_app/core/identity/ledger_api.dart';
import 'package:ledger_app/core/network/http_client.dart';

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
    applyPreferences: (preferences) {
      ref
          .read(localeControllerProvider.notifier)
          .setLanguageTag(preferences.locale);
      ref
          .read(themeModeControllerProvider.notifier)
          .setMode(
            ThemeMode.values.firstWhere(
              (mode) => mode.name == preferences.theme,
              orElse: () => ThemeMode.system,
            ),
          );
    },
    resetPreferences: () {
      ref.read(localeControllerProvider.notifier).resetToDevice();
      ref.read(themeModeControllerProvider.notifier).setMode(ThemeMode.system);
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
});
