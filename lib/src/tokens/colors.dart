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
    required this.controlFill,
    this.onAccent = const Color(0xFF26251E),
    this.mutedFill = const Color.fromRGBO(38, 37, 30, 0.08),
    this.controlPlate = const Color(0xFFFFFFFF),
  });

  /// The light color palette.
  static const CruxColors light = CruxColors(
    background: Color(0xFFF7F7F4),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFFD97745),
    accentTint: Color.fromRGBO(217, 119, 69, 0.15),
    accentLine: Color(0xFFCB6F41),
    textPrimary: Color(0xFF26251E),
    textSecondary: Color(0xFF5A5852),
    muted: Color(0xFF807D72),
    separator: Color(0xFFE6E5E0),
    success: Color(0xFF1F8A65),
    error: Color(0xFFCF2D56),
    controlFill: Color(0xFFE9E8E2),
    mutedFill: Color.fromRGBO(38, 37, 30, 0.08),
    controlPlate: Color(0xFFFFFFFF),
  );

  /// The dark color palette.
  static const CruxColors dark = CruxColors(
    background: Color(0xFF141210),
    surface: Color(0xFF211F18),
    accent: Color(0xFFD97745),
    accentTint: Color.fromRGBO(217, 119, 69, 0.15),
    accentLine: Color(0xFFD97745),
    textPrimary: Color(0xFFF6F5EF),
    textSecondary: Color.fromRGBO(236, 234, 224, 0.62),
    muted: Color.fromRGBO(236, 234, 224, 0.45),
    separator: Color.fromRGBO(92, 88, 76, 0.55),
    success: Color(0xFF3ED598),
    error: Color(0xFFFF5B78),
    controlFill: Color(0xFF262319),
    mutedFill: Color.fromRGBO(246, 245, 239, 0.12),
    controlPlate: Color(0xFF3F3C33),
  );

  /// The base page background color.
  final Color background;

  /// The color of elevated surfaces such as cards and sheets.
  final Color surface;

  /// The brand accent color, used for primary actions and highlights.
  final Color accent;

  /// A low-opacity tint of [accent], for subtle fills behind accented
  /// content (for example a selected chip's background). This is a
  /// decorative wash only: because [accent]'s own hue is close in luminance
  /// to [background] (even fully opaque, it falls short of a 3:1 contrast
  /// ratio in the light palette), no opacity of this tint alone can meet
  /// WCAG 1.4.11's 3:1 non-text contrast floor — [accentLine] is the token
  /// that carries that responsibility for state-identifying visual features
  /// such as a selected chip's outline.
  final Color accentTint;

  /// An accented, opaque outline color for borders that must double as a
  /// state-identifying visual feature (for example a selected [CruxChip]'s
  /// border) — solid rather than a translucent tint of [accent], so it
  /// clears WCAG 1.4.11's 3:1 non-text contrast floor against both
  /// [background] and [surface] in each palette (verified in
  /// `test/contrast_test.dart`).
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

  /// The fill painted behind an interactive control such as a text input —
  /// for example [CruxTextFormField]'s box. Distinct from both
  /// [separator] (reused here, the fill and the 1px border it sits behind
  /// would become the same color and the border would visually disappear)
  /// and [surface] (reused here, a filled control would become
  /// indistinguishable from a card in dark mode, where [surface] and
  /// [background] sit close together). This name is deliberately generic
  /// rather than field-specific: other controls this package adds later
  /// (for example a search or chat input bar, or a post-composer box) are
  /// expected to reuse it too.
  final Color controlFill;

  /// The text/icon color to use on top of [accent] (for example a filled
  /// button's label). Fixed to `#26251E` in both palettes — measured at a
  /// 4.89:1 contrast ratio against [accent], above WCAG AA's 4.5:1 for
  /// normal text.
  final Color onAccent;

  /// The fill painted behind an inactive affordance that sits *on top of*
  /// another filled surface — for example `CruxInputBar`'s disabled
  /// submit circle, which is drawn inside a [controlFill]-filled box.
  ///
  /// This token exists because [separator] cannot play that role there:
  /// [separator] and [controlFill] are nearly the same color in both
  /// palettes (measured ~1.03:1 in light), so a separator-filled circle
  /// inside a controlFill box simply vanishes. That is fine for
  /// `CruxButton`'s disabled state, which sits on [background], but not
  /// for anything nested inside a filled control.
  ///
  /// The value is a translucent wash of [textPrimary]'s hue rather than an
  /// opaque gray, the same "darkens in light mode, lightens in dark mode
  /// without a second brightness-specific token" trick `CruxButton`'s
  /// pressed overlay uses — and because it is translucent, it reads
  /// correctly over [controlFill], [background], or [surface] alike.
  /// Composite it over whatever it actually sits on before measuring
  /// contrast against it (see `test/contrast_test.dart`).
  final Color mutedFill;

  /// The fill for a filled control's own selected/lifted inner plate --
  /// for example [CruxSegmentedControl]'s selected-segment plate, drawn
  /// on top of [controlFill]'s track.
  ///
  /// This token exists because [surface] cannot play that role in the dark
  /// palette: there, [surface] (`#211F18`) and [controlFill] (`#262319`)
  /// sit only ~1.05:1 apart (measured with `test/tokens/contrast_test.dart`'s
  /// own WCAG math) -- close enough that a [surface]-filled plate is
  /// essentially indistinguishable from the track it is meant to lift off
  /// of. The light palette has no such problem ([surface] is pure white
  /// against [controlFill]'s `#E9E8E2`, ~1.23:1), so [light]'s value below
  /// is identical to [surface] and the light appearance is unchanged.
  ///
  /// The dark value, `#3F3C33`, is [mutedFill]'s dark wash
  /// (`rgba(246, 245, 239, 0.12)`) alpha-composited over [controlFill] and
  /// flattened to the single opaque color that composite produces on
  /// screen. It is stored opaque rather than kept as a translucent wash
  /// like [mutedFill] itself, because the plate this token fills is also
  /// painted with a drop shadow -- a translucent fill would let whatever
  /// sits underneath the plate show through and muddy that shadow.
  /// Measured against [controlFill] with this same WCAG math: light
  /// ~1.23:1, dark ~1.43:1 (`test/tokens/contrast_test.dart`) -- a
  /// perceptible, tasteful lift rather than a WCAG 1.4.11 3:1 non-text
  /// floor; for a selected segment, that 3:1 floor is still carried by the
  /// label's own color change ([textPrimary] vs. [textSecondary]), not by
  /// this plate fill.
  ///
  /// Like every value in this file, both `#FFFFFF` and `#3F3C33` are
  /// provisional (the borrowed "Mimir" palette) and may change on a future
  /// palette swap -- see this class's own doc.
  final Color controlPlate;
}
