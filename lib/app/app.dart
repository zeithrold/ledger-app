import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_app/app/locale/locale_controller.dart';
import 'package:ledger_app/app/router.dart';
import 'package:ledger_app/app/theme/ledger_theme.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/app/theme/theme_mode_controller.dart';
import 'package:ledger_app/l10n/generated/app_localizations.dart';
import 'package:ledger_app/l10n/l10n.dart';

/// Ledger's routing, localization and shared mobile theme.
class LedgerApp extends ConsumerWidget {
  /// Creates the application shell.
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light = LedgerTheme.light;
    final dark = LedgerTheme.dark;
    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(
        builder: (context) => MaterialApp.router(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          routerConfig: ref.watch(routerProvider),
          themeAnimationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : LedgerTokens.feedback,
          themeMode: ref.watch(themeModeControllerProvider),
          theme: light,
          darkTheme: dark,
          locale: ref.watch(localeControllerProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: Theme.of(context).appBarTheme.systemOverlayStyle!,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}
