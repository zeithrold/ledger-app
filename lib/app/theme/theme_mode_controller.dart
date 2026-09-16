import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Display theme, hydrated from the authenticated preference snapshot.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Applies display state; IdentityController owns authenticated persistence.
  // Riverpod exposes explicit notifier methods for state changes.
  // ignore: use_setters_to_change_properties
  void setMode(ThemeMode mode) => state = mode;
}

/// One retained display theme for the whole application shell.
final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
