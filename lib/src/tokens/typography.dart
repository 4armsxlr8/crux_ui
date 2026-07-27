import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// The Crux type scale: six [TextStyle] tokens covering everything from
/// hero-level headings ([display]) down to timestamps and metadata
/// ([caption]).
///
/// Font size, line height, and weight are fixed per K10 and are not
/// configurable. The font family is the one thing this scale lets you
/// override, via the [fontFamily] constructor parameter, so apps that ship
/// a custom font can plug it in without hardcoding it at every call site.
/// Leaving [fontFamily] unset uses the platform's default system font.
class CruxTypography {
  /// Creates a type scale, optionally overriding the font family used by
  /// every style. Pass `null` (the default) to use the platform's system
  /// font.
  const CruxTypography({this.fontFamily});

  /// The font family applied to every style in this scale, or `null` to use
  /// the platform's default system font.
  final String? fontFamily;

  static const TextStyle _display = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle _headline = TextStyle(
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle _title = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle _body = TextStyle(
    fontSize: 16,
    height: 25 / 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle _caption = TextStyle(
    fontSize: 12,
    height: 17 / 12,
    fontWeight: FontWeight.w400,
  );

  /// 28px / 36px line height, weight 700. For hero-level headings.
  TextStyle get display => _display.copyWith(fontFamily: fontFamily);

  /// 22px / 30px line height, weight 700. For section headings.
  TextStyle get headline => _headline.copyWith(fontFamily: fontFamily);

  /// 17px / 24px line height, weight 600. For card and list titles.
  TextStyle get title => _title.copyWith(fontFamily: fontFamily);

  /// 16px / 25px line height, weight 400. For the default body copy.
  TextStyle get body => _body.copyWith(fontFamily: fontFamily);

  /// 14px / 20px line height, weight 600. For button and chip labels.
  TextStyle get label => _label.copyWith(fontFamily: fontFamily);

  /// 12px / 17px line height, weight 400. For timestamps and metadata.
  TextStyle get caption => _caption.copyWith(fontFamily: fontFamily);
}
