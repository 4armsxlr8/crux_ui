import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// How tall the fade band is, in logical pixels, measured down from the
/// wrapped child's own top edge -- the confirmed 2026-08-05 spec value
/// (`unknowns/navigation-bars/ledger.md`: "フェード帯 160px"). This is also the
/// fixed height every [_BlurLayer] below lays itself out at, so the alpha
/// fade and the blur both act over exactly the same band -- the "全層同一
/// 160px 範囲 + 減衰マスク方式" contract the mock at
/// `unknowns/navigation-bars/mock-appbar-fade.html` was built to prove out: no
/// two layers ever end their own box at a different height, so there is no y
/// where the total effect changes abruptly.
const double _fadeBandHeight = 160;

/// How many color stops [_buildFadeShader] places across [_fadeBandHeight] --
/// the confirmed "5 ストップ" spec, matching the mock's `buildMask(heightPx,
/// stopCount, k)` called with `stopCount = 5`.
const int _fadeStopCount = 5;

/// The power-curve exponent [_buildFadeShader] raises each stop's own
/// position fraction to, biasing where along the band most of the alpha
/// actually drops -- the confirmed "カーブ強度 1.6" spec. Mirrors the mock's
/// `buildMask`, which computes each stop's alpha as `Math.pow(t, k)` for
/// `t` in `0..1`: below 1.0 this would front-load the fade (early stops
/// already fairly opaque-to-transparent), above 1.0 it back-loads it (the
/// content stays close to fully visible until near the very bottom of the
/// band, then drops quickly) -- 1.6 reads as "mostly visible, then dissolves
/// in the last third" rather than a linear ramp.
const double _fadeCurveStrength = 1.6;

/// [CruxTopFade.blurSigma]'s default -- the confirmed "ブラーは既定
/// ON・強度 8px" spec (`unknowns/navigation-bars.md`). Passed straight through
/// to [ImageFilter.blur] as a sigma with no unit conversion, the same
/// convention `segmented_control.dart`'s `_sheenBlurSigma` documents (the
/// mock's CSS blur px values are used as Flutter blur sigmas verbatim).
const double _defaultBlurSigma = 8;

/// How many compounding [_BlurLayer]s [CruxTopFade] stacks whenever
/// [CruxTopFade.blurSigma] is greater than zero -- extracted from the
/// mock's own 6 `.blur-layer` divs (`#blurLayer1`..`#blurLayer6`,
/// `unknowns/navigation-bars/mock-appbar-fade.html`). A single flat
/// `BackdropFilter` reads as one uniformly-blurred pane, not the iOS-style
/// "sharper near the content, near-imperceptible by the band's lower edge"
/// look this is chasing (see that mock's own `blurPanel` note) -- six
/// overlapping layers of different strength and reach, each fading out on
/// its own schedule, is what the mock proved reads as continuous instead.
const int _blurLayerCount = 6;

/// Each [_BlurLayer]'s own blur radius, as a fraction of
/// [CruxTopFade.blurSigma] -- extracted verbatim from the mock's
/// `radiusFractions` array in its `render()` function. Index 0 is the
/// weakest layer (reaches furthest down the band, per
/// [_blurLayerDecayFractions]' matching index); index [_blurLayerCount] - 1
/// is the strongest (`1.0`, i.e. the full [CruxTopFade.blurSigma]) but
/// stays concentrated closest to the very top. Because later layers paint
/// on top of (and therefore blur) everything the earlier layers already
/// blurred, the *effective* blur strength right at the top of the band is
/// the compounded result of all six -- not just this last layer's own
/// fraction.
const List<double> _blurLayerRadiusFractions = <double>[
  0.17,
  0.33,
  0.5,
  0.67,
  0.83,
  1.0,
];

/// Each [_BlurLayer]'s own decay reach, as a fraction of [_fadeBandHeight] --
/// extracted verbatim from the mock's `decayFractions` array. Paired
/// index-for-index with [_blurLayerRadiusFractions]: the *weakest* layer
/// (index 0, `0.17` of [CruxTopFade.blurSigma]) has the *largest* reach
/// (`1.0`, the full band), and the *strongest* layer (index 5, the full
/// [CruxTopFade.blurSigma]) has the *smallest* reach (`0.35`, just over a
/// third of the band). That inverse pairing is what produces the graded
/// look: near the top of the band all six layers overlap (heavy compounded
/// blur), while further down only the weak-but-wide layers still contribute
/// anything, easing the total blur down toward zero by the band's own lower
/// edge instead of cutting off abruptly.
const List<double> _blurLayerDecayFractions = <double>[
  1.0,
  0.87,
  0.74,
  0.61,
  0.48,
  0.35,
];

