import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/shadows.dart';
import '../../tokens/theme.dart';

/// The floating pill's own visible height, in logical pixels. Already
/// comfortably exceeds [_minTapTarget], so every tab's real cell is tall
/// enough on its own without needing a separate tap-target adjustment.
const double _barHeight = 64;

/// The icon size every [CruxNavItem.icon] is rendered at, enforced two
/// ways: an ambient [IconThemeData] hint (for a bare [Icon] descendant
/// that reads it) and a hard `SizedBox` + `FittedBox` bound around the
/// whole icon slot. The hint alone only ever suggests a size --
/// [CruxNavItem.icon] accepts any [Widget], none of which are obligated
/// to honor it. Without the hard bound, an oversized caller-supplied icon
/// would overflow the [Column] below instead of shrinking to fit.
const double _iconSize = 24;

const double _barInnerPadding = 4;

/// The tab's own selection-plate/kira-sheen inset on the left/right edges
/// only, `2`. See [_plateInsetVertical]'s own doc for why the vertical
/// edges use a different value.
const double _plateInsetHorizontal = 2;

/// The tab's own selection-plate/kira-sheen inset on the top/bottom edges,
/// `0` -- unlike [_plateInsetHorizontal]'s `2`, so the plate/sheen reaches
/// the tab cell's full available height. This only works because
/// [_CruxNavTabButtonState.build] wraps the Stack in `SizedBox.expand()`:
/// a loose [Stack] with only one non-positioned child (the icon+label
/// [FittedBox]) would otherwise size itself to that child's own natural
/// size, not the full cell, and no inset value could reach past it.
const double _plateInsetVertical = 0;

/// The minimum tappable hit-region height/width for a single tab, `44`.
/// A defensive floor: [_barHeight] minus [_barInnerPadding] on both edges
/// already clears this, but keeping it as a real [ConstrainedBox] means a
/// future change to [_barHeight] can't silently shrink the tap target
/// below this floor without also touching this constant.
const double _minTapTarget = 44;

const double _tabContentGap = 2;

/// The horizontal padding inside a single tab, around its icon+label
/// content. Together with [_tabWidth] this bounds the label's available
/// width (`_tabWidth - _tabHorizontalPadding * 2`) before
/// [TextOverflow.ellipsis] kicks in, and independently clears
/// [_minTapTarget] when combined with [_iconSize]
/// (`_iconSize + _tabHorizontalPadding * 2 = 48`).
const double _tabHorizontalPadding = 12;

/// A single tab's own fixed width, in logical pixels -- the pill's overall
/// width is this value times the tab count plus [_barInnerPadding] on both
/// edges (see [CruxNavBar]'s own "Compact width" doc), never driven by
/// any [CruxNavItem.label]'s own text. Comfortably clears both
/// [_minTapTarget] and the icon-plus-padding floor
/// (`_iconSize + _tabHorizontalPadding * 2 = 48`).
///
/// See unknowns/navigation-bars/ledger.md ("2026-08-07 ユーザー決定") for
/// why `88` rather than another value.
const double _tabWidth = 88;

const double _labelFontSize = 11;

/// The floating pill's own minimum left/right margin from its host.
/// [_CruxNavBarState.build] computes the pill's width as `math.min` of
/// its fixed tab-count width and `hostWidth - _barMarginX * 2`, so a host
/// too narrow for every tab's [_tabWidth] clamps the pill to this margin
/// and every tab shrinks equally (falling back to its own ellipsis)
/// rather than the margin shrinking further or the pill overflowing.
const double _barMarginX = 16;

/// The floating pill's own bottom margin, added on top of whatever bottom
/// safe-area inset [MediaQuery] reports -- `0`: the pill floats flush with
/// the safe-area inset itself, with no further gap added on top of it.
const double _barBottomOffset = 0;

/// How tall [CruxNavBar]'s own backdrop-fade band is, in logical pixels,
/// measured up from this widget's own bottom edge. Reuses [CruxTopFade]'s
/// `_fadeBandHeight` value (`top_fade.dart`) rather than deriving a new
/// one -- comfortably clears the pill's own worst-case height plus a
/// generous safe-area allowance with room to spare. Unlike [CruxTopFade]
/// (whose band is clamped against its child's own rendered height), this
/// band's height is never clamped: [CruxNavBar] has no content of its
/// own to measure.
const double _backdropBandHeight = 160;

