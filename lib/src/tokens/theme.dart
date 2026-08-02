import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'shadows.dart';
import 'typography.dart';

/// Value-equality for two [BoxShadow] lists (order-sensitive).
///
/// [CruxShadows] itself intentionally has no `==` override, matching
/// [CruxColors] (also field-only, no `==`): [CruxThemeData] is the one
/// place equality is hand-written, by enumerating every token field, so
/// that adding a field there without also adding it to
/// [CruxThemeData.==] is caught by the "differing only in ..." regression
/// tests rather than silently ignored. [CruxShadows.sm]/`.md`/`.lg` are
/// `List<BoxShadow>`, which — unlike [Color] or [BoxShadow] itself, both of
/// which already have value `==` — compares by identity by default, so
/// this helper does the element-wise comparison [CruxThemeData.==] needs
/// for those three fields.
bool _boxShadowListEquals(List<BoxShadow> a, List<BoxShadow> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// An immutable bundle of the design tokens that make up a Crux theme:
/// a color palette, a type scale, a shadow/scrim palette, and the
/// [Brightness] they were built for.
///
/// Use [CruxThemeData.light] or [CruxThemeData.dark] to get the
/// built-in palettes, or construct a custom instance to mix and match
/// (for example a custom [CruxColors] with the stock [CruxTypography]).
@immutable
class CruxThemeData {
  /// Creates a theme from an explicit color palette, type scale, shadow
  /// palette, and brightness.
  ///
  /// [shadows] defaults to [CruxShadows.light] so existing call sites
  /// that construct [CruxThemeData] manually (predating this field) keep
  /// compiling unchanged — the same non-breaking-default treatment
  /// [CruxColors.onAccent] and [CruxColors.mutedFill] already use.
  const CruxThemeData({
    required this.colors,
    required this.typography,
    required this.brightness,
    this.shadows = CruxShadows.light,
  });

  /// The light theme: [CruxColors.light] and [CruxShadows.light] with
  /// the default type scale.
  factory CruxThemeData.light() {
    return const CruxThemeData(
      colors: CruxColors.light,
      typography: CruxTypography(),
      brightness: Brightness.light,
      shadows: CruxShadows.light,
    );
  }

  /// The dark theme: [CruxColors.dark] and [CruxShadows.dark] with the
  /// default type scale.
  factory CruxThemeData.dark() {
    return const CruxThemeData(
      colors: CruxColors.dark,
      typography: CruxTypography(),
      brightness: Brightness.dark,
      shadows: CruxShadows.dark,
    );
  }

  /// The color palette for this theme.
  final CruxColors colors;

  /// The type scale for this theme.
  final CruxTypography typography;

  /// Whether this theme is intended for a light or dark surface.
  final Brightness brightness;

  /// The shadow and scrim palette for this theme.
  ///
  /// Defaults to [CruxShadows.light] on the [CruxThemeData.new]
  /// constructor regardless of [colors] or [brightness] -- that default
  /// exists purely so call sites that constructed [CruxThemeData] before
  /// this field existed keep compiling unchanged (see the constructor's own
  /// doc), not because [CruxShadows.light] is somehow the "right" shadow
  /// palette for a dark theme. Nothing keeps [colors] and [shadows] in sync
  /// automatically: hand-assembling a theme with a dark [CruxColors] (for
  /// example [CruxColors.dark]) while leaving [shadows] at its default
  /// silently pairs dark colors with light-tuned shadow opacities, which
  /// were tuned to read correctly against a light background and can look
  /// wrong -- too faint or too harsh -- against a dark one. Prefer
  /// [CruxThemeData.dark], which already pairs [CruxColors.dark] with
  /// [CruxShadows.dark]; if constructing a custom dark-brightness instance
  /// by hand instead, pass `shadows: CruxShadows.dark` explicitly rather
  /// than relying on this field's default.
  final CruxShadows shadows;

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
        other.colors.controlFill == colors.controlFill &&
        other.colors.onAccent == colors.onAccent &&
        other.colors.controlPlate == colors.controlPlate &&
        _boxShadowListEquals(other.shadows.sm, shadows.sm) &&
        _boxShadowListEquals(other.shadows.md, shadows.md) &&
        _boxShadowListEquals(other.shadows.lg, shadows.lg) &&
        other.shadows.scrim == shadows.scrim &&
        other.shadows.hairline == shadows.hairline &&
        other.shadows.ink == shadows.ink &&
        _boxShadowListEquals(other.shadows.thumb, shadows.thumb) &&
        _boxShadowListEquals(other.shadows.thumbLifted, shadows.thumbLifted) &&
        _boxShadowListEquals(other.shadows.xs, shadows.xs);
  }

  // Nested rather than one flat Object.hash call: brightness + fontFamily +
  // 14 color fields + 9 shadow-derived values is 25 arguments, past
  // Object.hash's 20-argument ceiling. The color fields are grouped into
  // their own Object.hash so the outer call stays within the limit; this
  // is purely a hashCode implementation detail and does not change what
  // counts as equal (still driven entirely by operator==).
  @override
  int get hashCode => Object.hash(
    brightness,
    typography.fontFamily,
    Object.hash(
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
      colors.controlFill,
      colors.onAccent,
      colors.controlPlate,
    ),
    Object.hashAll(shadows.sm),
    Object.hashAll(shadows.md),
    Object.hashAll(shadows.lg),
    shadows.scrim,
    shadows.hairline,
    shadows.ink,
    Object.hashAll(shadows.thumb),
    Object.hashAll(shadows.thumbLifted),
    Object.hashAll(shadows.xs),
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
