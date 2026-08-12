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

/// The minimum tappable hit-region height for the whole
/// [CruxSegmentedControl] shell and for each segment inside it (matches
/// [CruxButton]'s and [CruxChip]'s own `_minTapTarget`): 44 logical
/// pixels, taller than the 40px visible pill.
///
/// Must be enforced as a real *reported* size at both levels, not by
/// wrapping only the inner content in an [OverflowBox]: [RenderBox.hitTest]
/// gates every tap against a box's own reported size before recursing into
/// its child, and [OverflowBox] reports the size its parent's incoming
/// constraint gives it, not the overridden size it lays its child out at --
/// so an [OverflowBox] alone silently drops taps outside its reported
/// bounds. The fix is a real `SizedBox(height: _minTapTarget)` around the
/// whole control ([_CruxSegmentedControlState.build]), giving the segment
/// row a *loose* height constraint, plus a real `ConstrainedBox(minHeight:
/// _minTapTarget)` around each segment's own content
/// ([_CruxSegmentButtonState.build]) that then actually binds to it. The
/// visible pill (the [CruxColors.controlFill] background, 40px tall) is a
/// separate, purely decorative layer centered inside that 44-tall shell.
const double _minTapTarget = 44;

/// The padding around the whole control, inside its pill background and
/// outside every segment.
const double _controlPadding = 4;

/// Each segment's own visible height, in logical pixels. The pill
/// background is sized to `_controlPadding * 2 + _visibleSegmentHeight`
/// (40) and centered inside the taller [_minTapTarget] (44) tap-target
/// shell; the 4px difference is absorbed as a transparent margin that only
/// the segments' own taller tap targets reach into.
const double _visibleSegmentHeight = 32;

/// The horizontal padding inside a single segment, around its label.
const double _segmentHorizontalPadding = 12;

/// How long the newly selected segment's plate takes to fade in, once it
/// starts appearing. The scale spring driving its bounce ([CruxMotion
/// .animatedValue]'s `playful` spring) runs on its own independent timeline
/// -- see [_CruxSegmentButtonState._buildPlate]'s doc.
const Duration _plateFadeInDuration = Duration(milliseconds: 200);

/// How long the just-deselected segment's plate takes to fade out --
/// shorter than [_plateFadeInDuration].
const Duration _plateFadeOutDuration = Duration(milliseconds: 140);

/// The plate's scale immediately before it starts appearing; the spring
/// then overshoots past `1.0` on its way to rest (peaking around `1.02`).
const double _plateAppearStartScale = 0.8;

/// The kira sheen's tilt, in degrees. Positive tilts the band for a
/// left-to-right sweep (moving to a segment on the right); negative mirrors
/// it for right-to-left (moving left).
const double _sheenTiltDegrees = 4;

/// The kira sheen's peak highlight opacity.
const double _sheenPeakAlpha = 0.24;

/// The kira sheen's edge-shadow opacity: the faint darkening flanking the
/// highlight, added so the sweep stays visible over a same-hued plate.
const double _sheenEdgeAlpha = 0.05;

/// The kira sheen's blur, in logical pixels, used directly as
/// [ImageFilter.blur]'s sigma (no unit conversion, the same convention
/// `shadows.dart` uses for its own blur radii).
const double _sheenBlurSigma = 8;

/// The kira sheen's sweep duration.
const Duration _sheenDuration = Duration(milliseconds: 300);

/// How long after a real selection change the kira sheen starts sweeping.
const Duration _sheenDelay = Duration(milliseconds: 90);

/// The sheen band's width as a fraction of the segment's own width.
const double _sheenWidthFraction = 0.38;

/// How far past each edge of the segment the sheen band travels before/after
/// the sweep, as a multiple of the band's own width.
const double _sheenOvertravel = 1.3;

/// A single option inside a [CruxSegmentedControl].
///
/// [value] is the option this segment represents (compared with `==`
/// against [CruxSegmentedControl.selected] to decide which segment is
/// selected, and passed to [CruxSegmentedControl.onChanged] when tapped)
/// -- callers are responsible for [T] having a meaningful `==`, the same
/// assumption Flutter's own generic selection widgets make. [label] is the
/// text shown on the segment.
@immutable
class CruxSegment<T> {
  /// Creates a segmented-control option.
  const CruxSegment({required this.value, required this.label});

  /// The value this segment represents.
  final T value;

  /// The segment's visible label. Always rendered on a single line with an
  /// ellipsis, matching [CruxChip]'s label.
  final String label;
}