const int _backdropScrimStopCount = 5;

/// The power-curve exponent the backdrop scrim's per-stop alpha is raised
/// to. Above 1.0 the scrim stays mostly transparent longer, then
/// opacifies quickly near this band's own bottom edge.
const double _backdropScrimCurveStrength = 1.6;

/// How many compounding blur layers [CruxNavBar] stacks behind the pill
/// whenever [CruxNavBar.backdropBlurSigma] is greater than zero. Six
/// overlapping layers of different strength and reach grade the blur
/// across the band instead of reading as one uniformly-blurred pane.
const int _backdropBlurLayerCount = 6;

/// Each backdrop blur layer's own blur radius, as a fraction of
/// [CruxNavBar.backdropBlurSigma]. Paired index-for-index with
/// [_backdropBlurLayerDecayFractions]: index 0 is the weakest layer with
/// the largest reach; the last index is the strongest (`1.0`, the full
/// [CruxNavBar.backdropBlurSigma]) but stays concentrated closest to
/// this band's own bottom edge -- the true edge, on the opposite physical
/// side from [CruxTopFade]'s own true (top) edge.
const List<double> _backdropBlurLayerRadiusFractions = <double>[
  0.17,
  0.33,
  0.5,
  0.67,
  0.83,
  1.0,
];

/// Each backdrop blur layer's own decay reach, as a fraction of
/// [_backdropBandHeight], paired index-for-index with
/// [_backdropBlurLayerRadiusFractions]. Unlike [CruxTopFade] (whose true
/// edge sits at its band's own top, decaying downward), this band's true
/// edge is its own bottom, so [_buildBackdropBlurLayerDecayShader]'s decay
/// math grows upward from position `1` instead of `0`.
const List<double> _backdropBlurLayerDecayFractions = <double>[
  1.0,
  0.87,
  0.74,
  0.61,
  0.48,
  0.35,
];

const int _backdropBlurLayerDecaySteps = 10;

const double _backdropBlurLayerDecayCurveStrength = 1.6;

/// [CruxNavBar.backdropBlurSigma]'s default, `8`.
const double _defaultBackdropBlurSigma = 8;

const Duration _plateFadeInDuration = Duration(milliseconds: 200);

const Duration _plateFadeOutDuration = Duration(milliseconds: 140);

const double _plateAppearStartScale = 0.8;

const double _sheenTiltDegrees = 4;

const double _sheenPeakAlpha = 0.24;

const double _sheenEdgeAlpha = 0.05;

const double _sheenBlurSigma = 8;

const Duration _sheenDuration = Duration(milliseconds: 300);

const Duration _sheenDelay = Duration(milliseconds: 90);

const double _sheenWidthFraction = 0.38;

const double _sheenOvertravel = 1.3;

/// A single destination inside a [CruxNavBar].
///
/// [value] is the destination this item represents, compared with `==`
/// against [CruxNavBar.selected] to decide which item is selected and
/// passed to [CruxNavBar.onChanged] when tapped -- give [T] a meaningful
/// `==`. [icon] is a caller-supplied [Widget], never an `IconData`, so
/// this package never needs to know which icon system (Material,
/// Cupertino, a custom SVG) produced it. [label] is always shown
/// underneath [icon]; it is never optional or conditionally hidden.
@immutable
class CruxNavItem<T> {
  /// Creates a nav bar destination.
  const CruxNavItem({
    required this.value,
    required this.icon,
    required this.label,
  });

  /// The destination this item represents.
  final T value;

  /// The icon shown above [label], rendered at a fixed 24-logical-pixel
  /// size via an ambient [IconThemeData].
  final Widget icon;

  /// The item's visible label, always shown (never hidden), on a single
  /// line with an ellipsis.
  final String label;
}

