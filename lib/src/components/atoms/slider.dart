import 'package:flutter/widgets.dart';

import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/shadows.dart';
import '../../tokens/theme.dart';

/// The minimum tap target size for any [CruxSlider]: 44 logical pixels,
/// even though the visible track (6) and thumb (20) are both shorter than
/// that.
const double _minTapTarget = 44;

/// The thumb's ("fader cap") width and height at rest: a flat, horizontal
/// cap rather than a round Material-style thumb.
const double _thumbWidth = 30;
const double _thumbHeight = 20;

/// The thumb's corner radius, drawn as a superellipse like every other
/// rounded corner in this package (see radii.dart's class doc).
const double _thumbCornerRadius = 6;

/// Half of [_thumbWidth]: the horizontal inset reserved on both ends of the
/// slider so the thumb's center can travel edge-to-edge without the thumb
/// itself ever rendering outside the widget's given width.
const double _thumbHorizontalInset = _thumbWidth / 2;

/// The visible track's thickness.
const double _trackHeight = 6;

/// The track's and thumb's vertical offsets within the 44-tall tap target,
/// centering each of them within it.
const double _trackTopInset = (_minTapTarget - _trackHeight) / 2;
const double _thumbTopInset = (_minTapTarget - _thumbHeight) / 2;

/// The scale the thumb springs to while being dragged.
const double _thumbDraggingScale = 1.1;

/// The diameter of a single division tick mark, and its vertical offset
/// within the 44-tall tap target (centered on the track).
const double _tickDiameter = 4;
const double _tickTopInset = (_minTapTarget - _tickDiameter) / 2;

/// The gap between the thumb's top edge and the value bubble's bottom edge
/// while dragging, and the resulting `Positioned.bottom` offset (measured
/// from the *bottom* of the 44-tall tap target) that places it there.
const double _bubbleGap = 10;
const double _bubbleBottomOffset = _minTapTarget - _thumbTopInset + _bubbleGap;

/// The grip-line group's total width, the two side lines' stroke width, and
/// the center (accent) line's stroke width -- see [_GripLinesPainter].
const double _gripGroupWidth = 16;
const double _gripLineHeight = 10;
const double _gripSideLineWidth = 1.5;
const double _gripCenterLineWidth = 2;

/// The fraction of the full `max - min` range a continuous (no [CruxSlider.
/// divisions]) slider's semantics increase/decrease actions move by: 10%,
/// matching Flutter's own Material `Slider`'s iOS adjustment unit.
const double _continuousAdjustmentFraction = 0.1;

