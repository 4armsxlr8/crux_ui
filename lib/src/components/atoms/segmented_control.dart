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
/// [CruxSegmentedControl] shell, and for each single segment inside it
/// (matches [CruxButton]'s and [CruxChip]'s own `_minTapTarget`): 44
/// logical pixels -- taller than the 40px pill itself
/// (`_controlPadding * 2 + _visibleSegmentHeight`, the confirmed 2026-08-02
/// "ピルを 40px に" spec, down from an earlier 52px pill where the visible
/// pill and the tap target were the same height).
///
/// This constant is used at two levels, and both matter for the same
/// reason. An earlier version of this file wrapped only the per-segment
/// interactive content in an [OverflowBox] forced to this height -- but
/// [RenderBox.hitTest] gates every tap against a box's *own reported size*
/// before it ever recurses into that box's child, and [OverflowBox] reports
/// its own size from whatever *incoming* constraint its parent hands it,
/// not from the overridden size it lays its child out at. With the
/// segments' row itself pinned to a tight [_visibleSegmentHeight] (32),
/// that reported size stayed 32 no matter how tall the child underneath
/// grew, so taps into the "overflowed" 44-tall region above/below the pill
/// were silently dropped -- a real, once-shipped bug (see
/// `segmented_control_test.dart`'s "tap target" group for the regression
/// test).
///
/// The fix instead makes every *reported* size actually be 44, the same
/// `minHeight` pattern [CruxButton] and [CruxChip] already use for
/// their own tap regions: a real `ConstrainedBox(minHeight: _minTapTarget)`
/// around each segment's interactive content
/// ([_CruxSegmentButtonState.build]), *and* a real `SizedBox(height:
/// _minTapTarget)` around the whole control
/// ([_CruxSegmentedControlState.build]). The outer one is what matters
/// structurally: it is what gives the row of segments a *loose* (not
/// tight) incoming height constraint up to 44 in the first place, which is
/// what lets each segment's own `ConstrainedBox(minHeight: 44)` actually
/// bind instead of being clamped straight back down to a smaller tight
/// ambient constraint. The visible pill (the [CruxColors.controlFill]
/// background, 40px tall) is a separate, purely decorative layer painted
/// centered inside that 44-tall shell, so the pill's own visible bounds
/// never grow to match the tap target -- see
/// [_CruxSegmentedControlState.build] for the full layout.
const double _minTapTarget = 44;

/// The padding around the whole control, inside its pill background and
/// outside every segment -- matches mock-b-shadow.html's `.segmented`
/// (`padding: 4px`).
const double _controlPadding = 4;

/// Each segment's own visible height, in logical pixels: the fixed height of
/// the purely decorative pill background
/// ([_CruxSegmentedControlState.build] sizes it to exactly
/// `_controlPadding * 2 + _visibleSegmentHeight`), and in turn -- via
/// [_CruxSegmentButtonState.build]'s own inner `SizedBox` at the same
/// height -- the height every segment's selection plate, kira sheen, and
/// label are confined to. Together with [_controlPadding] on the top and
/// bottom, this yields the pill's own overall height, `40` (`4 + 32 + 4`) --
/// the confirmed 2026-08-02 "ピルを 40px に" spec. Deliberately shorter than
/// [_minTapTarget] (`44`); see that constant's doc for how the 4px
/// difference is absorbed as a transparent margin around the pill instead,
/// inside the real (not merely reported) taller tap target every segment's
/// own row actually lays out at.
const double _visibleSegmentHeight = 32;

/// The horizontal padding inside a single segment, around its label.
const double _segmentHorizontalPadding = 12;

/// How long the newly selected segment's plate takes to fade in, once it
/// starts appearing. The scale spring driving its bounce ([CruxMotion
/// .animatedValue]'s `playful` spring) runs on its own independent timeline
/// -- see [_CruxSegmentButtonState._buildPlate]'s doc.
const Duration _plateFadeInDuration = Duration(milliseconds: 200);

/// How long the just-deselected segment's plate takes to fade out --
/// shorter than [_plateFadeInDuration], matching the confirmed "解除側は
/// すっとフェードアウト（約140ms）" spec.
const Duration _plateFadeOutDuration = Duration(milliseconds: 140);

