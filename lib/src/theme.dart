import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'typography.dart';

/// An immutable bundle of the design tokens that make up a Crux theme:
/// a color palette, a type scale, and the [Brightness] they were built for.
///
/// Use [CruxThemeData.light] or [CruxThemeData.dark] to get the
/// built-in palettes, or construct a custom instance to mix and match
/// (for example a custom [CruxColors] with the stock [CruxTypography]).
@immutable
class CruxThemeData {
  /// Creates a theme from an explicit color palette, type scale, and
  /// brightness.
  const CruxThemeData({
    required this.colors,
    required this.typography,
    required this.brightness,
  });

  /// The light theme: [CruxColors.light] with the default type scale.
  factory CruxThemeData.light() {
    return const CruxThemeData(
      colors: CruxColors.light,
      typography: CruxTypography(),
      brightness: Brightness.light,
    );
  }

  /// The dark theme: [CruxColors.dark] with the default type scale.
  factory CruxThemeData.dark() {
    return const CruxThemeData(
      colors: CruxColors.dark,
      typography: CruxTypography(),
      brightness: Brightness.dark,
    );
  }

  /// The color palette for this theme.
  final CruxColors colors;

  /// The type scale for this theme.
  final CruxTypography typography;

  /// Whether this theme is intended for a light or dark surface.
  final Brightness brightness;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CruxThemeData &&
        other.brightness == brightness &&
        other.typography.fontFamily == typography.fontFamily &&
        other.colors.background == colors.background &&
        other.colors.surface == colors.surface &&
        other.colors.accent == colors.accent &&
        other.colors.accentTint == colors.accentTint &&
        other.colors.accentLine == colors.accentLine &&
        other.colors.textPrimary == colors.textPrimary &&
        other.colors.textSecondary == colors.textSecondary &&
        other.colors.muted == colors.muted &&
        other.colors.separator == colors.separator &&
        other.colors.success == colors.success &&
        other.colors.error == colors.error &&
        other.colors.onAccent == colors.onAccent;
  }

  @override
  int get hashCode => Object.hash(
    brightness,
    typography.fontFamily,
    colors.background,
    colors.surface,
    colors.accent,
    colors.accentTint,
    colors.accentLine,
    colors.textPrimary,
    colors.textSecondary,
    colors.muted,
    colors.separator,
    colors.success,
    colors.error,
    colors.onAccent,
  );
}

/// Makes a [CruxThemeData] available to a subtree via [CruxTheme.of].
///
/// This is a plain [InheritedWidget], independent of Material's `Theme` —
/// providing a [CruxTheme] never changes the appearance of Material
/// widgets. Widgets that want Crux's tokens read them explicitly with
/// [CruxTheme.of], rather than having them silently rewrite Material's
/// `ThemeData`.
class CruxTheme extends InheritedWidget {
  /// Provides [data] to [child] and its descendants.
  const CruxTheme({super.key, required this.data, required super.child});

  /// The theme data made available to descendants.
  final CruxThemeData data;

  /// Returns the [CruxThemeData] from the closest [CruxTheme] ancestor
  /// of [context].
  ///
  /// If no [CruxTheme] is found, returns [CruxThemeData.light] so that
  /// widgets built without an explicit Crux theme still render sensibly
  /// instead of throwing.
  static CruxThemeData of(BuildContext context) {
    final CruxTheme? theme = context
        .dependOnInheritedWidgetOfExactType<CruxTheme>();
    return theme?.data ?? CruxThemeData.light();
  }

  @override
  bool updateShouldNotify(CruxTheme oldWidget) => data != oldWidget.data;
}
