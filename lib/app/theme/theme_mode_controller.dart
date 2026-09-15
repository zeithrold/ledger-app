import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// Display theme, hydrated from the authenticated preference snapshot.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Applies display state; IdentityController owns authenticated persistence.
  // Riverpod exposes explicit notifier methods for state changes.
  // ignore: use_setters_to_change_properties
  void setMode(ThemeMode mode) => state = mode;
}