/// A floating, pill-shaped bottom navigation bar: Crux UI's tab-switcher
/// atom for 3-5 top-level destinations, each rendered as an icon over an
/// always-visible label.
///
/// ```dart
/// Stack(
///   alignment: Alignment.bottomCenter,
///   children: [
///     content,
///     CruxNavBar<AppTab>(
///       items: const <CruxNavItem<AppTab>>[
///         CruxNavItem(value: AppTab.home, icon: Icon(...), label: 'ホーム'),
///         CruxNavItem(value: AppTab.chat, icon: Icon(...), label: 'チャット'),
///         CruxNavItem(value: AppTab.settings, icon: Icon(...), label: '設定'),
///       ],
///       selected: currentTab,
///       onChanged: (AppTab next) => setState(() => currentTab = next),
///     ),
///   ],
/// )
/// ```
///
/// **Controlled widget**: [CruxNavBar] always reflects [selected] and
/// never mutates it itself, notifying [onChanged] with the tapped item's
/// value so the caller decides whether and how to update its state. Set
/// [onChanged] to `null` to render every item disabled. Tapping the
/// already-selected item does not call [onChanged]. [items] must have at
/// least two entries (an `assert`) -- 3-5 is the intended range for a real
/// bottom nav, but nothing below this widget's own layout enforces an
/// upper bound.
///
/// **Visual language**: the selected item's own plate fades and
/// scale-springs in (`0.8 -> ~1.02 -> 1.0`) while every other item's plate
/// stays hidden, and shortly after a real selection change, a diagonal
/// "kira" light sweep plays once across the newly selected item's plate,
/// tilted and swept in the direction of travel. Nothing ever slides or
/// translates between items.
///
/// **Floating shape and safe area**: unlike every other Crux component,
/// [CruxNavBar] reads [MediaQuery]'s bottom safe-area inset itself
/// (falling back to zero with no [MediaQuery] ancestor) and bakes its own
/// outer margin into its own layout, rather than expecting a host to place
/// and margin it. A host only needs to put this widget at the bottom of a
/// [Stack] or [Column] -- for example `Stack(alignment:
/// Alignment.bottomCenter, children: [content, CruxNavBar(...)])` -- and
/// the floating gap on all sides, including safe area, is already built
/// in. With [backdropFade] at its default `true`, this widget's own
/// reported size grows taller than just the pill's own margin box (see
/// "Backdrop fade" below); a host does not need to account for that
/// itself, since the extra height never shifts where the pill ends up.
///
/// **Compact width**: the floating pill's own width is driven purely by
/// how many tabs it has, never by any tab's own label: exactly `_tabWidth
/// * items.length + _barInnerPadding * 2`, so a 3-item bar's pill is
/// visibly narrower than a 4-item bar's. Every tab shares that one equal
/// width as an `Expanded` child of the pill's own `Row`; a label too wide
/// for its own tab falls back to a single-line ellipsis, never widening
/// the tab or the pill to accommodate it. The pill is centered
/// horizontally in this widget's own full width. It is never allowed to
/// get closer than [_barMarginX] to either edge of its host: a host too
/// narrow for every tab's fixed width clamps the pill down to that
/// minimum margin, and every tab shrinks below its fixed width by an
/// equal share rather than the pill overflowing its host. The
/// backdrop-fade band (below) is not affected by any of this: it stays
/// this widget's own full, edge-to-edge width regardless of how compact
/// the pill itself gets.
///
/// **Color mapping**: the pill's own background is [CruxColors.surface];
/// a selected item's plate is [CruxColors.controlFill] in light,
/// [CruxColors.controlPlate] in dark, painted with no shadow of its own.
/// The pill's own outer floating shadow is [CruxShadows.sm]. An item's
/// icon and label color is [CruxColors.textPrimary] while selected,
/// [CruxColors.textSecondary] while unselected, [CruxColors.muted]
/// while disabled -- propagated to the caller-supplied [CruxNavItem.icon]
/// via an ambient [IconThemeData]/[DefaultTextStyle].
///
/// **Label weight**: on top of that selected/unselected color distinction,
/// the selected tab's own label is also bold (`FontWeight.bold`); an
/// unselected label keeps [CruxTypography.label]'s base weight
/// (`FontWeight.w600`).
///
/// **Backdrop fade**: whenever [backdropFade] is `true` (the default),
/// this widget also draws a full-width, edge-to-edge band directly behind
/// the floating pill, anchored to this widget's own bottom edge and
/// reaching up from it far enough to comfortably cover the pill's own
/// worst-case height plus a generous safe-area allowance. Scrolling
/// content placed behind [CruxNavBar] in a host [Stack] therefore
/// appears to melt into the page as it approaches the screen's bottom
/// edge, mirroring the effect [CruxTopFade] gives a scrolling child's
/// top edge -- except this band paints its own [CruxColors.background]
/// scrim rather than masking a child, since [CruxNavBar] has no child of
/// its own to mask. Set [backdropBlurSigma] to `0` to keep the scrim but
/// skip building any [BackdropFilter] at all, or set [backdropFade] to
/// `false` to skip the entire band, scrim included. The whole band is
/// wrapped in [IgnorePointer]: it never intercepts a tap or scroll gesture
/// meant for whatever sits behind it.
///
/// Because the scrim is a flat [CruxColors.background] wash rather than
/// a true blur-through of whatever is actually behind it, this backdrop
/// fade only reads correctly when the host's own content actually sits on
/// [CruxColors.background]. Over a full-bleed image or any other
/// surface, the scrim will visibly tint it the wrong color as it
/// approaches full opacity near the bottom edge -- pass `backdropFade:
/// false` in that case rather than accepting the mismatch.
///
/// Set [MediaQuery.disableAnimationsOf] to suppress both the plate's
/// spring/fade and the kira sheen: the plate then jumps directly to its
/// resting opacity/scale and the sheen never sweeps.
///
/// Built from plain [GestureDetector] and painting widgets, never
/// Material's `BottomNavigationBar`, so it never depends on or is affected
/// by an ambient Material `ThemeData` -- and, like every Crux component,
/// never imports `package:flutter/material.dart` or
/// `package:flutter/cupertino.dart`.
class CruxNavBar<T> extends StatefulWidget {
  /// Creates a Crux floating nav bar.
  const CruxNavBar({
    super.key,
    required this.items,
    required this.selected,
    this.onChanged,
    this.backdropFade = true,
    this.backdropBlurSigma = _defaultBackdropBlurSigma,
  });

