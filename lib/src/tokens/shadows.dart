import 'package:flutter/painting.dart';

/// Semantic shadow and scrim tokens for Crux UI.
///
/// Like `CruxColors`, every field is a semantic name ([sm], [md], [lg],
/// [scrim], [hairline], [ink]) rather than a raw shadow recipe, so call
/// sites never hardcode a [BoxShadow] list or a scrim [Color]. The current
/// values are a provisional recipe carried over from
/// mock case B ("soft shadow", `unknowns/atoms-batch-3/mock-b-shadow.html`) —
/// the semantic names are the stable API this package commits to; the raw
/// offsets, blur radii, and colors behind them may still be re-tuned. Raw
/// shadow values live in this file only, matching the rule already in
/// place for color values in `colors.dart`: if either recipe changes later,
/// this is the single file that needs to change.
///
/// Use [CruxShadows.light] or [CruxShadows.dark] to pick a palette, or
/// construct a custom instance for a bespoke brightness.
///
/// **Mutability contract**: [sm], [md], [lg], [thumb], [thumbLifted], and
/// [xs] are typed `List<BoxShadow>` rather than a fixed-length or otherwise
/// runtime-immutable collection, because a `const` constructor cannot itself
/// wrap an incoming list in `List.unmodifiable` (that call is not a
/// constant expression). [light] and [dark] are safe regardless: every list
/// literal they pass in is itself `const`, and Dart's own const lists throw
/// on any attempted mutation, so those two built-in presets can never be
/// changed after the fact. A custom [CruxShadows] built with an ordinary
/// (non-`const`) mutable list, however, is not protected the same way --
/// this class treats every list field as effectively immutable once passed
/// to the constructor, and callers must not mutate it afterward (append,
/// remove, or index-assign into it). Mutating one in place is a silent
/// contract violation: [CruxThemeData]'s `operator==` and
/// `updateShouldNotify` compare these lists element-by-element at whatever
/// moment they happen to run, not against a snapshot taken at construction,
/// so an in-place mutation can make a theme compare unequal to itself
/// between two reads, or fail to notify a rebuild that should have fired.
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
    // The mock's light `--toast-border` is `none`: dark surfaces need a
    // hairline to keep their outline legible once the shadow sinks into a
    // similarly dark background, but light surfaces already contrast
    // against the light background without one. Represented as fully
    // transparent (rather than omitting the token) so callers can always
    // unconditionally paint a 1px border of this color and get the mock's
    // "no border" result in light without a brightness-specific `if`.
    hairline: Color.fromRGBO(38, 37, 30, 0),
    ink: Color(0xFF26251E),
    // `CruxSlider`'s thumb (a "physical fader cap") is `surface` (white in
    // light) sitting directly on `background`/`controlFill`, both close in
    // luminance -- `sm` alone reads too faint to separate the cap from what
    // is behind it, so the mock gives the thumb its own, more concentrated
    // recipe: a tighter, higher-opacity two-layer wash plus a third,
    // zero-blur/1px-spread layer that acts as an ambient outline (the CSS
    // `0 0 0 1px` idiom -- no offset, no blur, only spread -- for "trace a
    // hairline around the shape using a shadow instead of a border").
    // Transcribed from the mock's `.slider-thumb` `box-shadow`.
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
    // The same thumb, while it is being dragged: a further-lifted variant of
    // [thumb] (larger offset/blur on the first two layers, same 1px ambient
    // outline layer), matching the confirmed spec's "ドラッグ中はさらに浮く".
    // Transcribed from the mock's `.slider-thumb.is-dragging` `box-shadow`.
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
    // The confirmed 2026-08-02 "選択プレートの影を控えめに" spec: a single,
    // near, low-opacity layer for a face that should read as barely lifted
    // off whatever is behind it (contrast [sm]'s two-layer, further-thrown
    // recipe, tuned for a switch knob that needs to visibly separate).
    // Alpha picked at the low end of the confirmed 0.10-0.12 starting range
    // -- see [xs]'s own doc for why.
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
    // Dark surfaces sit close in luminance to the dark background, so a
    // black shadow alone all but disappears — the mock pairs it with a 1px
    // near-transparent textPrimary hairline to keep the outline visible.
    hairline: Color.fromRGBO(246, 245, 239, 0.10),
    ink: Color(0xFF000000),
    // Same recipe as [light]'s [thumb], washed in black instead of the ink
    // used in light (dark's `--shadow-ink` is `0, 0, 0`, matching how [sm],
    // [md], and [lg] above already re-ink themselves for dark). Transcribed
    // from the mock's `.slider-thumb` `box-shadow` with dark's `--shadow-ink`
    // substituted in.
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
    // Same recipe as [light]'s [thumbLifted], washed in black -- see [thumb]
    // above for why dark substitutes black for [light]'s textPrimary-derived
    // ink. Transcribed from the mock's `.slider-thumb.is-dragging`
    // `box-shadow` with dark's `--shadow-ink` substituted in.
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
    // Same recipe as [light]'s [xs], washed in black at a higher alpha (0.30
    // vs. light's 0.10) -- see [xs]'s own doc for why dark needs more
    // contrast to read at all, the same reasoning [sm]/[md]/[lg] already
    // apply at roughly the same 2.5x-3.5x light->dark ratio.
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
  /// knob. Two [BoxShadow] layers, matching the mock's `--shadow-sm`.
  final List<BoxShadow> sm;

  /// The medium shadow, for elements such as a toast card. Two [BoxShadow]
  /// layers, matching the mock's `--shadow-md`.
  final List<BoxShadow> md;

  /// The large shadow, for elements such as a floating dialog card. Two
  /// [BoxShadow] layers, matching the mock's `--shadow-lg`.
  final List<BoxShadow> lg;

  /// The background dim painted behind a modal surface such as a dialog,
  /// matching the mock's `--scrim-color`.
  final Color scrim;

  /// A 1px outline color for components whose shadow alone does not read
  /// clearly against the surface behind them (for example a toast in dark
  /// mode, where [ink]'s shadow sinks into a similarly dark background).
  /// Fully transparent in [light], where the shadow reads on its own,
  /// matching the mock's `--toast-border`.
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
  /// that reads as an ambient outline. Three [BoxShadow] layers, matching
  /// the mock's `.slider-thumb` `box-shadow`.
  final List<BoxShadow> thumb;

  /// [thumb], further lifted for the moment such a control is actively
  /// being manipulated (for example [CruxSlider]'s thumb while being
  /// dragged): larger offset and blur on the first two layers, so the
  /// control visibly rises further off the surface behind it. Three
  /// [BoxShadow] layers, matching the mock's `.slider-thumb.is-dragging`
  /// `box-shadow`.
  final List<BoxShadow> thumbLifted;

  /// The extra-small shadow, for a face that should read as only barely
  /// lifted off whatever sits directly behind it -- for example
  /// [CruxSegmentedControl]'s selection plate, which needs to signal "this
  /// is a hair in front of its track", not draw eye-catching elevation the
  /// way [sm] (tuned for a switch knob that must visibly separate from its
  /// track) does. Confirmed 2026-08-02 ("選択プレートの影を控えめにしたい",
  /// referencing iOS's near-flush tab-switch plate): a single [BoxShadow]
  /// layer -- a short `(0, 1)` offset, a `3`px blur, no spread -- washed at
  /// `0.10` alpha in [light] (the low end of a confirmed `0.10`-`0.12`
  /// starting range) and `0.30` in [dark]. Every metric here (offset, blur,
  /// and alpha) is deliberately smaller than every layer in [sm], not just
  /// one of the three, so [xs] reads as strictly more subdued than [sm]
  /// rather than merely different from it -- see
  /// `test/tokens/shadows_test.dart`'s "xs reads more subdued than sm"
  /// checks. [dark]'s alpha sits at roughly 3x [light]'s rather than the
  /// same value in both, matching [sm]/[md]/[lg]'s own ~2.5x-3.5x light ->
  /// dark ratio: a shadow this faint sinks into a dark background before it
  /// sinks into a light one, so dark needs the extra contrast just to read
  /// at all. One [BoxShadow] layer, matching this token's own minimal
  /// "barely there" brief -- unlike [sm]/[md]/[lg]/[thumb]/[thumbLifted],
  /// which all use two or three layers to combine a thrown shadow with a
  /// tighter contact shadow (or an ambient-outline layer), [xs] has no
  /// second layer to combine with: adding one would immediately fight the
  /// "almost not there" brief this token exists for.
  final List<BoxShadow> xs;
}
