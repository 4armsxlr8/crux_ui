import 'dart:ui' show Color;

/// Semantic color tokens for Crux UI.
///
/// Every field is a semantic name (for example [accent] or [textPrimary])
/// rather than a raw hue, so call sites never hardcode a color value.
/// Use [CruxColors.light] or [CruxColors.dark] to pick a palette, or
/// construct a custom instance for a bespoke brightness.
///
/// The raw color values live in this class only. If Crux UI's palette
/// changes in the future, this is the single file that needs to change.
class CruxColors {
  /// Creates a set of semantic color tokens.
  ///
  /// [onAccent] defaults to `#26251E` (fixed in both palettes) so existing
  /// call sites that construct [CruxColors] manually keep compiling
  /// unchanged.
  const CruxColors({
    required this.background,
    required this.surface,
    required this.accent,
    required this.accentTint,
    required this.accentLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.muted,
    required this.separator,
    required this.success,
    required this.error,
    this.onAccent = const Color(0xFF26251E),
  });

  /// The light color palette.
  static const CruxColors light = CruxColors(
    background: Color(0xFFF7F7F4),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFFD97745),
    accentTint: Color.fromRGBO(217, 119, 69, 0.15),
    accentLine: Color.fromRGBO(217, 119, 69, 0.40),
    textPrimary: Color(0xFF26251E),
    textSecondary: Color(0xFF5A5852),
    muted: Color(0xFF807D72),
    separator: Color(0xFFE6E5E0),
    success: Color(0xFF1F8A65),
    error: Color(0xFFCF2D56),
  );

  /// The dark color palette.
  static const CruxColors dark = CruxColors(
    background: Color(0xFF141210),
    surface: Color(0xFF211F18),
    accent: Color(0xFFD97745),
    accentTint: Color.fromRGBO(217, 119, 69, 0.15),
    accentLine: Color.fromRGBO(217, 119, 69, 0.40),
    textPrimary: Color(0xFFF6F5EF),
    textSecondary: Color.fromRGBO(236, 234, 224, 0.62),
    muted: Color.fromRGBO(236, 234, 224, 0.45),
    separator: Color.fromRGBO(92, 88, 76, 0.55),
    success: Color(0xFF3ED598),
    error: Color(0xFFFF5B78),
  );

  /// The base page background color.
  final Color background;

  /// The color of elevated surfaces such as cards and sheets.
  final Color surface;

  /// The brand accent color, used for primary actions and highlights.
  final Color accent;

  /// A low-opacity tint of [accent], for subtle fills behind accented
  /// content (for example a chip's background).
  final Color accentTint;

  /// A mid-opacity tint of [accent], for borders and outlines that should
  /// read as accented without competing with [accent] itself.
  final Color accentLine;

  /// The color of primary, high-emphasis text.
  final Color textPrimary;

  /// The color of secondary, lower-emphasis text.
  final Color textSecondary;

  /// The color of muted, least-emphasis content such as placeholder text
  /// or disabled affordances.
  final Color muted;

  /// The color of hairlines and dividers.
  final Color separator;

  /// The color used to indicate a successful or positive state.
  final Color success;

  /// The color used to indicate an error or destructive state.
  final Color error;

  /// The text/icon color to use on top of [accent] (for example a filled
  /// button's label). Fixed to `#26251E` in both palettes — measured at a
  /// 4.89:1 contrast ratio against [accent], above WCAG AA's 4.5:1 for
  /// normal text.
  final Color onAccent;
}