/// A horizontal, spring-and-drag slider: Crux UI's first component built
/// around a continuous drag gesture rather than a tap.
///
/// ```dart
/// CruxSlider(
///   value: volume,
///   min: 0,
///   max: 100,
///   onChanged: (double next) => setState(() => volume = next),
/// )
/// ```
///
/// [CruxSlider] is a controlled widget, the same convention [CruxSwitch]
/// and [CruxCheckbox] use: it always reflects [value] and never mutates it
/// itself, notifying [onChanged] with the new value as the user drags (or
/// taps the track, or invokes the accessibility increase/decrease actions)
/// so the caller decides whether and how to update its state. Set
/// [onChanged] to `null` to render a disabled slider (Flutter convention,
/// matching every other Crux atom's callback-nullable-disables pattern).
///
/// The thumb is a flat, horizontal 30x20 rounded rectangle in
/// [CruxColors.surface] (no gradient or bevel), with a center
/// [CruxColors.accent] grip line flanked by two thinner grip lines.
/// Because a plain white/surface cap can blend into a light background, it
/// is additionally lifted with [CruxShadows.thumb] at rest -- a shadow
/// tier dedicated to exactly this "small elevated control that would
/// otherwise blend into what's behind it" case, one step more concentrated
/// than [CruxShadows.sm] -- and springs to the further-lifted
/// [CruxShadows.thumbLifted] while being dragged. In dark mode it is
/// additionally outlined with [CruxShadows.hairline], the same way this
/// package's other small elevated controls are.
///
/// While dragging, the thumb tracks the pointer directly with no spring lag
/// and scales up to [_thumbDraggingScale] via [CruxMotion.scale]; a value
/// bubble showing
/// the current value (formatted by [valueLabelBuilder], or as a rounded
/// percentage of [min]..[max] by default -- see [valueLabelBuilder]'s own
/// doc) appears above it. Once released, the thumb's
/// position is driven by [CruxMotion.animatedValue] (a spring) again --
/// relevant when [value] changes from outside this widget (for example a
/// caller resetting it programmatically), which then animates smoothly
/// instead of jumping. Tapping anywhere on the track (not just the thumb)
/// jumps the value to that position, exactly like a drag starting there.
///
/// In a right-to-left [Directionality] ([TextDirection.rtl]), the whole
/// slider mirrors horizontally: [min] renders on the right and [max] on the
/// left, the fill grows from the right edge, and dragging or tapping is
/// interpreted against that mirrored layout -- the same convention
/// Flutter's own Material `Slider` uses (a rightward physical drag lowers
/// [value] in RTL, the opposite of what it does in LTR). The semantics
/// increase/decrease actions are unaffected by this: they always raise or
/// lower [value], regardless of which physical side that corresponds to.
///
/// Like Flutter's own Material `Slider`, [CruxSlider] needs a bounded
/// width from its parent (for example a fixed-width [SizedBox], or an
/// [Expanded]/[Flexible] child of a [Row]) -- it does not size itself
/// intrinsically. Placing it directly inside a [Row] with no [Expanded]
/// gives it an unbounded width constraint, which fails an assertion here
/// rather than crashing deep inside layout with an unhelpful `BoxConstraints`
/// error.
///
/// Pass [divisions] to snap to a fixed number of evenly-spaced steps
/// (`divisions + 1` positions from [min] to [max] inclusive) instead of a
/// continuous value. Snapping happens continuously while dragging (not only
/// once the finger lifts) -- the same behavior Flutter's own Material
/// `Slider` uses for a discrete slider -- and each division is marked with a
/// small tick dot along the track.
///
/// Exposes Flutter's `slider`/adjustable semantics trait: a screen reader
/// announces this as a slider and can raise or lower [value] via the
/// increase/decrease actions, which step by one division when [divisions]
/// is set, or by [_continuousAdjustmentFraction] (10%) of `max - min`
/// otherwise.
///
/// Like [CruxSwitch] and [CruxCheckbox], this widget is built from plain
/// [GestureDetector] and painting widgets rather than Material's `Slider`,
/// so it never depends on or is affected by an ambient Material `ThemeData`.
class CruxSlider extends StatefulWidget {
  /// Creates a Crux slider.
  const CruxSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.valueLabelBuilder,
  }) : assert(min < max, 'CruxSlider: min must be less than max.'),
       assert(
         divisions == null || divisions > 0,
         'CruxSlider: divisions must be positive when provided.',
       ),
       assert(
         value > double.negativeInfinity && value < double.infinity,
         'CruxSlider: value must be finite.',
       );

  /// The current value. [CruxSlider] never changes this itself; the caller
  /// owns this state and updates it from [onChanged]. Not required to
  /// already sit exactly on a [divisions] grid point or within
  /// [min]..[max] -- it is simply clamped for display and interaction (the
  /// same clamped number is used for both, so the bubble/semantics
  /// announcement never disagrees with the rendered thumb position). Must
  /// be finite: a `NaN` or infinite value fails an assertion here rather
  /// than throwing later inside value formatting.
  final double value;

  /// Called with the new value as the user drags, taps the track, or
  /// invokes an accessibility increase/decrease action. Pass `null` to
  /// disable the slider. If it becomes `null` while the user is mid-drag,
  /// the drag ends immediately -- the thumb stops following the pointer and
  /// snaps back to whichever [value] was last confirmed, the same
  /// "disabled ignores all interaction" convention every other Crux atom
  /// follows.
  final ValueChanged<double>? onChanged;

  /// The minimum value [value] can reach. Defaults to `0.0`.
  final double min;

  /// The maximum value [value] can reach. Defaults to `1.0`. Must be
  /// greater than [min].
  final double max;

  /// The number of discrete steps between [min] and [max], or `null` for a
  /// continuous slider. When set, [value] snaps to one of `divisions + 1`
  /// evenly-spaced positions (including both [min] and [max]) continuously
  /// while dragging, and each position is marked with a small tick along
  /// the track. Must be positive when provided.
  final int? divisions;

  /// Called once with the starting value when a drag or track tap begins,
  /// before the first [onChanged] call for that interaction. Useful for a
  /// caller that wants to, for example, pause some other live update while
  /// the user is actively adjusting the slider.
  final ValueChanged<double>? onChangeStart;

  /// Called once with the final value when a drag or track tap ends.
  final ValueChanged<double>? onChangeEnd;

  /// Formats [value] for the drag bubble and for the semantics `value`/
  /// `increasedValue`/`decreasedValue` strings. Defaults to [value]'s
  /// position within [min]..[max] as a rounded percentage (for example
  /// `"42%"`) when not provided, matching Flutter's own Material `Slider`'s
  /// default semantics format. A plain `value.round()` would read every
  /// value in the default `0.0..1.0` range as either `"0"` or `"1"`.
  final String Function(double value)? valueLabelBuilder;

  @override
  State<CruxSlider> createState() => _CruxSliderState();
}