/// The plate's scale immediately before it starts appearing -- the spring
/// then springs it toward `1.0`, overshooting past it on the way (see
/// [_CruxSegmentButtonState._buildPlate]'s doc for why `0.8`, not
/// something closer to `1.0`, is what produces the confirmed "~1.02" peak).
const double _plateAppearStartScale = 0.8;

/// The kira sheen's confirmed tilt, in degrees -- 2026-08-01 measured value
/// (`unknowns/atoms-batch-3/ledger.md`). Positive tilts the band for a
/// left-to-right sweep (moving to a segment on the right); negative mirrors
/// it for right-to-left (moving left).
const double _sheenTiltDegrees = 4;

/// The kira sheen's confirmed peak highlight opacity -- 2026-08-01 measured
/// value.
const double _sheenPeakAlpha = 0.24;

/// The kira sheen's confirmed edge-shadow opacity (the faint darkening
/// flanking the highlight, added so the sweep stays visible over a
/// same-hued plate -- see [_sheenPeakColor]'s doc) -- 2026-08-01 measured
/// value.
const double _sheenEdgeAlpha = 0.05;

/// The kira sheen's confirmed blur, in logical pixels, used directly as
/// [ImageFilter.blur]'s sigma -- 2026-08-01 measured value. Carried straight
/// over without a unit conversion, the same convention `shadows.dart`
/// already uses for its own blur radii (the CSS mock's blur px values are
/// used as Flutter blur radii verbatim).
const double _sheenBlurSigma = 8;

/// The kira sheen's confirmed sweep duration -- 2026-08-01 measured value.
const Duration _sheenDuration = Duration(milliseconds: 300);

/// How long after a real selection change the kira sheen starts sweeping --
/// 2026-08-01 measured value ("出現の約90ms後").
const Duration _sheenDelay = Duration(milliseconds: 90);

/// The sheen band's width as a fraction of the segment's own width, matching
/// the mock's `.segment-sheen { width: 38%; }`.
const double _sheenWidthFraction = 0.38;