  /// The ordered list of destinations this bar presents. Must have at least
  /// two entries -- see this class's own doc.
  final List<CruxNavItem<T>> items;

  /// The currently selected value. Must equal exactly one of [items]' values
  /// for the bar to show a selection.
  final T selected;

  /// Called with an item's value when that item is tapped while a
  /// *different* item is selected. Pass `null` to disable every item in the
  /// bar.
  final ValueChanged<T>? onChanged;

  /// Whether this widget draws its own backdrop-fade band behind the
  /// floating pill -- see this class's own "Backdrop fade" doc for what
  /// that band is and why a caller might turn it off. Defaults to `true`;
  /// pass `false` to draw the pill alone with no band at all, not even the
  /// scrim.
  final bool backdropFade;

  /// The backdrop-fade band's blur strength, passed straight through to
  /// [ImageFilter.blur] as a sigma. Defaults to `8`, matching
  /// [CruxTopFade]'s own default. Set to `0` to skip every
  /// [BackdropFilter] layer while keeping the scrim -- see this class's own
  /// "Backdrop fade" doc. Has no effect at all when [backdropFade] is
  /// `false`.
  final double backdropBlurSigma;

  @override
  State<CruxNavBar<T>> createState() => _CruxNavBarState<T>();
}

class _CruxNavBarState<T> extends State<CruxNavBar<T>> {
  Timer? _sheenDelayTimer;

  /// Each item's own kira-sheen trigger count, keyed by [CruxNavItem.
  /// value]. Never reset once an item has a count, even after the sheen
  /// moves to a different item -- a still-sweeping sheen must be free to
  /// finish on its own schedule.
  final Map<T, int> _sheenTriggerByValue = <T, int>{};

