import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, immutable;
import 'package:flutter/painting.dart'
    show FontWeight, TextBaseline, TextLeadingDistribution, TextStyle;

/// The Crux type scale: nine semantic [TextStyle] tokens that resolve to the
/// host platform's own type scale.
///
/// ```dart
/// CruxTheme(
///   data: const CruxThemeData(
///     colors: CruxColors.light,
///     brightness: Brightness.light,
///     typography: CruxTypography(body: TextStyle(fontSize: 15)),
///   ),
///   child: app,
/// )
/// ```
///
/// A customised scale has to be assembled through `CruxThemeData`'s own
/// constructor like this, which also puts the shadow palette in your hands:
/// that constructor defaults `shadows` to the light one whatever `brightness`
/// says, so a dark theme built this way needs `shadows: CruxShadows.dark`
/// passed explicitly — see the warning on `CruxThemeData`'s constructor.
///
/// On iOS and macOS each token resolves to a style from Apple's Human
/// Interface Guidelines (the Dynamic Type "Large" size category); on every
/// other platform it resolves to the equivalent Material 3 style. A token
/// therefore has **different metrics on different platforms** — [body] is
/// 17 logical pixels on iOS and 16 on Android — so text-bearing components
/// change size across platforms by design. The token names describe the role
/// ([title], [body], [label]), never the size, because the size is not fixed.
///
/// Line height follows each platform too: the Apple styles leave `height`
/// unset so the font's own metrics apply, while the Material styles carry the
/// line heights from the Material 3 specification.
///
/// ## Customising the scale
///
/// [fontFamily] replaces the family of every token on both tiers at once;
/// leaving it unset uses each platform's system font.
///
/// Each token additionally has its own optional override, passed to the
/// constructor as `heading`, `subheading`, `title`, `body`, `caption`,
/// `captionStrong`, `labelSmall`, `label`, or `navLabel`. An override is
/// merged onto that token's platform default, which makes customisation a
/// two-layer fallback: a token you do not override keeps its platform default
/// entirely, and a token you do override keeps the platform default for every
/// attribute the override leaves unset. Passing
/// `body: TextStyle(fontSize: 15)` therefore changes the size and nothing
/// else — the weight, letter spacing, family, and (on Material) the line
/// height and leading distribution all survive.
///
/// Sizes have a height budget. The controls in this kit have fixed heights
/// tuned to the default scale, so enlarging a control token — [label],
/// [labelSmall], [navLabel] — by much makes buttons, chips, and segments
/// truncate their labels rather than grow. Raise those tokens in small steps
/// and check the components that use them.
///
/// Overrides belong on the `CruxTypography` you build your `CruxThemeData`
/// from; that is the supported way to reshape the type scale. Patching a
/// token where it is used — reading the theme and calling `copyWith` on the
/// resulting style at the call site — is still the wrong move: it changes one
/// widget while the rest of the app keeps the old metrics, and it is
/// invisible to anyone reading the theme.
///
/// ### Replacing a token outright
///
/// An override whose `inherit` is `false` is taken verbatim: nothing is
/// merged into it, and it ignores the scale-wide [fontFamily] as well.
///
/// The catch is that a *partial* style with `inherit: false` does not fall
/// back to the platform default for the attributes it omits — it falls back
/// to the Flutter engine's own bare defaults, so the platform's font size,
/// line height, letter spacing, weight, and family are all gone. An omitted
/// size in particular becomes 14 logical pixels, not the token's own size.
/// Spell out every attribute the token needs, or drop `inherit: false` and
/// let the merge fill the gaps.
///
/// ### Which font family wins
///
/// For any one token the family is the first of these that is set: the
/// override's own `fontFamily`, then the scale-wide [fontFamily], then the
/// platform default. (An `inherit: false` override skips the last two along
/// with everything else.)
///
/// On the Apple tier the platform default family is `CupertinoSystemDisplay`
/// for the tokens that are 20pt or larger and `CupertinoSystemText` for the
/// rest. Which one a token gets is decided by its *default* size, so an
/// override that moves a token across the 20pt boundary keeps the family of
/// the tier it started in; pass a `fontFamily` in the override too if you
/// want the other one.
///
/// ### Tokens carry no color
///
/// An override must not set `color`, `backgroundColor`, `foreground`,
/// `background`, `decorationColor`, or `shadows`: in debug builds, reading any
/// token of a scale whose overrides carry one of those throws an assertion
/// error naming the offending token. (In release builds asserts are stripped,
/// so the color is simply applied — treat the debug run as the check.) A
/// `shadows` list is rejected however it is filled, because every `Shadow`
/// carries a color.
///
/// Tokens hold metrics only — the color of text is decided by each component
/// from its own state (enabled, pressed, disabled, selected) out of the
/// theme's color palette, so a color baked into the type scale would either
/// be ignored or fight the component.
///
/// ### [label] and [labelSmall] on Material
///
/// These two tokens resolve to the same Material style by default, because
/// Material has no equivalent of the Apple tier's 13pt/15pt split. Their
/// override slots are still independent, so overriding just one of them makes
/// the two differ on Material as well as on Apple platforms. Override both if
/// they are meant to stay in step.
@immutable
class CruxTypography {
  /// Creates a type scale.
  ///
  /// Pass [fontFamily] to override the family used by every style; leave it
  /// unset (the default) to use each platform's system font. Pass [platform]
  /// to pin which platform's scale is used — tests and golden files should
  /// always pin it; production code should leave it unset so it follows
  /// [defaultTargetPlatform].
  ///
  /// The remaining nine parameters — `heading`, `subheading`, `title`,
  /// `body`, `caption`, `captionStrong`, `labelSmall`, `label`, and
  /// `navLabel` — each override the token of the same name. See the class
  /// documentation for the merge rules, for `inherit: false` as the way to
  /// replace a token outright, and for the ban on colors.
  const CruxTypography({
    this.fontFamily,
    this.platform,
    TextStyle? heading,
    TextStyle? subheading,
    TextStyle? title,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? captionStrong,
    TextStyle? labelSmall,
    TextStyle? label,
    TextStyle? navLabel,
  }) : _headingOverride = heading,
       _subheadingOverride = subheading,
       _titleOverride = title,
       _bodyOverride = body,
       _captionOverride = caption,
       _captionStrongOverride = captionStrong,
       _labelSmallOverride = labelSmall,
       _labelOverride = label,
       _navLabelOverride = navLabel;

