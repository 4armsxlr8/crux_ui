import 'package:flutter/painting.dart';

/// Semantic shadow and scrim tokens for Crux UI.
///
/// Like `CruxColors`, every field is a semantic name ([sm], [md], [lg],
/// [scrim], [hairline], [ink]) rather than a raw shadow recipe, so call
/// sites never hardcode a [BoxShadow] list or a scrim [Color]. The semantic
/// names are the stable API this package commits to; the raw offsets, blur
/// radii, and colors behind them may still be re-tuned. Raw shadow and
/// scrim values are allowed only in this file -- never hardcode one
/// elsewhere, or a future palette swap stops being a one-file diff.
///
/// Use [CruxShadows.light] or [CruxShadows.dark] to pick a palette, or
/// construct a custom instance for a bespoke brightness.
///
/// **Mutability contract**: [sm], [md], [lg], [thumb], [thumbLifted], and
/// [xs] are `List<BoxShadow>`, not a runtime-immutable collection, because a
/// `const` constructor cannot wrap an incoming list in `List.unmodifiable`.
/// [light] and [dark] are safe because every list literal they pass is
/// itself `const`. A custom [CruxShadows] built with an ordinary mutable
/// list is not protected the same way: treat every list field as immutable
/// once passed to the constructor. Mutating one in place afterward is a
/// silent contract violation -- [CruxThemeData]'s `operator==` and
/// `updateShouldNotify` compare these lists element-by-element on every
/// call, not against a construction-time snapshot, so an in-place mutation
/// can make a theme compare unequal to itself or skip a rebuild it should
/// have triggered.
class CruxShadows {
  /// Creates a set of semantic shadow and scrim tokens.
  const CruxShadows({
    required this.sm,
    required this.md,
    required this.lg,
    required this.scrim,
    required this.hairline,
    required this.ink,
    required this.thumb,
    required this.thumbLifted,
    required this.xs,
  });