class _CruxSliderState extends State<CruxSlider> {
  bool _dragging = false;

  /// The live, unrounded-to-spring 0..1 position while [_dragging] is true.
  /// Only meaningful while dragging -- see [_buildVisual].
  double _dragFraction = 0;

  @override
  void didUpdateWidget(covariant CruxSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging && widget.onChanged == null) {
      // `onChanged` just went null mid-interaction. End it here rather
      // than waiting for the next drag-update event: GestureDetector's
      // recognizer has no idea this widget is now disabled and keeps
      // delivering move/end events for the in-flight gesture regardless of
      // this rebuild.
      //
      // Sets `_dragging` false directly rather than going through
      // `_endInteraction` (which calls `onChangeEnd`): going disabled
      // mid-interaction aborts the interaction, it doesn't conclude it, so
      // no "final value" should be reported. The move/end/cancel handlers
      // below all check `_dragging` first, so the eventual
      // `onHorizontalDragEnd`/`onHorizontalDragCancel` that fires when the
      // pointer lifts finds nothing left to do.
      setState(() => _dragging = false);
    }
  }

  bool get _enabled => widget.onChanged != null;

  double get _committedFraction => _fractionFromValue(widget.value);

  /// [CruxSlider.value] clamped to [CruxSlider.min]..[CruxSlider.max].
  /// Kept available directly (not only as a fraction) so callers reading
  /// "the current value" -- the bubble/semantics text, [onChangeStart]'s
  /// pre-interaction value, the increase/decrease step base -- don't have
  /// to round-trip through [_valueFromFraction] and reintroduce
  /// floating-point drift.
  double get _clampedValue => widget.value.clamp(widget.min, widget.max);

  /// The value this widget displays in the bubble and announces in
  /// semantics: the live drag value while dragging, or [_clampedValue]
  /// otherwise. Clamping here (rather than reading [CruxSlider.value]
  /// directly) keeps this in agreement with the rendered thumb position,
  /// which is likewise always clamped -- an out-of-range [CruxSlider.
  /// value] would otherwise render at the nearest edge while the bubble/
  /// semantics announced the raw, un-clamped number.
  double get _displayValue =>
      _dragging ? _valueFromFraction(_dragFraction) : _clampedValue;

  double _fractionFromValue(double value) {
    final double clamped = value.clamp(widget.min, widget.max);
    return (clamped - widget.min) / (widget.max - widget.min);
  }

  double _valueFromFraction(double fraction) {
    return widget.min + fraction * (widget.max - widget.min);
  }

  double _snapFraction(double fraction) {
    final int? divisions = widget.divisions;
    if (divisions == null) {
      return fraction;
    }
    return (fraction * divisions).round() / divisions;
  }

  /// Converts a horizontal-drag/tap-local `x` coordinate to a 0..1 fraction,
  /// snapped per [_snapFraction].
  ///
  /// [rtl] mirrors the input before snapping: a raw `x` near the widget's
  /// right edge yields a fraction near `1.0` in LTR but near `0.0` in RTL
  /// (see the class doc's RTL paragraph). Flipping the *fraction* here --
  /// rather than the pixel coordinate against [width] -- is equivalent
  /// because [_thumbHorizontalInset] is applied symmetrically on both ends
  /// of the drawable travel, but needs no [width]-dependent arithmetic of
  /// its own.
  double _fractionFromLocalX(double localX, double width, {required bool rtl}) {
    final double travel = width - 2 * _thumbHorizontalInset;
    if (travel <= 0) {
      return 0;
    }
    double raw = ((localX - _thumbHorizontalInset) / travel).clamp(0.0, 1.0);
    if (rtl) {
      raw = 1 - raw;
    }
    return _snapFraction(raw);
  }

  // GestureDetector lets a Tap recognizer and a HorizontalDrag recognizer
  // coexist on the same widget: both attach to the same pointer down, and
  // the arena resolves one of them the winner once the pointer either
  // lifts within the touch slop (Tap wins) or crosses it (HorizontalDrag
  // wins). A slow press-then-drag can therefore fire both onTapDown and
  // onHorizontalDragStart for the same physical gesture -- this method is
  // idempotent, so that only fires onChangeStart once. `_endInteraction`
  // is deliberately *not* wired to onTapCancel: that fires whenever the
  // Tap recognizer loses the arena to HorizontalDrag, which is not the end
  // of the interaction -- only onTapUp (a resolved, un-dragged tap),
  // onHorizontalDragEnd, and onHorizontalDragCancel actually terminate one.
  void _beginInteraction(double localX, double width, bool rtl) {
    if (!_enabled) {
      return;
    }
    final bool wasDragging = _dragging;
    // Captured before the setState below moves `_dragFraction`:
    // `onChangeStart` must report the value from before this interaction
    // began, not the position just pressed. Matches Flutter's own Material
    // `Slider`, which reports the pre-interaction value to `onChangeStart`.
    final double previousValue = _clampedValue;
    final double fraction = _fractionFromLocalX(localX, width, rtl: rtl);
    setState(() {
      _dragging = true;
      _dragFraction = fraction;
    });
    if (!wasDragging) {
      widget.onChangeStart?.call(previousValue);
    }
    widget.onChanged?.call(_valueFromFraction(fraction));
  }

  void _updateInteraction(double localX, double width, bool rtl) {
    if (!_dragging) {
      return;
    }
    if (!_enabled) {
      // Defense in depth: `didUpdateWidget` already ends the interaction
      // the instant `onChanged` flips null mid-drag, so this branch
      // shouldn't be reachable in practice. Kept so "no onChangeEnd once
      // disabled" still holds if a move event were ever delivered before
      // that rebuild lands. Deliberately does not call `_endInteraction`
      // -- see `didUpdateWidget`'s comment.
      setState(() => _dragging = false);
      return;
    }
    final double fraction = _fractionFromLocalX(localX, width, rtl: rtl);
    setState(() => _dragFraction = fraction);
    widget.onChanged?.call(_valueFromFraction(fraction));
  }

  void _endInteraction() {
    if (!_dragging) {
      return;
    }
    final double fraction = _dragFraction;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(_valueFromFraction(fraction));
  }

  // Deliberately a no-op -- see the wiring comment on `_beginInteraction`
  // above for why onTapCancel must not end the interaction.
  void _handleTapCancel() {}

  double get _stepSize {
    final int? divisions = widget.divisions;
    if (divisions != null) {
      return (widget.max - widget.min) / divisions;
    }
    return (widget.max - widget.min) * _continuousAdjustmentFraction;
  }

  void _handleIncrease() => _step(1);

  void _handleDecrease() => _step(-1);

  void _step(int direction) {
    final ValueChanged<double>? onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }
    // Steps from `_clampedValue` (not the raw, possibly out-of-range
    // `widget.value`) so an increase/decrease from an out-of-range starting
    // value moves relative to the same clamped number this widget renders
    // and announces everywhere else, rather than being pinned at the
    // boundary it happened to already be clamped to for display.
    final double next = (_clampedValue + direction * _stepSize).clamp(
      widget.min,
      widget.max,
    );
    onChanged(next);
  }

  /// Formats [value] for the drag bubble and the semantics `value`/
  /// `increasedValue`/`decreasedValue` strings -- see
  /// [CruxSlider.valueLabelBuilder]'s doc for the default format. [value]
  /// is expected to already be clamped to [CruxSlider.min]..[CruxSlider.
  /// max] by the caller; [_fractionFromValue] clamps again regardless, so
  /// this is safe even if it weren't.
  String _labelFor(double value) {
    final String Function(double value)? builder = widget.valueLabelBuilder;
    if (builder != null) {
      return builder(value);
    }
    final double fraction = _fractionFromValue(value);
    return '${(fraction * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxShadows shadows = theme.shadows;
    final bool enabled = _enabled;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Color activeColor = enabled ? colors.accent : colors.muted;
    final Color gripLineColor = theme.brightness == Brightness.dark
        ? shadows.hairline
        : shadows.ink.withValues(alpha: 0.22);
    final double displayValue = _displayValue;
    // Stepped from `_clampedValue`, matching `_step`'s own base -- see its
    // comment -- so these announced increase/decrease previews agree with
    // what actually invoking that accessibility action would produce.
    final double increasedValue = (_clampedValue + _stepSize).clamp(
      widget.min,
      widget.max,
    );
    final double decreasedValue = (_clampedValue - _stepSize).clamp(
      widget.min,
      widget.max,
    );

    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      value: _labelFor(displayValue),
      increasedValue: _labelFor(increasedValue),
      decreasedValue: _labelFor(decreasedValue),
      onIncrease: enabled ? _handleIncrease : null,
      onDecrease: enabled ? _handleDecrease : null,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          assert(
            constraints.maxWidth.isFinite,
            'CruxSlider received an unbounded width constraint. It needs '
            'a bounded width from its parent -- for example a fixed-width '
            'SizedBox, or an Expanded/Flexible child of a Row -- rather '
            'than sizing itself intrinsically.',
          );
          final double width = constraints.maxWidth;
          final double travel = (width - 2 * _thumbHorizontalInset).clamp(
            0.0,
            double.infinity,
          );

          // Builds the fraction-dependent visuals (track fill, division
          // ticks, bubble, thumb) for a given rendered fraction. Called
          // either with the live, unsprung drag fraction while dragging (so
          // the thumb tracks the finger with zero lag), or from inside
          // [CruxMotion.animatedValue]'s builder below while at rest, so
          // an external [CruxSlider.value] change animates smoothly
          // instead of jumping.
          Widget buildVisual(double fraction) {
            return _buildVisual(
              fraction: fraction,
              travel: travel,
              rtl: rtl,
              theme: theme,
              colors: colors,
              shadows: shadows,
              activeColor: activeColor,
              gripLineColor: gripLineColor,
              displayValue: displayValue,
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) =>
                _beginInteraction(details.localPosition.dx, width, rtl),
            onTapUp: (TapUpDetails details) => _endInteraction(),
            onTapCancel: _handleTapCancel,
            onHorizontalDragStart: (DragStartDetails details) =>
                _beginInteraction(details.localPosition.dx, width, rtl),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                _updateInteraction(details.localPosition.dx, width, rtl),
            onHorizontalDragEnd: (DragEndDetails details) => _endInteraction(),
            onHorizontalDragCancel: _endInteraction,
            child: _dragging
                ? buildVisual(_dragFraction)
                : CruxMotion.animatedValue(
                    value: _committedFraction,
                    builder:
                        (
                          BuildContext context,
                          double animatedFraction,
                          Widget? child,
                        ) => buildVisual(animatedFraction),
                  ),
          );
        },
      ),
    );
  }

  /// Builds the track/fill/ticks/bubble/thumb [Stack] for a given rendered
  /// [fraction] -- see [build]'s `buildVisual` closure for when each of the
  /// two possible sources of [fraction] (live drag vs. spring-animated) is
  /// used.
  ///
  /// [rtl] mirrors every fraction-dependent pixel position (fill anchor,
  /// tick positions, thumb/bubble center) per the class doc's RTL
  /// paragraph, without mirroring [fraction] itself where it is compared in
  /// value space (see [_buildTick]'s `insideFill`, which must stay
  /// orientation-independent).
  Widget _buildVisual({
    required double fraction,
    required double travel,
    required bool rtl,
    required CruxThemeData theme,
    required CruxColors colors,
    required CruxShadows shadows,
    required Color activeColor,
    required Color gripLineColor,
    required double displayValue,
  }) {
    final double renderFraction = rtl ? 1 - fraction : fraction;
    final double thumbCenterX = _thumbHorizontalInset + renderFraction * travel;
    final int? divisions = widget.divisions;

    return SizedBox(
      width: double.infinity,
      height: _minTapTarget,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: _thumbHorizontalInset,
            right: _thumbHorizontalInset,
            top: _trackTopInset,
            height: _trackHeight,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.controlFill,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(_trackHeight / 2),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: rtl ? null : _thumbHorizontalInset,
            right: rtl ? _thumbHorizontalInset : null,
            top: _trackTopInset,
            width: fraction * travel,
            height: _trackHeight,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: activeColor,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(_trackHeight / 2),
                  ),
                ),
              ),
            ),
          ),
          if (divisions != null)
            for (int i = 0; i <= divisions; i++)
              _buildTick(
                tickFraction: i / divisions,
                travel: travel,
                currentFraction: fraction,
                rtl: rtl,
                colors: colors,
              ),
          Positioned(
            left: thumbCenterX,
            bottom: _bubbleBottomOffset,
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: Opacity(
                  opacity: _dragging ? 1 : 0,
                  child: _buildBubble(theme, _labelFor(displayValue)),
                ),
              ),
            ),
          ),
          Positioned(
            left: thumbCenterX - _thumbHorizontalInset,
            top: _thumbTopInset,
            width: _thumbWidth,
            height: _thumbHeight,
            child: CruxMotion.scale(
              value: _dragging ? _thumbDraggingScale : 1.0,
              child: _buildThumbCap(
                colors: colors,
                capShadow: _dragging ? shadows.thumbLifted : shadows.thumb,
                hairlineColor: shadows.hairline,
                gripLineColor: gripLineColor,
                activeColor: activeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTick({
    required double tickFraction,
    required double travel,
    required double currentFraction,
    required bool rtl,
    required CruxColors colors,
  }) {
    final double renderTickFraction = rtl ? 1 - tickFraction : tickFraction;
    final double x = _thumbHorizontalInset + renderTickFraction * travel;
    final bool insideFill = tickFraction <= currentFraction + 1e-9;
    return Positioned(
      left: x - _tickDiameter / 2,
      top: _tickTopInset,
      width: _tickDiameter,
      height: _tickDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: insideFill ? colors.surface : colors.muted,
        ),
      ),
    );
  }

  Widget _buildThumbCap({
    required CruxColors colors,
    required List<BoxShadow> capShadow,
    required Color hairlineColor,
    required Color gripLineColor,
    required Color activeColor,
  }) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface,
        shadows: capShadow,
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(_thumbCornerRadius),
          ),
          side: BorderSide(color: hairlineColor),
        ),
      ),
      child: CustomPaint(
        painter: _GripLinesPainter(
          sideColor: gripLineColor,
          centerColor: activeColor,
        ),
      ),
    );
  }

  Widget _buildBubble(CruxThemeData theme, String text) {
    final CruxColors colors = theme.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.textPrimary,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(CruxRadii.m)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          text,
          style: theme.typography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.background,
          ),
        ),
      ),
    );
  }
}