/// A single-selection, exclusive-choice control: a row of segments where
/// exactly one is selected at a time, drawn as a pill-shaped track holding
/// a smaller row of pill-shaped options.
///
/// ```dart
/// CruxSegmentedControl<String>(
///   segments: const <CruxSegment<String>>[
///     CruxSegment<String>(value: 'recommended', label: 'おすすめ'),
///     CruxSegment<String>(value: 'today', label: '今日中'),
///     CruxSegment<String>(value: 'draft', label: '下書き'),
///   ],
///   selected: currentTab,
///   onChanged: (String next) => setState(() => currentTab = next),
/// )
/// ```
///
/// **[CruxSegmentedControl] vs. [CruxChip]**: these are the two
/// selection atoms this package ships, and they serve different jobs.
/// [CruxSegmentedControl] is a single-selection control with exclusivity
/// built in -- exactly one segment is ever selected, the same "which one of
/// these mutually exclusive options" role a `role="tablist"`/radio group
/// plays. [CruxChip] has no built-in exclusivity at all: a row of
/// [CruxChip]s is a multi-select filter list, where any number (including
/// zero) can be [CruxChip.selected] at once, and enforcing "at most one"
/// (if ever needed) is entirely the caller's own state-management job, not
/// this package's. Reach for [CruxSegmentedControl] when the choice is
/// inherently one-of-many (a view switcher, a unit toggle); reach for
/// [CruxChip] when it's a filter (zero, one, or many active tags).
///
/// [CruxSegmentedControl] is a controlled widget, the same convention
/// [CruxCheckbox] and [CruxSwitch] use: it always reflects [selected]
/// and never mutates it itself, notifying [onChanged] with the tapped
/// segment's value so the caller decides whether and how to update its
/// state. Set [onChanged] to `null` to render every segment disabled
/// (Flutter convention, matching [CruxButton]'s `onPressed`).
///
/// Tapping the *already-selected* segment does not call [onChanged]: since
/// this is a controlled widget whose [selected] would not actually change,
/// there is nothing new to notify (the same "reacts to changes, not
/// levels" contract [CruxMotion.shake]'s `trigger` follows), and it keeps
/// this widget's own selection-changed visual effects (the plate's
/// appear/disappear and the kira sheen below) correctly gated to real
/// changes without a separate "did this notification actually change
/// anything" check at every call site.
///
/// The selected segment is drawn with no position-changing animation at
/// all -- unlike a typical sliding-indicator segmented control, nothing
/// ever translates. Instead, each segment owns its own selection "plate" (a
/// [CruxColors.controlPlate] pill with [CruxShadows.xs]) that fades and
/// scale-springs in when its segment becomes selected (`0.8 -> ~1.02 ->
/// 1.0`, via [CruxMotion.animatedValue]'s `playful` spring) and fades out
/// when it stops being selected; the label text itself never moves. About
/// 90ms after a real selection change, a diagonal "kira" light sweep plays
/// once across the newly selected segment's plate, tilted and swept in the
/// direction of travel (rightward moves sweep left-to-right with a positive
/// tilt, leftward moves mirror both). Neither the plate's spring nor the
/// sheen animates on the widget's first build or when re-tapping the
/// already-selected segment. If the selection moves on again before a
/// segment's own sheen has finished sweeping, that sheen is never cut off:
/// it keeps playing out its full sweep on its own independent schedule,
/// while whichever segment is now selected gets its own, separately-timed
/// sheen a further ~90ms later.
///
/// Set [MediaQuery.disableAnimationsOf] (the OS "reduce motion"
/// accessibility setting) to suppress both of these purely decorative
/// effects: the plate then jumps directly to its resting opacity/scale with
/// no fade or bounce, and the kira sheen never sweeps at all -- the
/// selection itself is still fully communicated (via the plate's presence
/// and this widget's semantics), only the ornamental motion is skipped.
///
/// Like [CruxChip] and [CruxCheckbox], this widget is built from plain
/// [GestureDetector] and painting widgets rather than a Material tab bar or
/// segmented control, so it never depends on or is affected by an ambient
/// Material `ThemeData`.
class CruxSegmentedControl<T> extends StatefulWidget {
  /// Creates a Crux segmented control.
  const CruxSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    this.onChanged,
  });

  /// The ordered list of options this control presents. Must have at least
  /// two entries.
  final List<CruxSegment<T>> segments;

  /// The currently selected value. Must equal exactly one of [segments]'
  /// values for the control to show a selection.
  final T selected;

  /// Called with a segment's value when that segment is tapped while a
  /// *different* segment is selected. Pass `null` to disable every segment
  /// in the control.
  final ValueChanged<T>? onChanged;

  @override
  State<CruxSegmentedControl<T>> createState() =>
      _CruxSegmentedControlState<T>();
}

class _CruxSegmentedControlState<T> extends State<CruxSegmentedControl<T>> {
  Timer? _sheenDelayTimer;