  /// Each item's own kira-sheen sweep direction (`true` for left-to-right).
  final Map<T, bool> _sheenLtrByValue = <T, bool>{};

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(covariant CruxNavBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) {
      return;
    }
    final int oldIndex = widget.items.indexWhere(
      (CruxNavItem<T> item) => item.value == oldWidget.selected,
    );
    final int newIndex = widget.items.indexWhere(
      (CruxNavItem<T> item) => item.value == widget.selected,
    );
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) {
      // Either endpoint isn't in the current item list, or nothing
      // actually moved -- no sheen.
      return;
    }
    _scheduleSheen(target: widget.selected, movesRight: newIndex > oldIndex);
  }

  /// Schedules [target]'s kira sheen to start after [_sheenDelay]. Cancels
  /// any pending timer first, so a rapid re-selection retargets cleanly
  /// instead of firing a stale sheen on the wrong item.
  void _scheduleSheen({required T target, required bool movesRight}) {
    _sheenDelayTimer?.cancel();
    _sheenDelayTimer = Timer(_sheenDelay, () {
      setState(() {
        _sheenTriggerByValue[target] = (_sheenTriggerByValue[target] ?? 0) + 1;
        _sheenLtrByValue[target] = movesRight;
      });
    });
  }

  void _handleItemTap(T value) {
    if (value == widget.selected) {
      // Re-tapping the already-selected item notifies nothing -- see this
      // class's own doc for why.
      return;
    }
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    _sheenDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.length >= 2,
      'CruxNavBar needs at least two items to be a meaningful tab '
      'switcher.',
    );
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool enabled = _enabled;

    // The "maybe" family, not the asserting `MediaQuery.paddingOf`, so
    // this widget still lays out with no MediaQuery ancestor at all.
    final double safeAreaBottom =
        MediaQuery.maybePaddingOf(context)?.bottom ?? 0;

    // Needs its own incoming BoxConstraints (maxWidth) to compute the
    // pill's own host-width clamp -- see _barMarginX's own doc.
    final Widget pill = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Floored at 0. When maxWidth is unbounded, infinity minus a
        // finite amount is still infinity, so this naturally degrades to
        // "no clamp" with no separate branch needed.
        final double maxPillWidth = math.max(
          0.0,
          constraints.maxWidth - _barMarginX * 2,
        );
        // The pill's own natural width (_tabWidth per tab plus inner
        // padding), clamped by maxPillWidth: when it already fits, every
        // tab renders at exactly _tabWidth; otherwise every tab (still
        // Expanded below) shrinks by an equal share instead of the pill
        // overflowing its host.
        final double pillWidth = math.min(
          _tabWidth * widget.items.length + _barInnerPadding * 2,
          maxPillWidth,
        );

        return Padding(
          padding: EdgeInsets.only(bottom: safeAreaBottom + _barBottomOffset),
          // heightFactor: 1.0 keeps this Center snug to the pill's own
          // height; a bare Center expands to fill both axes under bounded
          // constraints, which would inflate this widget's own reported
          // height to match its host.
          child: Center(
            heightFactor: 1.0,
            child: SizedBox(
              width: pillWidth,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.surface,
                  shadows: theme.shadows.sm,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(CruxRadii.pill),
                    ),
                  ),
                ),
                child: SizedBox(
                  height: _barHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(_barInnerPadding),
                    child: Row(
                      children: <Widget>[
                        for (final CruxNavItem<T> item in widget.items)
                          Expanded(
                            key: ValueKey<T>(item.value),
                            child: _CruxNavTabButton<T>(
                              icon: item.icon,
                              label: item.label,
                              selected: item.value == widget.selected,
                              enabled: enabled,
                              onTap: enabled
                                  ? () => _handleItemTap(item.value)
                                  : null,
                              sheenTrigger:
                                  _sheenTriggerByValue[item.value] ?? 0,
                              sheenLtr: _sheenLtrByValue[item.value] ?? true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!widget.backdropFade) {
      // No band at all -- return the pill alone; see this class's own
      // "Backdrop fade" doc for when a caller would want this.
      return pill;
    }

    // math.max below guards against an exotic safe-area inset leaving the
    // pill's own margin box taller than the fixed-height band meant to
    // sit behind it.
    final double pillTotalHeight =
        _barHeight + safeAreaBottom + _barBottomOffset;

    return SizedBox(
      height: math.max(pillTotalHeight, _backdropBandHeight),
      // bottomCenter pins both the band and the pill to this outer
      // SizedBox's bottom edge, without needing an explicit Positioned on
      // either.
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          _buildBackdropBand(theme, widget.backdropBlurSigma),
          pill,
        ],
      ),
    );
  }

  /// Builds [CruxNavBar]'s own backdrop-fade band -- see that class's own
  /// "Backdrop fade" doc for what it is and why. Always [_backdropBandHeight]
  /// tall and this widget's own full width, ignoring [_barMarginX] entirely
  /// (unlike the pill itself) so the band reaches this widget's own left
  /// and right edges. Wrapped in [IgnorePointer]: every tap or scroll
  /// gesture aimed at whatever sits behind [CruxNavBar] must reach it
  /// unobstructed.
  ///
  /// Painted blur-first, scrim-on-top: the blur layers blur whatever is
  /// already composited behind this band, and the scrim's increasingly
  /// opaque wash then tints that already-blurred result -- "frosted glass
  /// with a tint on top", not the reverse.
  Widget _buildBackdropBand(CruxThemeData theme, double backdropBlurSigma) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: _backdropBandHeight,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (backdropBlurSigma > 0)
              for (int i = 0; i < _backdropBlurLayerCount; i++)
                _BackdropBlurLayer(
                  sigma:
                      backdropBlurSigma * _backdropBlurLayerRadiusFractions[i],
                  decayFraction: _backdropBlurLayerDecayFractions[i],
                ),
            DecoratedBox(
              decoration: _buildBackdropScrimDecoration(theme.colors),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the backdrop scrim's own gradient: a vertical [LinearGradient]
/// of [CruxColors.background], transparent at this band's own top edge
/// and opaque at its own bottom edge (this widget's true, screen-bottom
/// edge) -- painted directly as a filled box, since (unlike [CruxTopFade],
/// which fades an actual child it wraps) this widget has no child of its
/// own to mask; whatever should melt away is a separate sibling elsewhere
/// in the host's own [Stack].
///
/// Needs no direction flip despite this band's true edge sitting at the
/// opposite physical side from [CruxTopFade]'s: a [LinearGradient]'s
/// stops are read relative to its own box, and this box's bottom already
/// is the true edge. Contrast [_buildBackdropBlurLayerDecayShader], whose
/// decay math does need an explicit mirror.
BoxDecoration _buildBackdropScrimDecoration(CruxColors colors) {
  final List<double> stops = <double>[];
  final List<Color> gradientColors = <Color>[];
  for (int i = 0; i < _backdropScrimStopCount; i++) {
    final double t = i / (_backdropScrimStopCount - 1);
    final double alpha = math.pow(t, _backdropScrimCurveStrength).toDouble();
    stops.add(t);
    gradientColors.add(colors.background.withValues(alpha: alpha));
  }
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradientColors,
      stops: stops,
    ),
  );
}

