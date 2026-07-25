import 'spacing.dart';

/// The fixed corner-radius scale used across Crux UI.
///
/// Like [CruxSpacing], radii do not vary by theme or brightness: these are
/// plain constants, so they can be used directly (`CruxRadii.l`) without a
/// Crux theme in scope.
class CruxRadii {
  const CruxRadii._();

  /// 14 logical pixels. A medium corner radius for compact surfaces.
  static const double m = 14;

  /// 16 logical pixels. The default corner radius for larger surfaces such
  /// as `CruxCard`.
  static const double l = 16;

  /// 9999 logical pixels — large enough to always round a shape's shortest
  /// side into a full pill/stadium, regardless of that side's length.
  static const double pill = 9999;
}