  /// The light shadow/scrim palette.
  static const CruxShadows light = CruxShadows(
    sm: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.16),
        offset: Offset(0, 6),
        blurRadius: 14,
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.10),
        offset: Offset(0, 2),
        blurRadius: 5,
        spreadRadius: -1,
      ),
    ],
    md: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.18),
        offset: Offset(0, 14),
        blurRadius: 30,
        spreadRadius: -10,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.10),
        offset: Offset(0, 4),
        blurRadius: 10,
        spreadRadius: -4,
      ),
    ],
    lg: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.22),
        offset: Offset(0, 24),
        blurRadius: 48,
        spreadRadius: -14,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.12),
        offset: Offset(0, 10),
        blurRadius: 20,
        spreadRadius: -10,
      ),
    ],
    scrim: Color.fromRGBO(38, 37, 30, 0.32),
    hairline: Color.fromRGBO(38, 37, 30, 0),
    ink: Color(0xFF26251E),
    thumb: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.28),
        offset: Offset(0, 3),
        blurRadius: 8,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.20),
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.05),
        offset: Offset.zero,
        blurRadius: 0,
        spreadRadius: 1,
      ),
    ],
    thumbLifted: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.30),
        offset: Offset(0, 6),
        blurRadius: 16,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.22),
        offset: Offset(0, 2),
        blurRadius: 6,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.05),
        offset: Offset.zero,
        blurRadius: 0,
        spreadRadius: 1,
      ),
    ],
    xs: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.10),
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ],
  );

  /// The dark shadow/scrim palette.
  static const CruxShadows dark = CruxShadows(
    sm: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(0, 6),
        blurRadius: 14,
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.35),
        offset: Offset(0, 2),
        blurRadius: 6,
        spreadRadius: -1,
      ),
    ],
    md: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(0, 14),
        blurRadius: 30,
        spreadRadius: -10,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.35),
        offset: Offset(0, 4),
        blurRadius: 12,
        spreadRadius: -4,
      ),
    ],
    lg: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.55),
        offset: Offset(0, 24),
        blurRadius: 48,
        spreadRadius: -14,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.4),
        offset: Offset(0, 10),
        blurRadius: 24,
        spreadRadius: -10,
      ),
    ],
    scrim: Color.fromRGBO(0, 0, 0, 0.55),
    hairline: Color.fromRGBO(246, 245, 239, 0.10),
    ink: Color(0xFF000000),
    thumb: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.28),
        offset: Offset(0, 3),
        blurRadius: 8,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.20),
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.05),
        offset: Offset.zero,
        blurRadius: 0,
        spreadRadius: 1,
      ),
    ],
    thumbLifted: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.30),
        offset: Offset(0, 6),
        blurRadius: 16,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.22),
        offset: Offset(0, 2),
        blurRadius: 6,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.05),
        offset: Offset.zero,
        blurRadius: 0,
        spreadRadius: 1,
      ),
    ],
    xs: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.30),
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ],
  );

  /// The small shadow, for compact elevated elements such as a switch
  /// knob. Two [BoxShadow] layers.
  final List<BoxShadow> sm;

  /// The medium shadow, for elements such as a toast card. Two [BoxShadow]
  /// layers.
  final List<BoxShadow> md;

  /// The large shadow, for elements such as a floating dialog card. Two
  /// [BoxShadow] layers.
  final List<BoxShadow> lg;

  /// The background dim painted behind a modal surface such as a dialog.
  final Color scrim;

  /// A 1px outline color for components whose shadow alone does not read
  /// clearly against the surface behind them (for example a toast in dark
  /// mode, where [ink]'s shadow sinks into a similarly dark background).
  /// Fully transparent in [light] rather than omitted, so a caller can
  /// always paint an unconditional 1px border in this color: no visible
  /// border in light, a visible one in dark, with no brightness-specific
  /// branch.
  final Color hairline;

  /// The opaque base color the [sm], [md], and [lg] shadows are washes of.
  /// Published so other components can derive their own translucent
  /// overlays from the same ink with `ink.withValues(alpha: ...)` — the
  /// same technique `CruxColors.mutedFill` already documents as a
  /// wash of `textPrimary`, applied here to shadow-adjacent decorations
  /// (for example a slider thumb's grip lines) instead of a fill.
  final Color ink;

  /// A compact, outline-leaning shadow for a small elevated control's cap
  /// or knob that would otherwise blend into a background/fill close to it
  /// in luminance (for example [CruxSlider]'s thumb) -- a tighter, more
  /// concentrated recipe than [sm], with a third zero-blur/1px-spread layer
  /// that reads as an ambient outline. Three [BoxShadow] layers.
  final List<BoxShadow> thumb;

  /// [thumb], further lifted for the moment such a control is actively
  /// being manipulated (for example [CruxSlider]'s thumb while being
  /// dragged): larger offset and blur on the first two layers, so the
  /// control visibly rises further off the surface behind it. Three
  /// [BoxShadow] layers.
  final List<BoxShadow> thumbLifted;

  /// The extra-small shadow, for a face that should read as only barely
  /// lifted off whatever sits directly behind it -- for example
  /// [CruxSegmentedControl]'s selection plate, which signals "a hair in
  /// front of its track" rather than the eye-catching elevation [sm] gives
  /// a switch knob. One [BoxShadow] layer: a short `(0, 1)` offset, `3`px
  /// blur, no spread. Every metric here (offset, blur, alpha) is smaller
  /// than every layer in [sm], not just one of the three, so [xs] reads as
  /// strictly more subdued than [sm] rather than merely different from it
  /// -- pinned by `test/tokens/shadows_test.dart`. [dark]'s alpha is
  /// roughly 3x [light]'s, matching [sm]/[md]/[lg]'s own ratio: a shadow
  /// this faint needs the extra contrast to read against a dark
  /// background at all. Deliberately a single layer -- unlike
  /// [sm]/[md]/[lg]/[thumb]/[thumbLifted], which combine a thrown shadow
  /// with a tighter contact shadow or outline layer, a second layer here
  /// would fight the "barely there" brief this token exists for.
  final List<BoxShadow> xs;
}
