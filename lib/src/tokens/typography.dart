import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/painting.dart'
    show FontWeight, TextBaseline, TextLeadingDistribution, TextStyle;

/// The Crux type scale: nine semantic [TextStyle] tokens that resolve to the
/// host platform's own type scale.
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
/// Sizes, weights, letter spacing, and line height are fixed per platform and
/// are not configurable. The font family is the one thing this scale lets you
/// override, via the [fontFamily] constructor parameter; it replaces the
/// family on both tiers at once. Leaving [fontFamily] unset uses each
/// platform's system font.
class CruxTypography {
  /// Creates a type scale.
  ///
  /// Pass [fontFamily] to override the family used by every style; leave it
  /// unset (the default) to use each platform's system font. Pass [platform]
  /// to pin which platform's scale is used — tests and golden files should
  /// always pin it; production code should leave it unset so it follows
  /// [defaultTargetPlatform].
  const CruxTypography({this.fontFamily, this.platform});

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

  TextStyle _resolve(TextStyle apple, TextStyle material) {
    final TextStyle base = _usesAppleScale ? apple : material;
    // copyWith(fontFamily: null) keeps the base family, so an unset
    // fontFamily leaves each tier's own family in place.
    return base.copyWith(fontFamily: fontFamily);
  }

  /// A screen's main heading.
  ///
  /// 28pt bold on Apple platforms (HIG Title 1 Emphasized); 28pt regular with
  /// a 1.29 line height elsewhere (Material `headlineMedium`).
  TextStyle get heading => _resolve(_appleHeading, _materialHeading);

  /// A section heading within a screen.
  ///
  /// 22pt bold on Apple platforms (HIG Title 2 Emphasized); 22pt regular with
  /// a 1.27 line height elsewhere (Material `titleLarge`).
  TextStyle get subheading => _resolve(_appleSubheading, _materialSubheading);

  /// The title of a dialog, card, or list row.
  ///
  /// 17pt semibold on Apple platforms (HIG Headline); 16pt medium with a 1.50
  /// line height elsewhere (Material `titleMedium`).
  TextStyle get title => _resolve(_appleTitle, _materialTitle);

  /// Default body copy, and the text the user types into a field.
  ///
  /// 17pt regular on Apple platforms (HIG Body); 16pt regular with a 1.50
  /// line height elsewhere (Material `bodyLarge`).
  TextStyle get body => _resolve(_appleBody, _materialBody);

  /// Secondary text: timestamps, counters, and metadata.
  ///
  /// 12pt regular on Apple platforms (HIG Caption 1); 12pt regular with a
  /// 1.33 line height elsewhere (Material `bodySmall`).
  TextStyle get caption => _resolve(_appleCaption, _materialCaption);

  /// [caption] at a heavier weight, for text that must stand out at that
  /// size — an error message, or a value readout.
  ///
  /// 12pt semibold on Apple platforms (HIG Caption 1 Emphasized); 12pt medium
  /// elsewhere (Material `labelMedium`).
  TextStyle get captionStrong =>
      _resolve(_appleCaptionStrong, _materialCaptionStrong);

  /// The label on a compact control: a small button, a chip, a segment, or a
  /// field's own label.
  ///
  /// 13pt semibold on Apple platforms (HIG Footnote Emphasized); 14pt medium
  /// elsewhere (Material `labelLarge`) — Material has no 13pt step, and a
  /// native Android button uses `labelLarge` at every size.
  TextStyle get labelSmall => _resolve(_appleLabelSmall, _materialLabel);

  /// The label on a standard control: a medium or large button, or a toast.
  ///
  /// 15pt semibold on Apple platforms (HIG Subheadline Emphasized); 14pt
  /// medium elsewhere (Material `labelLarge`, the same style [labelSmall]
  /// resolves to there).
  TextStyle get label => _resolve(_appleLabel, _materialLabel);

  /// The label under a navigation bar's icon.
  ///
  /// 11pt semibold on Apple platforms (HIG Caption 2 Emphasized); 11pt medium
  /// with a 1.45 line height elsewhere (Material `labelSmall`).
  TextStyle get navLabel => _resolve(_appleNavLabel, _materialNavLabel);
}
