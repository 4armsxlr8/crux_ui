import 'package:flutter/painting.dart';

/// Semantic shadow and scrim tokens for Crux UI.
///
/// Like `CruxColors`, every field is a semantic name ([contact], [scrim],
/// [hairline], [ink]) rather than a raw shadow recipe, so call sites never
/// hardcode a [BoxShadow] list or a scrim [Color]. The semantic names are
/// the stable API this package commits to; the raw offsets, blur radii, and
/// colors behind them may still be re-tuned. Raw shadow and scrim values
/// are allowed only in this file -- never hardcode one elsewhere, or a
/// future palette swap stops being a one-file diff.
///
/// Use [CruxShadows.light] or [CruxShadows.dark] to pick a palette, or
/// construct a custom instance for a bespoke brightness.
///
/// **Mutability contract**: [contact] is a `List<BoxShadow>`, not a
/// runtime-immutable collection, because a `const` constructor cannot wrap
/// an incoming list in `List.unmodifiable`. [light] and [dark] are safe
/// because the list literal they pass is itself `const`. A custom
/// [CruxShadows] built with an ordinary mutable list is not protected the
/// same way: treat the list field as immutable once passed to the
/// constructor. Mutating it in place afterward is a silent contract
/// violation -- [CruxThemeData]'s `operator==` and `updateShouldNotify`
/// compare it element-by-element on every call, not against a
/// construction-time snapshot, so an in-place mutation can make a theme
/// compare unequal to itself or skip a rebuild it should have triggered.
class CruxShadows {
  /// Creates a set of semantic shadow and scrim tokens.
  const CruxShadows({
    required this.contact,
    required this.scrim,
    required this.hairline,
    required this.ink,
  });

  /// The light shadow/scrim palette.
  static const CruxShadows light = CruxShadows(
    contact: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.04),
        offset: Offset(0, 1),
        blurRadius: 2,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(38, 37, 30, 0.05),
        offset: Offset.zero,
        blurRadius: 0,
        spreadRadius: 1,
      ),
    ],
    scrim: Color.fromRGBO(38, 37, 30, 0.32),
    hairline: Color.fromRGBO(38, 37, 30, 0),
    ink: Color(0xFF26251E),
  );

  /// The dark shadow/scrim palette.
  static const CruxShadows dark = CruxShadows(
    contact: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.14),
        offset: Offset(0, 1),
        blurRadius: 2,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.05),
        offset: Offset.zero,
        blurRadius: 0,
        spreadRadius: 1,
      ),
    ],
    scrim: Color.fromRGBO(0, 0, 0, 0.55),
    hairline: Color.fromRGBO(246, 245, 239, 0.10),
    ink: Color(0xFF000000),
  );

  /// The one elevation shadow in this kit, used uniformly by every surface
  /// that sits on top of another (a floating pill, a toast, a dialog, a
  /// slider thumb, and so on). Two [BoxShadow] layers: an almost
  /// imperceptible contact shadow plus a zero-blur, 1px-spread ambient
  /// ring that reads as an outline. There is no ladder of elevation
  /// depths here -- this kit expresses hierarchy with color and [scrim],
  /// not with how far a shadow throws.
  final List<BoxShadow> contact;

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

  /// The opaque base color the [contact] shadow is a wash of. Published so
  /// other components can derive their own translucent overlays from the
  /// same ink with `ink.withValues(alpha: ...)` — the same technique
  /// `CruxColors.mutedFill` already documents as a wash of `textPrimary`,
  /// applied here to shadow-adjacent decorations (for example a slider
  /// thumb's grip lines) instead of a fill.
  final Color ink;
}