/// One compounding backdrop blur layer inside [CruxNavBar]'s band: a
/// [BackdropFilter] at [sigma], masked by a decay gradient reaching
/// [decayFraction] of the way up this band before hitting zero alpha.
/// Returns [Positioned.fill] directly from [build] so it slots into the
/// enclosing [Stack]'s `children` list like any other item.
class _BackdropBlurLayer extends StatelessWidget {
  const _BackdropBlurLayer({required this.sigma, required this.decayFraction});

  /// This layer's own [ImageFilter.blur] sigma -- already
  /// [CruxNavBar.backdropBlurSigma] scaled by this layer's
  /// [_backdropBlurLayerRadiusFractions] entry.
  final double sigma;

  /// How far up this band (as a fraction of this layer's own rendered
  /// height) this layer's decay gradient reaches before hitting zero alpha
  /// -- this layer's own [_backdropBlurLayerDecayFractions] entry.
  final double decayFraction;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) =>
            _buildBackdropBlurLayerDecayShader(bounds, decayFraction),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          // Same "needs a child only to be given a size, paints nothing of
          // its own" reasoning as CruxTopFade's own _BlurLayer -- see
          // that class's own doc.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Builds one [_BackdropBlurLayer]'s own decay-mask shader: opaque at this
/// band's own bottom (the true edge, since this band anchors to this
/// widget's screen-bottom edge), decaying to zero alpha by [decayFraction]
/// of the way up, then pinned fully transparent for the remainder. This is
/// the mirror image of [CruxTopFade]'s own decay shader (`top_fade.dart`),
/// whose true edge sits at its band's own *top* instead -- reusing that
/// formula unmirrored here would concentrate full blur strength at the
/// point farthest from this band's own true edge.
Shader _buildBackdropBlurLayerDecayShader(Rect bounds, double decayFraction) {
  final double height = bounds.height > 0 ? bounds.height : _backdropBandHeight;
  final double decayHeight = height * decayFraction;
  final List<double> stops = <double>[0.0];
  final List<Color> colors = <Color>[const Color.fromRGBO(0, 0, 0, 0)];
  for (int i = 0; i <= _backdropBlurLayerDecaySteps; i++) {
    final double t = i / _backdropBlurLayerDecaySteps;
    final double alpha = math
        .pow(t, _backdropBlurLayerDecayCurveStrength)
        .toDouble();
    final double positionPx = height - decayHeight + t * decayHeight;
    stops.add((positionPx / height).clamp(0.0, 1.0));
    colors.add(Color.fromRGBO(0, 0, 0, alpha));
  }
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
    stops: stops,
  ).createShader(bounds);
}

