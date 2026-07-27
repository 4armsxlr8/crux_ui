/// The fixed, 4px-based spacing scale used across Crux UI.
///
/// Unlike colors or typography, spacing does not vary by theme or
/// brightness: these are plain constants, so they can be used directly
/// (`CruxSpacing.s16`) without a Crux theme in scope.
class CruxSpacing {
  const CruxSpacing._();

  /// 2 logical pixels.
  static const double s2 = 2;

  /// 4 logical pixels.
  static const double s4 = 4;

  /// 8 logical pixels.
  static const double s8 = 8;

  /// 12 logical pixels.
  static const double s12 = 12;

  /// 16 logical pixels.
  static const double s16 = 16;

  /// 20 logical pixels.
  static const double s20 = 20;

  /// 24 logical pixels.
  static const double s24 = 24;

  /// 32 logical pixels.
  static const double s32 = 32;

  /// 40 logical pixels.
  static const double s40 = 40;

  /// 48 logical pixels.
  static const double s48 = 48;
}