  /// Each segment's own kira sheen trigger count, keyed by [CruxSegment
  /// .value]. Absent (`?? 0` at every read site) means never triggered --
  /// the same `0` [CruxMotion.playOnce] treats as "never triggered". Once
  /// set, an entry is only ever incremented, never reset when the sheen
  /// moves to a different segment: resetting it would cut a still-sweeping
  /// sheen off instantly. See [_scheduleSheen].
  final Map<T, int> _sheenTriggerByValue = <T, int>{};

  /// Each segment's own sweep direction (`true` for left-to-right), updated
  /// in lockstep with [_sheenTriggerByValue] at the same key. Kept
  /// per-segment so a still-sweeping segment's direction can't be flipped
  /// mid-flight by a different segment starting a sweep the opposite way.
  final Map<T, bool> _sheenLtrByValue = <T, bool>{};

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(covariant CruxSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) {
      return;
    }
    final int oldIndex = widget.segments.indexWhere(
      (CruxSegment<T> segment) => segment.value == oldWidget.selected,
    );
    final int newIndex = widget.segments.indexWhere(
      (CruxSegment<T> segment) => segment.value == widget.selected,
    );
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) {
      // Either endpoint isn't in the segment list, or nothing moved --
      // skip the sheen.
      return;
    }
    _scheduleSheen(target: widget.selected, movesRight: newIndex > oldIndex);
  }

  /// Schedules [target]'s kira sheen to start after [_sheenDelay], bumping
  /// only that segment's own entry in [_sheenTriggerByValue] -- every other
  /// segment's entry, including one still mid-sweep, is left untouched so
  /// its sweep finishes uninterrupted. [CruxMotion.playOnce] only reacts
  /// to a *changed* `trigger`; a segment whose entry is never touched never
  /// sees a change, however long its own sweep still has left to run.
  void _scheduleSheen({required T target, required bool movesRight}) {
    _sheenDelayTimer?.cancel();
    _sheenDelayTimer = Timer(_sheenDelay, () {
      setState(() {
        _sheenTriggerByValue[target] = (_sheenTriggerByValue[target] ?? 0) + 1;
        _sheenLtrByValue[target] = movesRight;
      });
    });
  }

  void _handleSegmentTap(T value) {
    if (value == widget.selected) {
      // Re-tapping the already-selected segment notifies nothing -- see
      // this class's own doc for why.
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
      widget.segments.length >= 2,
      'CruxSegmentedControl needs at least two segments to be a '
      'meaningful exclusive choice.',
    );
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool enabled = _enabled;

    // Reports _minTapTarget (44), taller than the visible 40px pill, so
    // the Row below gets a loose height constraint each segment's own
    // ConstrainedBox(minHeight: 44) can actually bind to -- see
    // _minTapTarget's doc.
    return SizedBox(
      height: _minTapTarget,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The visible pill background -- purely decorative. Fixed at its
          // own 40-tall size and centered by the Stack inside the taller
          // 44-tall shell above, leaving a 2px transparent margin above
          // and below that only the segments' own taller tap targets
          // reach into.
          Container(
            width: double.infinity,
            height: _controlPadding * 2 + _visibleSegmentHeight,
            decoration: ShapeDecoration(
              color: colors.controlFill,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(CruxRadii.pill)),
              ),
            ),
          ),
          // The interactive row. Horizontal padding matches
          // _controlPadding so each segment's cell lines up with the pill
          // beneath it. Not wrapped in anything that forces a tight height
          // below 44, so each segment's own ConstrainedBox(minHeight: 44)
          // can still resolve to a real 44.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _controlPadding),
            child: Row(
              children: <Widget>[
                for (final CruxSegment<T> segment in widget.segments)
                  Expanded(
                    key: ValueKey<T>(segment.value),
                    child: _CruxSegmentButton<T>(
                      label: segment.label,
                      selected: segment.value == widget.selected,
                      enabled: enabled,
                      onTap: enabled
                          ? () => _handleSegmentTap(segment.value)
                          : null,
                      sheenTrigger: _sheenTriggerByValue[segment.value] ?? 0,
                      sheenLtr: _sheenLtrByValue[segment.value] ?? true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The private per-segment button: press feedback, the selection plate, the
/// kira sheen, and the label. Not exported -- callers only ever see
/// [CruxSegmentedControl].
class _CruxSegmentButton<T> extends StatefulWidget {
  const _CruxSegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.sheenTrigger,
    required this.sheenLtr,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  /// This segment's own kira trigger count -- see
  /// [_CruxSegmentedControlState._sheenTriggerByValue].
  final int sheenTrigger;

  /// The sweep direction for this segment's next kira sheen: `true` for
  /// left-to-right, `false` for right-to-left. Only meaningful while
  /// [sheenTrigger] is driving a sweep.
  final bool sheenLtr;

  @override
  State<_CruxSegmentButton<T>> createState() => _CruxSegmentButtonState<T>();
}

class _CruxSegmentButtonState<T> extends State<_CruxSegmentButton<T>> {
  bool _pressed = false;

  // Guarantees the pressed scale stays visible for a minimum duration even
  // if a tap's down/up arrive back-to-back (e.g. inside a scroll view) --
  // see press_feedback.dart's class doc.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  // Only _handleTapDown checks `enabled`, since it's the only handler that
  // *starts* a press. _handleTapUp/_handleTapCancel always resolve any
  // in-flight press unconditionally, so a press that started while enabled
  // still ends cleanly even if the segment becomes disabled mid-press.
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
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Color textColor = !widget.enabled
        ? colors.muted
        : (widget.selected ? colors.textPrimary : colors.textSecondary);

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      // No explicit `label`: the child Text below already supplies its
      // own automatic semantics label, and nothing between this node and
      // that Text introduces a merge boundary.
      //
      // The ConstrainedBox below gives this segment's tap target a real,
      // reported _minTapTarget (44) height -- see _minTapTarget's doc for
      // why a reported OverflowBox size alone would silently drop taps.
      // It only resolves to 44 because the row above sits in a loose
      // SizedBox(height: 44), not a tight _visibleSegmentHeight one. The
      // inner Center+SizedBox pair below re-confines the visible content
      // (plate, sheen, label) back down to _visibleSegmentHeight, centered
      // within the 44-tall tap region -- Center is required there, not
      // optional, to loosen the tight 44 constraint enough for that inner
      // SizedBox to validly tighten to 32 (nesting a bare
      // SizedBox(height: 32) directly inside a *tight* 44 constraint would
      // throw instead).
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTapTarget),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          child: CruxMotion.scale(
            value: _pressed ? CruxMotion.pressedScale : 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _minTapTarget),
              child: Center(
                child: SizedBox(
                  // `width: double.infinity` (clamped back down to
                  // whatever finite max width Center offers, i.e. this
                  // segment's own cell) keeps the Stack below tight in
                  // both dimensions. Center's loosened constraints (see
                  // the ConstrainedBox doc above) loosen width too, and a
                  // loose-width Stack (the default StackFit.loose) shrinks
                  // to fit its one non-positioned child -- the label --
                  // instead of filling the cell, which every
                  // Positioned.fill below (plate, sheen mask) is relative
                  // to.
                  width: double.infinity,
                  height: _visibleSegmentHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Positioned.fill(child: _buildPlate(theme, reduceMotion)),
                      Positioned.fill(
                        child: _buildSheenMask(theme, reduceMotion),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _segmentHorizontalPadding,
                        ),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.typography.labelSmall.copyWith(
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the selection "plate": a [CruxColors.controlPlate] pill with
  /// [CruxShadows.xs], present for every segment but only ever visible
  /// for the selected one. Opacity is a plain ease-out fade (asymmetric
  /// duration -- [_plateFadeInDuration] appearing, the shorter
  /// [_plateFadeOutDuration] disappearing), while scale always springs
  /// toward its target via [CruxMotion.animatedValue]'s `playful` spring,
  /// including while fading out -- that motion is never seen since the
  /// plate is already fully transparent by the time the fade finishes.
  ///
  /// Fills with [CruxColors.controlPlate] rather than [CruxColors
  /// .surface]: in the dark palette, plain [CruxColors.surface] measures
  /// only ~1.05:1 against [CruxColors.dark.controlFill], well below WCAG
  /// 1.4.11's 3:1 non-text contrast floor, so the selected state would be
  /// distinguishable only by the label's color change, not by the plate
  /// itself. [CruxColors.controlPlate] exists to fix that (~1.43:1 in
  /// dark; the remaining gap to the 3:1 floor is carried by the label --
  /// see that token's own doc in `colors.dart`). In the light palette,
  /// [CruxColors.controlPlate] equals [CruxColors.surface], so this is
  /// a no-op swap there.
  Widget _buildPlate(CruxThemeData theme, bool reduceMotion) {
    final Widget plateBox = DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colors.controlPlate,
        shadows: theme.shadows.xs,
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

  /// Builds the kira sheen mask. [CruxMotion.playOnce] stays mounted even
  /// before [sheenTrigger] first increments: mounting it fresh at an
  /// already-nonzero trigger would never animate, since it only reacts to
  /// a *change* via `didUpdateWidget`, not an initial value. Until then,
  /// `progress` stays `0.0`, so this subtree is a cheap no-op.
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

/// The sheen's peak highlight color: [CruxColors.surface] in the light
/// palette, [CruxColors.textPrimary] in the dark one -- each already the
/// brightest existing token in its own palette, reused here instead of a
/// new raw color value (this package's raw-color-values-in-colors.dart-only
/// rule).
Color _sheenPeakColor(CruxThemeData theme) {
  return theme.brightness == Brightness.light
      ? theme.colors.surface
      : theme.colors.textPrimary;
}