/// The private per-item button: press feedback, the selection plate, the
/// kira sheen, and the icon+label. Not exported -- callers only ever see
/// [CruxNavBar].
class _CruxNavTabButton<T> extends StatefulWidget {
  const _CruxNavTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.sheenTrigger,
    required this.sheenLtr,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  /// This item's own running kira-sheen trigger count.
  final int sheenTrigger;

  /// This item's next kira-sheen sweep direction.
  final bool sheenLtr;

  @override
  State<_CruxNavTabButton<T>> createState() => _CruxNavTabButtonState<T>();
}

class _CruxNavTabButtonState<T> extends State<_CruxNavTabButton<T>> {
  bool _pressed = false;

  // See press_feedback.dart's class doc for the fast-tap bug this guards
  // against.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  // Only _handleTapDown checks `enabled`, since it is the only handler
  // that starts a press.
  void _handleTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _pressFeedback.down();
    }
  }

  void _handleTapUp(TapUpDetails details) => _pressFeedback.up();

  void _handleTapCancel() => _pressFeedback.cancel();

  @override
  void dispose() {
    _pressFeedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Color contentColor = !widget.enabled
        ? colors.muted
        : (widget.selected ? colors.textPrimary : colors.textSecondary);

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      // No explicit `label` here: the child Text below already supplies
      // its own automatic semantics label, and nothing between this node
      // and that Text introduces a merge boundary.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _minTapTarget,
          minHeight: _minTapTarget,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          child: CruxMotion.scale(
            value: _pressed ? CruxMotion.pressedScale : 1.0,
            // Forces the Stack below to size itself to the tab cell's
            // full loose height instead of shrinking to its one
            // non-positioned child -- see _plateInsetVertical's own doc.
            // Both dimensions resolve against already-bounded incoming
            // constraints, so this never throws for an unbounded
            // ancestor.
            child: SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: _plateInsetHorizontal,
                    top: _plateInsetVertical,
                    right: _plateInsetHorizontal,
                    bottom: _plateInsetVertical,
                    child: _buildPlate(theme, reduceMotion),
                  ),
                  Positioned(
                    left: _plateInsetHorizontal,
                    top: _plateInsetVertical,
                    right: _plateInsetHorizontal,
                    bottom: _plateInsetVertical,
                    child: _buildSheenMask(theme, reduceMotion),
                  ),
                  // Padding is breathing room inside this tab's own fixed
                  // width; it does not affect measurement (the tab's
                  // width comes from pillWidth / Expanded, not from its
                  // content).
                  //
                  // The FittedBox(scaleDown) around the icon+label group
                  // protects against text-scale overflow of the
                  // fixed-height cell -- a no-op at normal scale, uniform
                  // shrink only once the intrinsic size stops fitting.
                  //
                  // The LayoutBuilder below is required, not decorative:
                  // RenderFittedBox always lays out its child with
                  // unbounded constraints, so a Text's `overflow:
                  // ellipsis` inside a FittedBox never receives a bounded
                  // width to ellipsize against -- it always measures its
                  // own full natural width first, then the whole group
                  // is scaled down uniformly (shrinking the icon too)
                  // instead of the label ellipsizing alone. This
                  // LayoutBuilder captures the tab's real available
                  // width and feeds it into the ConstrainedBox around
                  // Text below; because ConstrainedBox.enforce clamps
                  // within whatever the parent hands it, this finite
                  // bound survives even though its parent (FittedBox) is
                  // itself unbounded.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _tabHorizontalPadding,
                    ),
                    child: LayoutBuilder(
                      builder:
                          (
                            BuildContext context,
                            BoxConstraints cellConstraints,
                          ) {
                            final double maxLabelWidth = math.max(
                              0.0,
                              cellConstraints.maxWidth,
                            );
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  // Hard bound around the icon slot; see
                                  // _iconSize's own doc for why the
                                  // ambient IconThemeData hint below
                                  // isn't sufficient alone.
                                  SizedBox(
                                    width: _iconSize,
                                    height: _iconSize,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: IconTheme.merge(
                                        data: IconThemeData(
                                          size: _iconSize,
                                          color: contentColor,
                                        ),
                                        child: DefaultTextStyle.merge(
                                          style: TextStyle(color: contentColor),
                                          child: widget.icon,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: _tabContentGap),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: maxLabelWidth,
                                    ),
                                    child: Text(
                                      widget.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.typography.label.copyWith(
                                        fontSize: _labelFontSize,
                                        color: contentColor,
                                        // Bold only while selected -- see
                                        // [CruxNavBar]'s own "Label
                                        // weight" doc. `null` leaves the
                                        // base style's own weight (w600)
                                        // untouched for an unselected
                                        // tab rather than redundantly
                                        // re-specifying it.
                                        fontWeight: widget.selected
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the selection plate: fades and scale-springs in while selected,
  /// fades out while not, painted with no shadow of its own -- [_plateColor]
  /// already gives it a real fill difference from the pill's own background
  /// in both themes, so a shadow on top would add no further legibility.
  Widget _buildPlate(CruxThemeData theme, bool reduceMotion) {
    final Widget plateBox = DecoratedBox(
      decoration: ShapeDecoration(
        color: _plateColor(theme),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(CruxRadii.pill)),
        ),
      ),
    );

    if (reduceMotion) {
      return widget.selected ? plateBox : const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: widget.selected ? 1.0 : 0.0,
      duration: widget.selected ? _plateFadeInDuration : _plateFadeOutDuration,
      curve: Curves.easeOut,
      child: CruxMotion.animatedValue(
        value: widget.selected ? 1.0 : _plateAppearStartScale,
        playful: true,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: plateBox,
      ),
    );
  }

  /// Builds the kira sheen mask. Always mounted; a cheap no-op until
  /// [_CruxNavTabButton.sheenTrigger] fires.
  Widget _buildSheenMask(CruxThemeData theme, bool reduceMotion) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(CruxRadii.pill)),
      child: CruxMotion.playOnce(
        trigger: widget.sheenTrigger,
        duration: _sheenDuration,
        reduceMotion: reduceMotion,
        builder: (BuildContext context, double progress, Widget? child) {
          if (progress <= 0.0 || progress >= 1.0) {
            return const SizedBox.shrink();
          }
          return IgnorePointer(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double height = constraints.maxHeight;
                final double bandWidth = width * _sheenWidthFraction;
                final double travel = bandWidth * _sheenOvertravel;
                final double startX = widget.sheenLtr
                    ? -travel
                    : width + travel;
                final double endX = widget.sheenLtr ? width + travel : -travel;
                final double bandLeft = startX + (endX - startX) * progress;
                final double tiltDegrees = widget.sheenLtr
                    ? _sheenTiltDegrees
                    : -_sheenTiltDegrees;
                final Color edge = theme.shadows.ink.withValues(
                  alpha: _sheenEdgeAlpha,
                );
                final Color peak = _sheenPeakColor(theme);

                return Transform.translate(
                  offset: Offset(bandLeft, 0),
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.skewX(tiltDegrees * math.pi / 180),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _sheenBlurSigma,
                        sigmaY: _sheenBlurSigma,
                      ),
                      child: Container(
                        width: bandWidth,
                        height: height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              edge.withValues(alpha: 0),
                              edge,
                              peak.withValues(alpha: _sheenPeakAlpha),
                              edge,
                              edge.withValues(alpha: 0),
                            ],
                            stops: const <double>[0.0, 0.30, 0.50, 0.70, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The sheen's peak highlight color: [CruxColors.surface] in light,
/// [CruxColors.textPrimary] in dark -- reuses existing tokens rather
/// than a new raw color value.
Color _sheenPeakColor(CruxThemeData theme) {
  return theme.brightness == Brightness.light
      ? theme.colors.surface
      : theme.colors.textPrimary;
}

/// The selection plate's fill color, split by brightness: [CruxColors
/// .controlFill] in light, [CruxColors.controlPlate] in dark. In light,
/// [CruxColors.controlPlate] is defined identical to [CruxColors
/// .surface] -- the same color as this pill's own background -- so using
/// it there would leave a selected plate indistinguishable except by
/// shadow. In dark, [CruxColors.controlFill] sits too close to
/// [CruxColors.surface] (~1.05:1, see that token's own doc in
/// `colors.dart`) to serve the same purpose, so dark keeps [controlPlate]
/// instead.
Color _plateColor(CruxThemeData theme) {
  return theme.brightness == Brightness.light
      ? theme.colors.controlFill
      : theme.colors.controlPlate;
}
