import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';

/// The single palette, typography and Material component boundary for Ledger.
abstract final class LedgerTheme {
  /// Neutral light canvas with a restrained blue accent.
  static final ThemeData light = _build(Brightness.light);

  /// Independently selected dark surfaces and accessible foregrounds.
  static final ThemeData dark = _build(Brightness.dark);

  /// Locally bundled Latin typeface; CJK uses the platform fallback.
  static const fontFamily = 'Inter';

  /// Complete, shared text roles with deliberate leading and weight.
  static TextTheme typography(Color color) {
    TextStyle role(double size, double height, FontWeight weight) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      letterSpacing: 0,
      fontWeight: weight,
      color: color,
      textBaseline: TextBaseline.alphabetic,
    );
    return TextTheme(
      displayLarge: role(40, 1.2, FontWeight.w600),
      displayMedium: role(36, 1.2, FontWeight.w600),
      displaySmall: role(32, 1.25, FontWeight.w600),
      headlineLarge: role(32, 1.25, FontWeight.w600),
      headlineMedium: role(28, 1.25, FontWeight.w600),
      headlineSmall: role(24, 1.3, FontWeight.w600),
      titleLarge: role(18, 1.4, FontWeight.w600),
      titleMedium: role(16, 1.4, FontWeight.w500),
      titleSmall: role(15, 1.4, FontWeight.w500),
      bodyLarge: role(16, 1.5, FontWeight.w400),
      bodyMedium: role(16, 1.5, FontWeight.w400),
      bodySmall: role(14, 1.45, FontWeight.w400),
      labelLarge: role(15, 1.4, FontWeight.w500),
      labelMedium: role(14, 1.4, FontWeight.w500),
      labelSmall: role(12, 1.4, FontWeight.w500),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final accent = dark ? const Color(0xFF9DACFF) : const Color(0xFF365CCE);
    final onAccent = dark ? const Color(0xFF182044) : Colors.white;
    final subtle = dark ? const Color(0xFF252E54) : const Color(0xFFEBEFFE);
    final canvas = dark ? const Color(0xFF121318) : const Color(0xFFF6F7F9);
    final surface = dark ? const Color(0xFF1B1D24) : Colors.white;
    final raised = dark ? const Color(0xFF242730) : const Color(0xFFECEEF2);
    final foreground = dark ? const Color(0xFFEEF0F4) : const Color(0xFF1B1D24);
    final muted = dark ? const Color(0xFFADB2BF) : const Color(0xFF636874);
    final border = dark ? const Color(0xFF343946) : const Color(0xFFDDE0E6);
    final error = dark ? const Color(0xFFF49C98) : const Color(0xFFB33A38);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: subtle,
      onPrimaryContainer: accent,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: subtle,
      onSecondaryContainer: accent,
      tertiary: accent,
      onTertiary: onAccent,
      tertiaryContainer: subtle,
      onTertiaryContainer: accent,
      error: error,
      onError: dark ? canvas : Colors.white,
      errorContainer: Color.alphaBlend(error.withValues(alpha: .1), surface),
      onErrorContainer: error,
      surface: surface,
      onSurface: foreground,
      onSurfaceVariant: muted,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      surfaceDim: canvas,
      surfaceBright: raised,
      inverseSurface: foreground,
      onInverseSurface: canvas,
      inversePrimary: dark
          ? light.colorScheme.primary
          : const Color(0xFF9DACFF),
      outline: dark ? const Color(0xFF7E8596) : const Color(0xFF7A808E),
      outlineVariant: border,
      surfaceTint: Colors.transparent,
    );
    final text = typography(foreground);
    const shape = RoundedRectangleBorder(borderRadius: LedgerTokens.radius);
    WidgetStateProperty<Color?> overlay(Color color) =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.transparent;
          if (states.contains(WidgetState.pressed)) {
            return color.withValues(alpha: .1);
          }
          if (states.contains(WidgetState.focused)) {
            return color.withValues(alpha: .12);
          }
          if (states.contains(WidgetState.hovered)) {
            return color.withValues(alpha: .06);
          }
          return Colors.transparent;
        });
    ButtonStyle button({bool filled = false, bool outlined = false}) =>
        ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: LedgerTokens.lg,
              vertical: LedgerTokens.md,
            ),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          shape: const WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
          animationDuration: LedgerTokens.feedback,
          splashFactory: NoSplash.splashFactory,
          overlayColor: overlay(filled ? onAccent : accent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? muted
                : filled
                ? onAccent
                : accent,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? filled
                      ? raised
                      : Colors.transparent
                : filled
                ? accent
                : Colors.transparent,
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: filled ? onAccent : accent, width: 2);
            }
            return outlined
                ? BorderSide(color: scheme.outline)
                : BorderSide.none;
          }),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: text,
      fontFamily: fontFamily,
      iconTheme: IconThemeData(color: foreground, size: LedgerTokens.icon),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: NoSplash.splashFactory,
      highlightColor: accent.withValues(alpha: .08),
      hoverColor: accent.withValues(alpha: .06),
      focusColor: accent.withValues(alpha: .16),
      appBarTheme: AppBarThemeData(
        backgroundColor: canvas,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineMedium,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(style: button(filled: true)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button(outlined: true),
      ),
      textButtonTheme: TextButtonThemeData(style: button()),
      iconButtonTheme: IconButtonThemeData(
        style: button().copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? muted : foreground,
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.all(LedgerTokens.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(LedgerTokens.lg),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: text.bodySmall?.copyWith(color: muted),
        hintStyle: text.bodyMedium?.copyWith(color: muted),
        prefixIconColor: muted,
        border: const OutlineInputBorder(
          borderRadius: LedgerTokens.smallRadius,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LedgerTokens.smallRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LedgerTokens.smallRadius,
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: LedgerTokens.smallRadius,
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: LedgerTokens.smallRadius,
          borderSide: BorderSide(color: error, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBarrierColor: const Color(0x66000000),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: LedgerTokens.sheetRadius,
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: false,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: accent,
        textColor: foreground,
        iconColor: muted,
        minTileHeight: LedgerTokens.rowHeight,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : scheme.outline,
        ),
        overlayColor: overlay(accent),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        textColor: muted,
        collapsedTextColor: muted,
        iconColor: muted,
        collapsedIconColor: muted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: subtle,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: LedgerTokens.smallRadius,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? accent : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: LedgerTokens.icon,
            color: states.contains(WidgetState.selected) ? accent : muted,
          ),
        ),
        overlayColor: overlay(accent),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: subtle,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: LedgerTokens.smallRadius,
        ),
        selectedIconTheme: IconThemeData(
          color: accent,
          size: LedgerTokens.icon,
        ),
        unselectedIconTheme: IconThemeData(
          color: muted,
          size: LedgerTokens.icon,
        ),
        selectedLabelTextStyle: text.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: text.labelSmall?.copyWith(color: muted),
      ),
    );
  }
}
