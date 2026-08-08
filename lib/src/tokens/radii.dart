import 'spacing.dart';

/// The fixed corner-radius scale used across Crux UI.
///
/// Like [CruxSpacing], radii do not vary by theme or brightness: these are
/// plain constants, so they can be used directly (`CruxRadii.l`) without a
/// Crux theme in scope.
///
/// A radius from this scale is never painted as a plain circular-arc rounded
/// rectangle: every Crux component that draws a rounded corner (a filled
/// background, a border, or both together) shapes it as a superellipse — the
/// smoother, "squircle" corner style iOS uses (`UIBezierPath
/// (roundedRect:cornerRadius:)`'s `.continuous` style, and SwiftUI's
/// `RoundedRectangle(cornerRadius:style: .continuous)`), painted via
/// Flutter's `RoundedSuperellipseBorder`, not `RoundedRectangleBorder`. A
/// value from this scale is still just "how far the corner is rounded, in
/// logical pixels" — it does not change meaning across the two shapes — but
/// the actual curve it produces is a superellipse arc rather than a
/// circular one.
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
