import 'package:flutter/widgets.dart';

/// Shared geometry and feedback timing for the entire application.
abstract final class LedgerTokens {
  /// Tight inline gap.
  static const double xs = 4;

  /// Related item gap.
  static const double sm = 8;

  /// Icon and content gap.
  static const double md = 12;

  /// Standard row inset.
  static const double lg = 16;

  /// Page margin at regular phone widths.
  static const double gutter = 20;

  /// Section gap.
  static const double xl = 24;

  /// Major content gap.
  static const double xxl = 32;

  /// Maximum standard spacing step.
  static const double xxxl = 48;

  /// Minimum interactive target dimension.
  static const double target = 48;

  /// Standard icon size.
  static const double icon = 22;

  /// Accessory icon size.
  static const double smallIcon = 18;

  /// Minimum grouped row height before text expansion.
  static const double rowHeight = 56;

  /// Maximum width for focused forms.
  static const double formWidth = 520;

  /// Maximum width for reading content.
  static const double contentWidth = 640;

  /// Width at which authenticated navigation becomes a rail.
  static const double railBreakpoint = 600;

  /// Minimum width for side-by-side preference labels and values.
  static const double preferenceValueBreakpoint = 328;

  /// Compact navigation height before system text expansion.
  static const double navigationHeight = 72;

  /// Expanded canvas breakpoint for future split content.
  static const double expandedBreakpoint = 840;

  /// Maximum height for searchable catalogs.
  static const double sheetHeight = 680;

  /// Maximum height for short choice lists.
  static const double compactSheetHeight = 400;

  /// Narrow canvas threshold for compact page margins.
  static const double crampedHeight = 360;

  /// Onboarding progress indicator thickness.
  static const double progressHeight = 3;

  /// Small controls and badges.
  static const smallRadius = BorderRadius.all(Radius.circular(8));

  /// Shared group and action shape.
  static const radius = BorderRadius.all(Radius.circular(12));

  /// Modal sheet top corners.
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

  /// Standard short feedback duration.
  static const feedback = Duration(milliseconds: 160);

  /// Keep content usable on the narrowest supported screens.
  static double pageGutter(double width) => width < crampedHeight ? lg : gutter;
}