/// How far past each edge of the segment the sheen band travels before/after
/// the sweep, as a multiple of the band's own width -- matches the mock's
/// `translateX(-130%)` / `translateX(230%)` keyframe endpoints (a band of
/// width `w` translated by `-1.3w`/`+1.3w` relative to the segment's near
/// edge lands at those same percentages of the segment's own width when the
/// band is `0.38` of it).
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
/// [CruxColors.controlPlate] pill with [CruxShadows.sm]) that fades and
/// scale-springs in when its segment becomes selected (`0.8 -> ~1.02 ->
/// 1.0`, via [CruxMotion.animatedValue]'s `playful` spring) and fades out
/// when it stops being selected; the label text itself never moves. About
/// 90ms after a real selection change, a diagonal "kira" light sweep plays
/// once across the newly selected segment's plate, tilted and swept in the
/// direction of travel (rightward moves sweep left-to-right with a positive
/// tilt, leftward moves mirror both). Neither the plate's spring nor the
/// sheen ever animates on the widget's first build or on a same-segment
/// re-tap -- see this class's `didUpdateWidget`-driven change detection in
/// `segmented_control.dart` for how that's enforced structurally rather
/// than by a separate flag. If the selection moves on again before a
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
  /// .value]. A segment absent from this map (`?? 0` at every read site)
  /// has never been the sheen's target -- the same `0` [CruxMotion
  /// .playOnce] treats as "never triggered".
  ///
  /// Once a segment *has* an entry, that entry is only ever incremented,
  /// never reset back to `0` when the sheen moves on to a different
  /// segment -- see [_scheduleSheen]'s doc for why: resetting it used to
  /// cut a still-sweeping sheen off instantly the moment a different
  /// segment became the new target.
  final Map<T, int> _sheenTriggerByValue = <T, int>{};

  /// Each segment's own sweep direction (`true` for left-to-right),
  /// updated in lockstep with [_sheenTriggerByValue] at the same key. Kept
  /// per-segment rather than as one shared field for the same reason the
  /// trigger count is: once a segment's sheen has started, its own
  /// direction must stay fixed for the rest of that sweep even if a
  /// *different* segment starts sweeping the opposite way in the meantime.
  /// A single shared direction field would otherwise flip the tilt on an
  /// unrelated segment's still-finishing sheen mid-flight.
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
      // Either endpoint isn't in the current segment list (nothing to
      // compute a sweep direction from) or nothing actually moved -- skip
      // the sheen, matching the "no sheen unless a real move happened"
      // contract this class's own doc promises.
      return;
    }
    _scheduleSheen(target: widget.selected, movesRight: newIndex > oldIndex);
  }

  /// Schedules [target]'s kira sheen to start after [_sheenDelay], bumping
  /// only *that* segment's own entry in [_sheenTriggerByValue] once the
  /// delay elapses -- every other segment's entry (including whichever
  /// segment was previously mid-sweep) is left completely untouched.
  ///
  /// An earlier version of this class instead kept one shared trigger
  /// counter plus a single "current target" value, resetting a
  /// no-longer-targeted segment's rendered trigger back to `0` in
  /// [CruxSegmentedControl]'s `build`. That reset is what broke a fast
  /// re-selection (A -> B -> C before B's sweep finished): [CruxMotion
  /// .playOnce]'s `progress` is computed as a *windowed*
  /// `animatedValue - baseline`, and yanking a segment's own trigger
  /// backwards moves that window's baseline ahead of wherever the
  /// underlying spring/curve value actually still was, clamping `progress`
  /// straight to `0.0` instead of letting the sweep ease out on its own
  /// schedule -- see `test/components/atoms/segmented_control_test.dart`'s
  /// "kira sheen survives rapid retarget" group, which failed before this
  /// fix. Never touching an old target's entry avoids that: a segment that
  /// stops being the sheen's target keeps whatever [CruxMotion.playOnce]
  /// trigger it already had, so [CruxMotion.playOnce] never sees a
  /// changed `trigger` for it and its in-flight sweep (if any) simply
  /// finishes uninterrupted.
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

    // Pins the whole control's own reported/natural height to
    // _minTapTarget (44), deliberately taller than the visible pill (40)
    // painted inside it -- see _minTapTarget's doc for why this outer
    // SizedBox matters structurally: it is what gives the Row below a
    // *loose* incoming height constraint up to 44, which each segment's own
    // ConstrainedBox(minHeight: 44) (_CruxSegmentButtonState.build) then
    // actually binds to, instead of being clamped back down to a smaller
    // tight ambient constraint the way an inner-only fix would be.
    return SizedBox(
      height: _minTapTarget,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The visible pill background -- purely decorative, no
          // interactive content of its own. Fixed at its own 40-tall size
          // (`_controlPadding * 2 + _visibleSegmentHeight`) and centered by
          // the Stack's alignment inside the taller 44-tall shell above,
          // leaving a 2px transparent margin above and below it that only
          // the segments' own (taller) tap targets below reach into.
          Container(
            width: double.infinity,
            height: _controlPadding * 2 + _visibleSegmentHeight,
            decoration: ShapeDecoration(
              color: colors.controlFill,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(CruxRadii.pill),
                ),
              ),
            ),
          ),
          // The real, interactive row -- horizontal padding matches the
          // pill's own _controlPadding so each segment's cell lines up with
          // the visible pill beneath it. Deliberately *not* wrapped in
          // anything that forces a tight height smaller than 44: this Row
          // receives the Stack's own loose 0..44 height (loose because it's
          // the Stack, not a tight ancestor of the Row, that the outer
          // SizedBox above actually pins to 44), which is exactly what lets
          // each segment's own ConstrainedBox(minHeight: 44) resolve to a
          // real 44 instead of being clamped back down.
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

  /// This segment's own running kira trigger count: `0` until this segment
  /// has been the target of at least one real selection change, then its
  /// own independently-incrementing count from that point on --
  /// [CruxMotion.playOnce]'s trigger contract. Once a segment has a
  /// nonzero count, it is never reset back to `0` just because a
  /// *different* segment becomes the sheen's next target (see
  /// [_CruxSegmentedControlState]'s doc for why: a still-sweeping sheen
  /// must be free to finish on its own schedule rather than being cut off
  /// by an unrelated segment's turn).
  final int sheenTrigger;

  /// The sweep direction for this segment's next kira sheen: `true` for a
  /// left-to-right sweep with a positive tilt (moving to a segment on the
  /// right), `false` for the mirrored right-to-left sweep (moving left).
  /// Only meaningful while [sheenTrigger] is actively driving a sweep.
  final bool sheenLtr;

  @override
  State<_CruxSegmentButton<T>> createState() =>
      _CruxSegmentButtonState<T>();
}

