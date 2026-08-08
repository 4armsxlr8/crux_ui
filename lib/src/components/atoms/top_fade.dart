import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// How tall the fade band is, in logical pixels, measured down from the
/// wrapped child's own top edge. Every [_BlurLayer] also lays itself out
/// at this same height, so the alpha fade and the blur both act over
/// exactly the same band, with no height mismatch between layers.
const double _fadeBandHeight = 160;

/// How many color stops [_buildFadeShader] places across [_fadeBandHeight].
const int _fadeStopCount = 5;

/// The power-curve exponent [_buildFadeShader] raises each stop's own
/// position fraction to. Above 1.0 the content stays mostly visible and
/// then dissolves quickly near the end of the band; below 1.0 it fades
/// earlier and more gradually.
const double _fadeCurveStrength = 1.6;

/// [CruxTopFade.blurSigma]'s default. Passed straight through to
/// [ImageFilter.blur] as a sigma, with no unit conversion.
const double _defaultBlurSigma = 8;

/// How many compounding [_BlurLayer]s [CruxTopFade] stacks whenever
/// [CruxTopFade.blurSigma] is greater than zero. A single flat
/// [BackdropFilter] reads as one uniformly-blurred pane; six overlapping
/// layers of different strength and reach produce the "sharper near the
/// content, fading out toward the band's edge" look instead.
const int _blurLayerCount = 6;

/// Each [_BlurLayer]'s own blur radius, as a fraction of
/// [CruxTopFade.blurSigma]. Paired index-for-index with
/// [_blurLayerDecayFractions] -- reordering one without the other breaks
/// the graded look. Index 0 is the weakest layer (widest reach, per the
/// paired array); the last index is the strongest (`1.0`, the full
/// [CruxTopFade.blurSigma]) but stays concentrated nearest the top.
/// Later layers blur what earlier layers already blurred, so the
/// effective strength at the very top is the compounded result of all
/// six, not just the last layer's own fraction.
const List<double> _blurLayerRadiusFractions = <double>[
  0.17,
  0.33,
  0.5,
  0.67,
  0.83,
  1.0,
];

/// Each [_BlurLayer]'s own decay reach, as a fraction of [_fadeBandHeight].
/// Paired index-for-index with [_blurLayerRadiusFractions]: the weakest
/// layer has the largest reach (`1.0`, the full band) and the strongest
/// has the smallest (`0.35`) -- that inverse pairing is what grades the
/// total blur from heavy near the top to near-zero by the band's lower
/// edge, instead of cutting off abruptly.
const List<double> _blurLayerDecayFractions = <double>[
  1.0,
  0.87,
  0.74,
  0.61,
  0.48,
  0.35,
];

/// How many steps [_buildBlurLayerDecayShader] samples to build one blur
/// layer's own decay gradient. Fixed independently of [_fadeStopCount]: a
/// per-layer decay mask only needs to keep the blur itself seamless, not
/// stand up to the visible hard-vs-soft comparison the alpha fade's own
/// stop count does.
const int _blurLayerDecaySteps = 10;

/// The power-curve exponent each blur layer's own decay gradient is
/// raised to. Equals [_fadeCurveStrength]'s value today, but kept as its
/// own constant since the two govern independent curves that could
/// diverge later.
const double _blurLayerDecayCurveStrength = 1.6;

/// Wraps scrollable content and dissolves it, in place, near [child]'s own
/// top edge -- a static mask, not a scroll-driven effect: there is no
/// [ScrollController] anywhere in this widget, and nothing is recomputed
/// as [child] scrolls. Meant to sit over a status bar / safe-area-top
/// region so content scrolling up underneath melts away instead of being
/// hard-cut by the device's own opaque chrome.
///
/// Two effects run together, both confined to the same 160-logical-pixel
/// band measured down from [child]'s own top edge:
///
/// 1. **Alpha fade**: a [ShaderMask] with [BlendMode.dstIn] over [child].
///    `dstIn` only multiplies [child]'s already-painted alpha, never its
///    color, so this reads correctly over light or dark content and lets
///    whatever is behind [child] show through as it fades, rather than
///    being replaced by a fixed matte color.
/// 2. **Progressive blur** (when [blurSigma] is greater than zero): six
///    stacked, gradient-masked [BackdropFilter] layers painted on top of
///    the already-faded [child], compounding into a blur that reads as
///    strong near the very top and eases toward nothing by the band's
///    lower edge, never a single flat pane. The whole overlay is wrapped
///    in [IgnorePointer]: it is purely decorative, and every tap/drag
///    reaches [child] (a [Scrollable] in the common case) unobstructed.
///
/// Set [blurSigma] to `0` to disable the blur entirely: this skips
/// building any [BackdropFilter] at all, rather than merely blurring at a
/// radius of zero, so there is no backdrop-filter compositing cost paid
/// when a caller doesn't want the effect. The alpha fade above always
/// runs regardless of [blurSigma].
///
/// This widget reads no [CruxTheme] and no `MediaQuery`: every fraction
/// above is derived purely from [child]'s own rendered size, and there is
/// no color decoration of its own to resolve from a theme -- it is a pure
/// mask over whatever [child] already paints. If [child]'s own rendered
/// height is shorter than the 160px band (an edge case, but a real one),
/// the alpha fade compresses to finish exactly at [child]'s own bottom
/// edge instead of overflowing past it; the blur band's own height stays
/// fixed regardless, relying on [Stack]'s default `Clip.hardEdge` to crop
/// its paint down to whatever [child] actually occupies.
///
/// There is no animation anywhere in this widget -- the fade/blur are a
/// static function of [child]'s size, recomputed on every build like any
/// other purely declarative widget -- so unlike most other Crux UI atoms
/// there is no `MediaQuery.disableAnimationsOf` ("reduce motion") branch to
/// honor here: there is no motion to suppress.
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
  /// a sigma. Defaults to `8`. Set to `0` to disable the blur overlay
  /// entirely -- see this class's own doc for what that skips.
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
                // Bounds every BackdropFilter below to exactly this band;
                // otherwise BackdropFilter samples far outside it (up to
                // the full screen) per its own docs.
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

  /// Builds the alpha-fade gradient for [ShaderMask]'s `shaderCallback`.
  /// [_fadeStopCount] stops biased by [_fadeCurveStrength], plus a final
  /// fully-opaque stop pinned to [bounds]' own bottom so content below the
  /// band always stays visible. Stop positions use `min(_fadeBandHeight,
  /// bounds.height)` rather than the band height directly: when [child] is
  /// shorter than the band, the unclamped height would push a stop
  /// fraction past `1.0`, which [LinearGradient] cannot represent.
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
/// [BackdropFilter] at [sigma], masked by a top-to-bottom decay gradient
/// reaching [decayFraction] of the way down the band before hitting zero
/// alpha. Returns [Positioned.fill] directly from [build] so it slots into
/// the enclosing [Stack]'s `children` list like any other item.
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
          // BackdropFilter needs a child only to receive a size; this one
          // paints nothing -- the visible effect is the blurred backdrop
          // itself, not anything drawn here.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Builds one [_BlurLayer]'s own decay-mask shader: opaque at the layer's
/// own top, decaying to zero alpha by [decayFraction] of the way down
/// [bounds], then pinned fully transparent for the remainder -- so a
/// layer whose reach ends early contributes nothing beyond that point
/// rather than holding at its last alpha.
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
