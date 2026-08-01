import 'package:flutter/widgets.dart';

import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/theme.dart';

/// The `CruxSpinner` viewBox this atom's geometry is defined against: every
/// other constant below is a fraction of this 24 logical-pixel square, and
/// [CruxSpinnerSize] scales the whole geometry up or down from it.
const double _viewBoxSize = 24;

/// The full lap duration of [CruxSpinner]'s falling animation. Started at
/// 1800ms (KB per plans/atoms-batch-2.md's "周期約 1.8 秒"); shortened to
/// 1200ms in a live tuning pass against the running example, per user
/// instruction (2026-08-01) -- see implementation-notes.md's "チューニング
/// 追記 (2026-08-01)" entry, the same tuned-live convention
/// `CruxMotion._spring`'s duration doc records for its own 500ms → 250ms →
/// 200ms pass.
const Duration _period = Duration(milliseconds: 1200);

/// The dot radius in [_viewBoxSize] units.
const double _dotRadius = 1.6;

/// How far each column sits from the viewBox's horizontal center, in
/// [_viewBoxSize] units -- one of the "中心から ±5〜8 相当" values the plan
/// calls for.
const double _columnOffset = 7;

/// How far the falling dot travels above and below the viewBox's vertical
/// center, in [_viewBoxSize] units -- the other "中心から ±5〜8 相当" value
/// the plan calls for.
const double _travelHalfRange = 8;

/// The fraction of one lap spent fading in at the top and fading out at the
/// bottom, each. A dot is at full opacity only in the middle
/// `1 - 2 * _fadeFraction` of its lap.
const double _fadeFraction = 0.18;

/// The number of falling columns [CruxSpinner] paints (KB "3 列").
const int _columnCount = 3;

/// The visual size a [CruxSpinner] renders at.
///
/// Every value is a whole-widget side length in logical pixels; the
/// spinner's internal geometry ([_viewBoxSize]-based) scales uniformly to
/// fit it. New values may be added in a future minor release; an exhaustive
/// `switch` over this enum can break when that happens, so prefer a
/// `default` case (or an equivalent fallback) at call sites that don't need
/// to special-case every size, the same non-exhaustiveness note
/// [CruxButtonSize] documents.
enum CruxSpinnerSize {
  /// A 16 logical pixel square. Suited to sitting inline with body text or
  /// inside a compact control (for example replacing a [CruxButton]'s
  /// label while it is loading).
  small,

  /// A 24 logical pixel square. The default.
  medium,

  /// A 36 logical pixel square. Suited to standing alone as a full-screen
  /// or full-section loading state.
  large,
}

/// Resolves the whole-widget side length, in logical pixels, for a
/// [CruxSpinnerSize].
double _sideLengthFor(CruxSpinnerSize size) {
  switch (size) {
    case CruxSpinnerSize.small:
      return 16;
    case CruxSpinnerSize.medium:
      return 24;
    case CruxSpinnerSize.large:
      return 36;
  }
}

/// Crux UI's branded loading indicator: three columns of dots that fall in
/// an endless, gentle "rain" -- fading in at the top of the lap, fading out
/// at the bottom, and reappearing at the top once invisible again. Columns
/// are offset from each other by a third of a lap, so the three dots never
/// fall in lockstep.
///
/// **This is a branding choice, not a general-purpose loading indicator.**
/// For a generic "something is loading" affordance anywhere in a consuming
/// app, prefer Flutter's own `CircularProgressIndicator.adaptive()`, which
/// automatically matches the host platform's native spinner (a Material
/// circular spinner on Android, a Cupertino activity indicator on iOS) --
/// `CruxSpinner` intentionally does *not* do that adaptation, since its
/// whole purpose is to look the same, on-brand way everywhere. Reach for
/// `CruxSpinner` when the loading state is itself part of Crux UI's own
/// visual identity -- most notably, other Crux components use it
/// internally for their own loading states (for example `CruxButton`'s
/// `loading` flag) precisely because those components must never depend on
/// the host app's `ThemeData` or platform for their appearance (see this
/// package's "never touches Material theming" rule).
///
/// ```dart
/// CruxSpinner(size: CruxSpinnerSize.large)
/// ```
///
/// This animation never settles or stops on its own -- it loops for as long
/// as the widget stays mounted -- so callers are expected to remove it from
/// the tree once whatever it represents finishes loading, the same way they
/// would stop rendering any other loading indicator.
class CruxSpinner extends StatelessWidget {
  /// Creates a Crux rain spinner.
  const CruxSpinner({
    super.key,
    this.size = CruxSpinnerSize.medium,
    this.color,
    this.semanticsLabel,
  });