class _CruxSegmentButtonState<T> extends State<_CruxSegmentButton<T>> {
  bool _pressed = false;

  // Guarantees the pressed scale stays visible for a minimum duration even
  // when a tap's down and up arrive back-to-back (e.g. inside a scroll
  // view) -- see press_feedback.dart's class doc for the bug this fixes.
  // Same wiring as CruxChip's/CruxCheckbox's identically-named field.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  // Mirrors CruxChip's/CruxCheckbox's onTapDown/onTapUp/onTapCancel
  // wiring: only _handleTapDown checks `enabled`, since it is the only
  // handler that *starts* a press. _handleTapUp and _handleTapCancel always
  // resolve any in-flight press unconditionally, so a press that started
  // while enabled still ends -- and un-presses -- cleanly even if the
  // segment becomes disabled mid-press.
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
      // No explicit `label` here for the same reason as CruxChip: the
      // child Text below already supplies its own automatic semantics
      // label, and nothing between this Semantics node and that Text
      // introduces a merge boundary.
      //
      // The ConstrainedBox below is what gives this segment's real tap
      // target a genuine, reported _minTapTarget (44) height, the same
      // `minHeight` pattern CruxButton and CruxChip already use for
      // their own tap regions -- rather than an OverflowBox's smaller
      // *reported* size with a taller child underneath it (a real,
      // once-shipped bug here: RenderBox.hitTest gates every tap against a
      // box's own reported size before it ever recurses into that box's
      // child, so a too-small reported size silently drops taps into the
      // "overflowed" region no matter how tall the child underneath
      // actually is -- see segmented_control_test.dart's "tap target"
      // group). ConstrainedBox(minHeight: 44) only actually resolves to 44,
      // though, because _CruxSegmentedControlState.build wraps the row of
      // segments in a real SizedBox(height: _minTapTarget) instead of a
      // tight _visibleSegmentHeight one -- see that method's doc. Inside
      // this 44-tall subtree, the inner Center+SizedBox pair below
      // re-confines the *visible* content (plate, sheen, label) back down
      // to _visibleSegmentHeight, centered within the 44-tall tap region --
      // Center is required there, not optional, to loosen the tight 44
      // constraint back to a range SizedBox(height: _visibleSegmentHeight)
      // can validly tighten to 32 (a bare SizedBox nested directly inside a
      // *tight* 44 constraint would instead throw, since a tight 44 and a
      // tight 32 aren't simultaneously satisfiable).
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
                  // whatever finite max width Center actually offers, i.e.
                  // this segment's own cell) keeps the Stack below tight
                  // in both dimensions. Without it, Center's loosened
                  // constraints (loosened to let the *height* shrink from
                  // 44 to _visibleSegmentHeight -- see the ConstrainedBox
                  // doc above) leave this SizedBox's width unbounded-loose
                  // too, and a loose-width Stack (StackFit.loose, the
                  // default) shrinks to fit its one non-positioned child
                  // -- the label -- instead of filling the cell. That
                  // shrunk Stack size is what every Positioned.fill below
                  // (the plate, the sheen mask) is relative to, so the
                  // plate collapsed to the label's own text width instead
                  // of covering the full segment, contradicting
                  // mock-b-shadow.html's `.segment-plate { position:
                  // absolute; inset: 0; }` relative to the whole
                  // `flex: 1` `.segment` box.
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
                          style: theme.typography.label.copyWith(
                            fontSize: 13,
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
  /// for the selected one. Opacity and scale are driven independently
  /// (matching the mock's decoupled `transition: opacity ..., transform
  /// ...`, which run on different durations for the same trigger): opacity
  /// is a plain ease-out fade (asymmetric duration -- [_plateFadeInDuration]
  /// appearing, the shorter [_plateFadeOutDuration] disappearing, per the
  /// confirmed spec), while scale always springs toward its target via
  /// [CruxMotion.animatedValue]'s `playful` spring. Scale's target while
  /// *not* selected is [_plateAppearStartScale] (`0.8`) rather than `1.0`:
  /// this is the plate's rest position going into its *next* appearance,
  /// and it is never visible while opacity is `0`, so which direction it
  /// settles from while hidden has no visual effect -- reusing the same
  /// spring for both directions (rather than only springing on appear and
  /// snapping instantly on disappear) keeps this method single-pathed. The
  /// disappearing plate's scale therefore also springs (rather than easing)
  /// while it fades out, but since it is fading to fully transparent over
  /// [_plateFadeOutDuration] regardless, that motion is never seen.
  ///
  /// Uses [CruxShadows.xs] rather than [CruxShadows.sm] (2026-08-02,
  /// "選択プレートの影を控えめにしたい", referencing an iOS-style tab switch
  /// whose selected plate reads as almost flush with its track): [sm] was
  /// tuned for a control -- a switch knob -- that needs to visibly separate
  /// from what is behind it, which read as too prominent here, where the
  /// plate should signal only a hair of separation from the pill track it
  /// sits on.
  ///
  /// Fills with [CruxColors.controlPlate] rather than [CruxColors
  /// .surface] (2026-08-02, "ダークモードの SegmentedControl 選択プレートの
  /// コントラストを改善する" --色の変更で改善, superseding an earlier same-day
  /// attempt at a dark-only 1px [CruxColors.muted] hairline outline
  /// instead). Plain [CruxColors.surface] measures only ~1.05:1 against
  /// the track it sits on ([CruxColors.dark.controlFill], `#262319`) in
  /// the dark palette -- far below WCAG 1.4.11's 3:1 non-text contrast
  /// floor, so the selected state was only distinguishable by the label's
  /// color change, not by the plate's own fill. [CruxColors.controlPlate]
  /// exists specifically to fix that: its dark value (`#3F3C33`) measures
  /// ~1.43:1 against [CruxColors.dark.controlFill] -- see that token's own
  /// doc in `colors.dart` for how it is derived and why it stays short of
  /// the 3:1 floor by design (the floor is carried by the label instead).
  /// In the light palette, [CruxColors.controlPlate] is defined identical
  /// to [CruxColors.surface], so this is a no-op swap there -- the
  /// confirmed 2026-08-02 "light はそのまま" preference, since the light
  /// palette's plate/track pairing already had enough native contrast and
  /// nobody asked to change that look.
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

  /// Builds the kira sheen mask. [CruxMotion.playOnce] is always mounted
  /// (never conditionally built only once [sheenTrigger] becomes nonzero):
  /// staying mounted from this segment's very first build is what lets a
  /// later real trigger change arrive as a normal `didUpdateWidget`
  /// transition (which actually plays the `0 -> 1` ramp) rather than a
  /// fresh `initState` mount already sitting at a nonzero trigger (which
  /// would never animate at all -- `motor`'s controller only starts
  /// animating in response to a *change*, not an initial value). While
  /// [sheenTrigger] has never incremented, [CruxMotion.playOnce] reports a
  /// steady `progress == 0.0`, which the `progress <= 0.0` guard below hides
  /// -- so this is a no-op subtree (cheap to keep always-mounted) whenever
  /// no sheen has ever played for this segment.
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
/// palette, [CruxColors.textPrimary] in the dark one.
///
/// This reuses two *existing* [CruxColors] fields rather than introducing
/// a new raw color value (this package's "raw color values live in
/// `colors.dart` only" rule, plus this batch's own scoping, which reserves
/// `colors.dart` for a different editor): [CruxColors.light.surface] is
/// `#FFFFFF`, and [CruxColors.dark.textPrimary] is `#F6F5EF` -- exactly
/// the two brightness-specific values `unknowns/atoms-batch-3/mock-b-shadow
/// .html` hardcodes for its own `--sheen-ink` variable (`255, 255, 255` for
/// light, `246, 245, 239` for dark; see that file's comments on
/// `--sheen-ink`). Each is, not coincidentally, the *brightest* existing
/// token in its own palette -- [CruxColors.light]'s surface is pure white,
/// and [CruxColors.dark] has no near-white surface of its own, so its
/// `textPrimary` (already near-white for text-on-dark contrast) stands in
/// for the same role.
Color _sheenPeakColor(CruxThemeData theme) {
  return theme.brightness == Brightness.light
      ? theme.colors.surface
      : theme.colors.textPrimary;
}
