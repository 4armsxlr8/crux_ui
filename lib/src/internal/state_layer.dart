import 'dart:ui' show Color;

import '../tokens/colors.dart';

/// The opacity of the state layer laid over a pressed atom's background:
/// [CruxColors.textPrimary] at 8%, which reads as darkening in light mode
/// and lightening in dark mode without a second, brightness-specific token.
const double _pressedOverlayOpacity = 0.08;

/// The pressed-state overlay opacity for an [CruxColors.accent]-filled atom
/// specifically, lower than [_pressedOverlayOpacity].
///
/// [CruxColors.onAccent] (the label color on an accent fill) and the
/// overlay color ([CruxColors.textPrimary]) are the exact same value in
/// both palettes, so any overlay alpha moves the pressed background
/// directly toward the label color and can only shrink their contrast,
/// never grow it. The shared 8% overlay would drop onAccent-vs-background
/// contrast to 4.353:1 -- under the 4.5:1 AA floor for normal-size text;
/// 5% keeps it at 4.549:1 (light) / 5.163:1 (dark).
const double _pressedOverlayOpacityAccent = 0.05;

/// Resolves the background a pressable atom paints while pressed: the
/// pressed-state overlay layered over [base], the atom's rest-state
/// background.
///
/// Callers decide *when* the atom is pressed; this only resolves the color.
/// [base] is `null` for an atom that paints no fill at rest (a ghost
/// `CruxButton`), in which case the overlay itself, at its own alpha, is the
/// pressed background. A translucent [base] such as [CruxColors.mutedFill]
/// is composited by [Color.alphaBlend], which keeps the combined alpha, so
/// the result still reads correctly over whatever the atom sits on.
///
/// An [CruxColors.accent] base gets a lighter overlay than every other fill
/// (see [_pressedOverlayOpacityAccent] for the contrast constraint behind
/// that), so every accent-filled atom -- a filled `CruxButton`, a selected
/// `CruxChip` -- darkens identically and none can drift below AA on its
/// own.
Color pressedStateLayer({required CruxColors colors, required Color? base}) {
  final double overlayOpacity = base == colors.accent
      ? _pressedOverlayOpacityAccent
      : _pressedOverlayOpacity;
  final Color overlay = colors.textPrimary.withValues(alpha: overlayOpacity);
  if (base == null) {
    return overlay;
  }
  return Color.alphaBlend(overlay, base);
}