/// Paints [CruxSlider]'s thumb grip lines: a center [centerColor] line
/// flanked by two thinner [sideColor] lines.
class _GripLinesPainter extends CustomPainter {
  const _GripLinesPainter({required this.sideColor, required this.centerColor});

  /// The two flanking grip lines' color: [CruxShadows.ink] washed to 22%
  /// alpha in light mode, or [CruxShadows.hairline] in dark mode (the same
  /// color as the thumb's own outline there).
  final Color sideColor;

  /// The center grip line's color: [CruxColors.accent] (or
  /// [CruxColors.muted] while disabled, matching every other Crux
  /// atom's accent-to-muted disabled treatment).
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double top = centerY - _gripLineHeight / 2;
    final double bottom = centerY + _gripLineHeight / 2;
    final double sideOffset = _gripGroupWidth / 2 - _gripSideLineWidth / 2;

    final Paint sidePaint = Paint()..color = sideColor;
    canvas
      ..drawRect(
        Rect.fromLTRB(
          centerX - sideOffset - _gripSideLineWidth / 2,
          top,
          centerX - sideOffset + _gripSideLineWidth / 2,
          bottom,
        ),
        sidePaint,
      )
      ..drawRect(
        Rect.fromLTRB(
          centerX + sideOffset - _gripSideLineWidth / 2,
          top,
          centerX + sideOffset + _gripSideLineWidth / 2,
          bottom,
        ),
        sidePaint,
      )
      ..drawRect(
        Rect.fromLTRB(
          centerX - _gripCenterLineWidth / 2,
          top,
          centerX + _gripCenterLineWidth / 2,
          bottom,
        ),
        Paint()..color = centerColor,
      );
  }

  @override
  bool shouldRepaint(covariant _GripLinesPainter oldDelegate) {
    return oldDelegate.sideColor != sideColor ||
        oldDelegate.centerColor != centerColor;
  }
}