  /// The font family applied to every style in this scale, or `null` to use
  /// each platform's system font.
  ///
  /// A non-null value replaces the family on both the Apple and the Material
  /// tier, so a custom font applies everywhere rather than only on one.
  final String? fontFamily;

  /// Which platform's type scale to resolve to, or `null` to follow
  /// [defaultTargetPlatform].
  ///
  /// [TargetPlatform.iOS] and [TargetPlatform.macOS] select Apple's HIG
  /// scale; every other value selects Material 3.
  final TargetPlatform? platform;

  // The nine per-token overrides. They carry an `Override` suffix because the
  // token name itself is taken by the public getter that resolves it, and
  // because a bare `_heading` would read like a sibling of the `_appleHeading`
  // and `_materialHeading` defaults below rather than a user-supplied patch.
  final TextStyle? _headingOverride;
  final TextStyle? _subheadingOverride;
  final TextStyle? _titleOverride;
  final TextStyle? _bodyOverride;
  final TextStyle? _captionOverride;
  final TextStyle? _captionStrongOverride;
  final TextStyle? _labelSmallOverride;
  final TextStyle? _labelOverride;
  final TextStyle? _navLabelOverride;

  /// Whether this scale resolves to Apple's HIG styles rather than Material's.
  bool get _usesAppleScale {
    final TargetPlatform target = platform ?? defaultTargetPlatform;
    return target == TargetPlatform.iOS || target == TargetPlatform.macOS;
  }

  // Apple's HIG tier. Values are the iOS "Large" Dynamic Type category, kept
  // in sync with the cupertino_typography package by
  // test/tokens/native_scale_parity_test.dart. 'CupertinoSystemDisplay' is
  // the family for 20pt and above, 'CupertinoSystemText' below it; on
  // non-Apple platforms Flutter falls back to the default family, which is
  // why these styles are only ever used behind [_usesAppleScale].
  static const TextStyle _appleHeading = TextStyle(
    fontFamily: 'CupertinoSystemDisplay',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
  );

  static const TextStyle _appleSubheading = TextStyle(
    fontFamily: 'CupertinoSystemDisplay',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
  );