/// How many steps [_buildBlurLayerDecayShader] samples to build a single
/// blur layer's own decay gradient -- the confirmed "11 finely-spaced
/// stops" the mock's `buildBlurLayerMask` comment calls out (`steps = 10`,
/// looped inclusively as `i <= steps`, i.e. 11 samples), deliberately fixed
/// regardless of [_fadeStopCount]/[_fadeCurveStrength]: per that same
/// comment, a per-layer decay mask is "purely about keeping the blur itself
/// seamless", not a visible hard-vs-soft comparison the way the alpha
/// fade's own stop count is, so it always uses this many, finer-grained
/// samples rather than reusing the alpha fade's coarser 5.
const int _blurLayerDecaySteps = 10;

/// The power-curve exponent each blur layer's own decay gradient is raised
/// to -- the mock's `buildBlurLayerMask` hardcodes `Math.pow(1 - t, 1.6)`
/// regardless of the alpha-fade panel's own curve control (see that
/// function's comment). This happens to equal [_fadeCurveStrength]'s own
/// confirmed value, but the two are independent constants that could
/// diverge later without one accidentally dragging the other along --
/// kept as its own named constant for that reason, not merged with
/// [_fadeCurveStrength].
const double _blurLayerDecayCurveStrength = 1.6;

/// Wraps scrollable content and dissolves it, in place, as it nears
/// [child]'s own top edge -- a static "progressive fade" mask rather than a
/// scroll-position-driven effect (there is no [ScrollController] anywhere in
/// this widget; it never needs to know how far [child] has scrolled). Meant
/// to sit directly over a status bar / safe-area-top region so content
/// scrolling up underneath appears to melt away instead of being hard-cut
/// by the device's own opaque chrome.
///
/// Two effects run at once, both confined to the same [_fadeBandHeight]
/// (160 logical pixels) measured down from [child]'s own top edge:
///
/// 1. **Alpha fade** ([_buildFadeShader]): a [ShaderMask] with
///    [BlendMode.dstIn] over [child], using a [_fadeStopCount]-stop
///    [LinearGradient] biased by [_fadeCurveStrength]. `dstIn` only ever
///    multiplies [child]'s own already-painted alpha -- it never touches
///    color -- so this works identically over light or dark content, and
///    whatever is behind [child] (typically the surrounding page's own
///    background) shows through as it fades, rather than being replaced by
///    some fixed matte color.
/// 2. **Progressive blur** ([_BlurLayer], [blurSigma]): [_blurLayerCount]
///    stacked [BackdropFilter]s, painted on top of the (already
///    alpha-faded) [child], each blurring everything already composited
///    beneath it -- so later layers blur what earlier layers already
///    blurred, compounding into a blur that reads as continuously strong
///    near the very top and continuously weaker toward the band's lower
///    edge, never a single flat pane. Each layer is itself masked by its
///    own [ShaderMask] (see [_buildBlurLayerDecayShader]) so its own
///    contribution fades out smoothly rather than being hard-cut at a
///    box edge -- see [_blurLayerRadiusFractions]'/[_blurLayerDecayFractions]'
///    docs for exactly how the six layers are staggered. The entire blur
///    overlay is wrapped in [IgnorePointer]: it is purely decorative, and
///    every tap/drag must reach [child] (a [Scrollable] in the common case)
///    completely unobstructed.
///
/// Set [blurSigma] to `0` to disable the blur entirely -- doing so skips
/// building any [BackdropFilter] (or the [ShaderMask]/[IgnorePointer]
/// scaffolding around them) at all, rather than merely blurring at a
/// radius of zero, so there is no backdrop-filter compositing cost paid at
/// all when a caller doesn't want the effect (see this package's
/// `unknowns/navigation-bars/impact.md`: "ブラー強度 0 で完全に層を生成しない実
/// 装にし、コスト回避の逃げ道を残す"). The alpha fade above always runs
/// regardless of [blurSigma] -- it is a cheap, single [ShaderMask] with no
/// equivalent off switch.
///
/// This widget reads no [CruxTheme] and no `MediaQuery`: every fraction
/// above is derived purely from [child]'s own rendered size (via
/// [ShaderMask.shaderCallback]'s `bounds` parameter), and there is no color
/// decoration of its own to resolve from a theme -- it is a pure mask over
/// whatever [child] already paints. If [child]'s own rendered height is
/// shorter than [_fadeBandHeight] (an edge case, but a real one -- see
/// `widgetbook/lib/usecases/top_fade.dart`'s Edge cases use case), the
/// alpha fade's own band clamps down to that height instead of overflowing
/// past it (see [_buildFadeShader]); the blur band's own [Positioned]
/// height stays fixed at [_fadeBandHeight] regardless, relying on [Stack]'s
/// default `Clip.hardEdge` clip behavior to crop its paint down to
/// whatever the actual [child] occupies -- deliberately not re-clamped the
/// same way, since doing so would require re-deriving [child]'s size a
/// second time (via a [LayoutBuilder]) for a case [Stack]'s own default
/// clipping already handles for free.
///
/// There is no animation anywhere in this widget (the fade/blur are a
/// static function of [child]'s size, recomputed on every build like any
/// other purely declarative widget), so unlike most other Crux UI atoms
/// there is no `MediaQuery.disableAnimationsOf` ("reduce motion") branch to
/// honor here -- there is no motion to suppress.
class CruxTopFade extends StatelessWidget {
  /// Creates a Crux top fade.
  const CruxTopFade({
    super.key,
    required this.child,
    this.blurSigma = _defaultBlurSigma,
  });