  /// The whole-widget size. Defaults to [CruxSpinnerSize.medium].
  final CruxSpinnerSize size;

  /// The dot color. Defaults to the ambient [CruxTheme]'s
  /// [CruxColors.accent]. Pass [CruxColors.onAccent] (or another
  /// explicit color) when painting this spinner on top of an
  /// [CruxColors.accent]-filled surface, the same way a caller would pick
  /// a label color for text on that surface.
  final Color? color;

  /// The accessible name announced for this spinner, if any.
  ///
  /// Defaults to `null`, in which case `CruxSpinner` stays purely
  /// decorative and exposes no semantics label of its own -- the right
  /// choice whenever a host widget already supplies its own accessible name
  /// (for example `CruxButton`'s `loading` state, where the button's own
  /// label continues to describe the control). Pass an explicit label (for
  /// example `'Loading'`) when `CruxSpinner` is used on its own as a
  /// stand-alone loading indicator, so a screen reader has something to
  /// announce -- otherwise a bare spinner communicates nothing to
  /// assistive technology.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final Color resolvedColor = color ?? theme.colors.accent;
    final double side = _sideLengthFor(size);
    final double scale = side / _viewBoxSize;

    final Widget rain = SizedBox(
      width: side,
      height: side,
      child: CruxMotion.repeat(
        period: _period,
        builder: (BuildContext context, double progress, Widget? child) {
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int column = 0; column < _columnCount; column++)
                _buildDot(
                  column: column,
                  progress: progress,
                  scale: scale,
                  color: resolvedColor,
                ),
            ],
          );
        },
      ),
    );

    if (semanticsLabel == null) {
      return rain;
    }

    return Semantics(container: true, label: semanticsLabel, child: rain);
  }

  /// Builds the falling dot for [column] at the current animation
  /// [progress] (`0.0` to `1.0`, one full lap), scaled from [_viewBoxSize]
  /// units to on-screen logical pixels via [scale].
  Widget _buildDot({
    required int column,
    required double progress,
    required double scale,
    required Color color,
  }) {
    // Each column is a third of a lap behind the previous one (KB "列位相
    // 1/3 周期ずらし"), so the three dots read as a staggered rain rather
    // than falling in lockstep.
    final double phaseOffset = column / _columnCount;
    final double local = (progress + phaseOffset) % 1.0;

    final double centerXInViewBox =
        _viewBoxSize / 2 + (column - (_columnCount - 1) / 2) * _columnOffset;
    final double topInViewBox = _viewBoxSize / 2 - _travelHalfRange;
    final double bottomInViewBox = _viewBoxSize / 2 + _travelHalfRange;
    final double centerYInViewBox =
        topInViewBox + local * (bottomInViewBox - topInViewBox);

    final double diameter = _dotRadius * 2 * scale;
    final double left = centerXInViewBox * scale - diameter / 2;
    final double top = centerYInViewBox * scale - diameter / 2;

    return Positioned(
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: Opacity(
        opacity: _opacityFor(local),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

/// The fade-in/fade-out opacity for a dot [_fadeFraction] of a lap into its
/// fall and [_fadeFraction] of a lap before its fall ends, full opacity in
/// between -- KB "上端でフェードイン・下端でフェードアウト".
double _opacityFor(double local) {
  if (local < _fadeFraction) {
    return local / _fadeFraction;
  }
  if (local > 1 - _fadeFraction) {
    return (1 - local) / _fadeFraction;
  }
  return 1.0;
}