  static const TextStyle _appleTitle = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
  );

  static const TextStyle _appleBody = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
  );

  static const TextStyle _appleCaption = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle _appleCaptionStrong = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle _appleLabelSmall = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.08,
  );

  static const TextStyle _appleLabel = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
  );

  static const TextStyle _appleNavLabel = TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.07,
  );

  // Material 3 tier. Values are Flutter's own Typography.englishLike2021,
  // kept in sync by test/tokens/native_scale_parity_test.dart.
  // `leadingDistribution: even` comes with them: dropping it shifts text
  // vertically inside the package's fixed-height controls. The family is
  // deliberately left null so the platform default applies — naming 'Roboto'
  // would break CJK fallback.
  static const TextStyle _materialHeading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.29,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _materialSubheading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.27,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _materialTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.50,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _materialBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _materialCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _materialCaptionStrong = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Both labelSmall and label map here: a native Android button uses
  // labelLarge at every size, so the 13/15 split the Apple tier makes has no
  // Material counterpart.
  static const TextStyle _materialLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _materialNavLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Throws instead of returning false so the message can name the token. A
  // non-null shadows list is rejected whatever it holds: every Shadow carries
  // a color, so there is no color-free way to set one.
  static bool _debugCheckOverride(String token, TextStyle? override) {
    if (override != null &&
        (override.color != null ||
            override.backgroundColor != null ||
            override.foreground != null ||
            override.background != null ||
            override.decorationColor != null ||
            override.shadows != null)) {
      throw AssertionError(
        'The CruxTypography override for "$token" carries a color. '
        'An override must not set color, backgroundColor, foreground, '
        'background, decorationColor, or shadows. Tokens carry metrics '
        'only; the color of text is decided by each component from its own '
        'state.',
      );
    }
    return true;
  }

  // Checks all nine overrides, not only the one being resolved: no component
  // in the package reads heading or subheading, so a check scoped to the token
  // being read would let a color baked into either of them survive a whole app
  // run. Written as nine direct calls rather than a table so the check costs
  // no allocation on a path every token read goes through.
  bool _debugCheckOverrides() =>
      _debugCheckOverride('heading', _headingOverride) &&
      _debugCheckOverride('subheading', _subheadingOverride) &&
      _debugCheckOverride('title', _titleOverride) &&
      _debugCheckOverride('body', _bodyOverride) &&
      _debugCheckOverride('caption', _captionOverride) &&
      _debugCheckOverride('captionStrong', _captionStrongOverride) &&
      _debugCheckOverride('labelSmall', _labelSmallOverride) &&
      _debugCheckOverride('label', _labelOverride) &&
      _debugCheckOverride('navLabel', _navLabelOverride);

  TextStyle _resolve(TextStyle apple, TextStyle material, TextStyle? override) {
    // Asserted here rather than in the constructor: reading a field is not a
    // constant expression, so a constructor assert would cost const
    // construction of every scale that carries an override.
    assert(_debugCheckOverrides());
    final TextStyle base = _usesAppleScale ? apple : material;
    // Skipped when there is no scale-wide family: copyWith(fontFamily: null)
    // keeps the base family but still allocates a copy, so the default scale
    // would rebuild each tier's const styles on every token read.
    final TextStyle scaled = fontFamily == null
        ? base
        : base.copyWith(fontFamily: fontFamily);
    // merge returns an inherit: false override verbatim, which is what makes
    // outright replacement work without a branch here.
    return scaled.merge(override);
  }

  /// A screen's main heading.
  ///
  /// 28pt bold on Apple platforms (HIG Title 1 Emphasized); 28pt regular with
  /// a 1.29 line height elsewhere (Material `headlineMedium`).
  TextStyle get heading =>
      _resolve(_appleHeading, _materialHeading, _headingOverride);

  /// A section heading within a screen.
  ///
  /// 22pt bold on Apple platforms (HIG Title 2 Emphasized); 22pt regular with
  /// a 1.27 line height elsewhere (Material `titleLarge`).
  TextStyle get subheading =>
      _resolve(_appleSubheading, _materialSubheading, _subheadingOverride);

  /// The title of a dialog, card, or list row.
  ///
  /// 17pt semibold on Apple platforms (HIG Headline); 16pt medium with a 1.50
  /// line height elsewhere (Material `titleMedium`).
  TextStyle get title => _resolve(_appleTitle, _materialTitle, _titleOverride);

  /// Default body copy, and the text the user types into a field.
  ///
  /// 17pt regular on Apple platforms (HIG Body); 16pt regular with a 1.50
  /// line height elsewhere (Material `bodyLarge`).
  TextStyle get body => _resolve(_appleBody, _materialBody, _bodyOverride);

  /// Secondary text: timestamps, counters, and metadata.
  ///
  /// 12pt regular on Apple platforms (HIG Caption 1); 12pt regular with a
  /// 1.33 line height elsewhere (Material `bodySmall`).
  TextStyle get caption =>
      _resolve(_appleCaption, _materialCaption, _captionOverride);

  /// [caption] at a heavier weight, for text that must stand out at that
  /// size — an error message, or a value readout.
  ///
  /// 12pt semibold on Apple platforms (HIG Caption 1 Emphasized); 12pt medium
  /// elsewhere (Material `labelMedium`).
  TextStyle get captionStrong => _resolve(
    _appleCaptionStrong,
    _materialCaptionStrong,
    _captionStrongOverride,
  );

  /// The label on a compact control: a small button, a chip, a segment, or a
  /// field's own label.
  ///
  /// 13pt semibold on Apple platforms (HIG Footnote Emphasized); 14pt medium
  /// elsewhere (Material `labelLarge`) — Material has no 13pt step, and a
  /// native Android button uses `labelLarge` at every size.
  TextStyle get labelSmall =>
      _resolve(_appleLabelSmall, _materialLabel, _labelSmallOverride);

  /// The label on a standard control: a medium or large button, or a toast.
  ///
  /// 15pt semibold on Apple platforms (HIG Subheadline Emphasized); 14pt
  /// medium elsewhere (Material `labelLarge`, the same style [labelSmall]
  /// resolves to there).
  TextStyle get label => _resolve(_appleLabel, _materialLabel, _labelOverride);

  /// The label under a navigation bar's icon.
  ///
  /// 11pt semibold on Apple platforms (HIG Caption 2 Emphasized); 11pt medium
  /// with a 1.45 line height elsewhere (Material `labelSmall`).
  TextStyle get navLabel =>
      _resolve(_appleNavLabel, _materialNavLabel, _navLabelOverride);

  /// Returns a copy of this scale with the given values replaced.
  ///
  /// A `null` argument means "leave this one alone", so [copyWith] can add or
  /// change an override but never remove one; build a fresh [CruxTypography]
  /// to drop an override.
  CruxTypography copyWith({
    String? fontFamily,
    TargetPlatform? platform,
    TextStyle? heading,
    TextStyle? subheading,
    TextStyle? title,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? captionStrong,
    TextStyle? labelSmall,
    TextStyle? label,
    TextStyle? navLabel,
  }) {
    return CruxTypography(
      fontFamily: fontFamily ?? this.fontFamily,
      platform: platform ?? this.platform,
      heading: heading ?? _headingOverride,
      subheading: subheading ?? _subheadingOverride,
      title: title ?? _titleOverride,
      body: body ?? _bodyOverride,
      caption: caption ?? _captionOverride,
      captionStrong: captionStrong ?? _captionStrongOverride,
      labelSmall: labelSmall ?? _labelSmallOverride,
      label: label ?? _labelOverride,
      navLabel: navLabel ?? _navLabelOverride,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CruxTypography &&
        other.fontFamily == fontFamily &&
        other.platform == platform &&
        other._headingOverride == _headingOverride &&
        other._subheadingOverride == _subheadingOverride &&
        other._titleOverride == _titleOverride &&
        other._bodyOverride == _bodyOverride &&
        other._captionOverride == _captionOverride &&
        other._captionStrongOverride == _captionStrongOverride &&
        other._labelSmallOverride == _labelSmallOverride &&
        other._labelOverride == _labelOverride &&
        other._navLabelOverride == _navLabelOverride;
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    platform,
    _headingOverride,
    _subheadingOverride,
    _titleOverride,
    _bodyOverride,
    _captionOverride,
    _captionStrongOverride,
    _labelSmallOverride,
    _labelOverride,
    _navLabelOverride,
  );
}