  /// The scrollable content to dissolve near its own top edge. Typically a
  /// [Scrollable] (a `ListView`, a `CustomScrollView`, ...), but any widget
  /// works -- [CruxTopFade] only masks whatever [child] paints, it never
  /// depends on scroll position.
  final Widget child;

  /// The blur's strength, passed straight through to [ImageFilter.blur] as
  /// a sigma (see [_defaultBlurSigma]'s doc for the unit convention).
  /// Defaults to [_defaultBlurSigma] (`8`). Set to `0` to disable the blur
  /// overlay entirely -- see this class's own doc for what that skips.
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: _buildFadeShader,
          child: child,
        ),
        if (blurSigma > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _fadeBandHeight,
            child: IgnorePointer(
              child: ClipRect(
                // Bounds every BackdropFilter below to exactly this band --
                // BackdropFilter's own doc warns it otherwise samples "all
                // the area within its parent or ancestor widget's clip...
                // [or] the full screen", which both wastes work blurring
                // pixels far outside the band and risks visibly smearing
                // content this widget was never meant to touch.
                child: Stack(
                  children: <Widget>[
                    for (int i = 0; i < _blurLayerCount; i++)
                      _BlurLayer(
                        sigma: blurSigma * _blurLayerRadiusFractions[i],
                        decayFraction: _blurLayerDecayFractions[i],
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the alpha-fade gradient shader for [ShaderMask]'s
  /// `shaderCallback`. [bounds] is [child]'s own actual rendered size (in
  /// local coordinates, per [ShaderMask.shaderCallback]'s contract) --
  /// authoritative for how tall [child] really is, unlike an incoming
  /// [BoxConstraints] which could be looser than what [child] actually
  /// occupies.
  ///
  /// Mirrors the mock's `buildMask(heightPx, stopCount, k)`: [_fadeStopCount]
  /// stops at `t = i / (stopCount - 1)` for `i` in `0..stopCount - 1`, each
  /// with alpha `pow(t, k)` (this widget never hits the mock's `stopCount
  /// === 2` linear special case, since [_fadeStopCount] is fixed at 5), plus
  /// one final fully-opaque stop pinned to the very bottom of [bounds] --
  /// guaranteeing everything below the fade band stays completely visible
  /// even though the color stops above only ever explicitly cover
  /// [_fadeBandHeight] worth of pixels.
  ///
  /// Each stop's pixel position (`t * band`) is converted to a fraction of
  /// [bounds]'s own height for [LinearGradient.stops]. `band` is
  /// `min(_fadeBandHeight, bounds.height)` rather than [_fadeBandHeight]
  /// unconditionally: when [child] is shorter than the band (the "shorter
  /// than 160px" edge case), using the unclamped band would push some
  /// stops' fractions past `1.0`, which [LinearGradient] cannot represent --
  /// clamping here instead compresses the whole fade to finish exactly at
  /// [child]'s own bottom edge.
  static Shader _buildFadeShader(Rect bounds) {
    final double height = bounds.height > 0 ? bounds.height : _fadeBandHeight;
    final double band = math.min(_fadeBandHeight, height);
    final List<double> stops = <double>[];
    final List<Color> colors = <Color>[];
    for (int i = 0; i < _fadeStopCount; i++) {
      final double t = i / (_fadeStopCount - 1);
      final double alpha = math.pow(t, _fadeCurveStrength).toDouble();
      final double positionPx = t * band;
      stops.add((positionPx / height).clamp(0.0, 1.0));
      colors.add(Color.fromRGBO(0, 0, 0, alpha));
    }
    stops.add(1.0);
    colors.add(const Color.fromRGBO(0, 0, 0, 1));
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(bounds);
  }
}

/// One compounding blur layer inside [CruxTopFade]'s overlay: a
/// [BackdropFilter] at [sigma], masked by its own top-to-bottom decay
/// gradient reaching [decayFraction] of the way down the band before
/// hitting zero alpha. Returns a [Positioned.fill] directly from [build] so
/// it can be used as a plain item inside the enclosing [Stack]'s `children`
/// list (a [StatelessWidget] introduces no [RenderObject] of its own, so
/// [Positioned]'s [ParentDataWidget] still resolves against the [Stack]
/// exactly as if it were listed inline -- the same pattern a custom badge
/// or floating-action widget would use to place itself inside someone
/// else's [Stack]).
class _BlurLayer extends StatelessWidget {
  const _BlurLayer({required this.sigma, required this.decayFraction});

  /// This layer's own [ImageFilter.blur] sigma -- already
  /// [CruxTopFade.blurSigma] scaled by this layer's
  /// [_blurLayerRadiusFractions] entry.
  final double sigma;

  /// How far down the band (as a fraction of this layer's own rendered
  /// height) this layer's decay gradient reaches before hitting zero alpha
  /// -- this layer's own [_blurLayerDecayFractions] entry.
  final double decayFraction;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) =>
            _buildBlurLayerDecayShader(bounds, decayFraction),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          // BackdropFilter always needs a child to give it a size to lay
          // out at (its own RenderObject sizes itself to match); this one
          // paints nothing of its own (fully transparent, zero-cost),
          // deliberately empty because the visible effect here is entirely
          // the blurred backdrop BackdropFilter paints beneath it, not
          // anything this child itself draws.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Builds one [_BlurLayer]'s own decay-mask shader. [bounds] is that
/// layer's actual rendered size -- always [_fadeBandHeight] tall in
/// practice (every [_BlurLayer] is a [Positioned.fill] inside the band's
/// own fixed-[_fadeBandHeight] [Positioned] box), but read from [bounds]
/// rather than the [_fadeBandHeight] constant directly so this stays
/// correct even if that changes later.
///
/// Mirrors the mock's `buildBlurLayerMask(heightPx, decayFraction)`:
/// [_blurLayerDecaySteps] + 1 stops at `t = i / steps` for `i` in
/// `0..steps`, each with alpha `pow(1 - t, _blurLayerDecayCurveStrength)`
/// (opaque at `t = 0`, the very top of the layer, decaying toward `0` by
/// `t = 1`, i.e. by `decayFraction` of the way down [bounds]), plus one
/// final fully-transparent stop pinned to the very bottom of [bounds] --
/// so a layer whose [decayFraction] is less than `1.0` stays completely
/// transparent (contributing nothing) for the remainder of the band below
/// where its own decay finishes, rather than holding at whatever alpha the
/// last explicit stop left it at.
Shader _buildBlurLayerDecayShader(Rect bounds, double decayFraction) {
  final double height = bounds.height > 0 ? bounds.height : _fadeBandHeight;
  final double decayHeight = height * decayFraction;
  final List<double> stops = <double>[];
  final List<Color> colors = <Color>[];
  for (int i = 0; i <= _blurLayerDecaySteps; i++) {
    final double t = i / _blurLayerDecaySteps;
    final double alpha = math
        .pow(1 - t, _blurLayerDecayCurveStrength)
        .toDouble();
    final double positionPx = t * decayHeight;
    stops.add((positionPx / height).clamp(0.0, 1.0));
    colors.add(Color.fromRGBO(0, 0, 0, alpha));
  }
  stops.add(1.0);
  colors.add(const Color.fromRGBO(0, 0, 0, 0));
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
    stops: stops,
  ).createShader(bounds);
}
