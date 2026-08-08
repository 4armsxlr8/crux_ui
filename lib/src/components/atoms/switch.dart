import 'package:flutter/widgets.dart';

import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/theme.dart';

/// The minimum tap target size for any [CruxSwitch] (matching
/// [CruxButton]'s minimum tap target rule): 44 logical pixels, even though
/// the visible track is shorter than that.
const double _minTapTarget = 44;

/// The visible track's width and height, and the thumb's diameter at rest.
const double _trackWidth = 52;
const double _trackHeight = 32;
const double _thumbSize = 28;

/// The thumb's width while held down (an iOS-style "thumb stretch"): it
/// widens toward the track's center while pressed and springs back to
/// [_thumbSize] on release. The 52-wide track's inner space (after
/// [_thumbInset] on each side) is 48 logical pixels, comfortably wider than
/// this, so the stretched thumb never overflows it.
const double _thumbStretchedSize = 34;

/// The gap between the thumb and the track's top/bottom/side edges:
/// `(trackHeight - thumbSize) / 2`, kept equal on every side so the thumb
/// reads as centered within the pill at rest.
const double _thumbInset = (_trackHeight - _thumbSize) / 2;

/// The track's inner content width -- the coordinate space the thumb's
/// leading/trailing edges (see [_CruxSwitchState.build]) are positioned
/// in -- after [_thumbInset] is subtracted from both sides: 48 for the
/// current 52-wide track and 2-wide inset.
const double _innerWidth = _trackWidth - 2 * _thumbInset;

/// The floor the thumb's height is clamped to while it is stretched thin
/// during a "liquid travel" flight (see the class doc): 60% of
/// [_thumbSize], chosen so the roughly area-preserving width<->height
/// relationship in [_CruxSwitchState.build] never thins the thumb down to
/// reading as a sliver, however wide a flight momentarily stretches it.
const double _thumbMinHeight = _thumbSize * 0.6;

/// A pill-shaped, spring-animated on/off toggle: Crux UI's switch atom.
///
/// ```dart
/// CruxSwitch(
///   value: isEnabled,
///   onChanged: (bool next) => setState(() => isEnabled = next),
/// )
/// ```
///
/// [CruxSwitch] is a controlled widget, the same convention Flutter's own
/// `Switch` uses: it always reflects [value] and never mutates it itself,
/// notifying [onChanged] with the flipped value on tap so the caller decides
/// whether and how to update its state. Set [onChanged] to `null` to render
/// a disabled switch (Flutter convention, matching [CruxButton]'s
/// `onPressed`).
///
/// Tapping anywhere in the switch's 44 logical pixel hit area toggles it.
/// Rather than sliding as a rigid circle, the thumb travels with a
/// "liquid" feel: its leading edge (the edge nearer the destination side)
/// springs ahead quickly via [CruxMotion] while its trailing edge (the
/// edge nearer the side it's leaving) follows on a slower [CruxMotion]
/// spring, so the thumb stretches thin and reaches across the track
/// mid-flight before relaxing back into a 28-diameter circle once both
/// edges arrive. Separately, while held down, the thumb also stretches
/// wider (iOS-style): it grows from whichever edge it currently occupies
/// toward the track's center, then springs back to its resting size on
/// release -- whether or not that release ends up toggling [value]. Both
/// stretches compose without a visual seam even if they overlap (e.g.
/// pressing again before a previous toggle's flight has settled), since
/// both are ultimately expressed as offsets on the same pair of
/// continuously-tracked edge positions rather than as one committed
/// "resting side" the other has to assume (see [_CruxSwitchState.build]).
/// A disabled switch never press-stretches:
/// [_CruxSwitchState._handleTapDown] only starts a press when enabled, so
/// [_CruxSwitchState._pressed] can never become true to stretch from. The
/// liquid-travel position spring is not gated the same way -- like any
/// other controlled widget, [CruxSwitch] keeps reflecting [value]
/// (including animating toward it) whether or not it is currently
/// interactive; disabling only stops new presses, not reactions to [value]
/// changing. Dragging the thumb to slide it is not supported in this
/// release.
///
/// Like [CruxButton], this widget is built from plain [GestureDetector]
/// and painting widgets rather than Material's `Switch`, so it never depends
/// on or is affected by an ambient Material `ThemeData`.
class CruxSwitch extends StatefulWidget {
  /// Creates a Crux switch.
  const CruxSwitch({super.key, required this.value, this.onChanged});

  /// Whether the switch is on. [CruxSwitch] never changes this itself;
  /// the caller owns this state and updates it from [onChanged].
  final bool value;

  /// Called with the flipped value when the switch is tapped. Pass `null`
  /// to disable the switch.
  final ValueChanged<bool>? onChanged;

  @override
  State<CruxSwitch> createState() => _CruxSwitchState();
}

class _CruxSwitchState extends State<CruxSwitch> {
  bool _pressed = false;

  bool get _enabled => widget.onChanged != null;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  // Only _handleTapDown checks `_enabled`, since it is the only handler
  // that *starts* a press. _handleTapUp and _handleTapCancel always resolve
  // any in-flight press unconditionally -- gating them by `enabled` instead
  // would tear the in-flight TapGestureRecognizer out of the gesture arena
  // if the switch becomes disabled mid-press.
  void _handleTapDown(TapDownDetails details) {
    if (_enabled) {
      _setPressed(true);
    }
  }

  void _handleTapUp(TapUpDetails details) => _setPressed(false);

  void _handleTapCancel() => _setPressed(false);

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool enabled = _enabled;
    final bool isOn = widget.value;
    final Color trackColor = _resolveTrackColor(
      colors: colors,
      value: isOn,
      enabled: enabled,
    );

    // The thumb's leading/trailing edges, in the track's inner content
    // coordinate space (0.._innerWidth): at rest, off spans
    // 0.._thumbSize and on spans (_innerWidth - _thumbSize).._innerWidth,
    // both _thumbSize wide. `leftEdge` and `rightEdge` below are tracked as
    // two independent springs rather than as one position+width pair, so
    // the gap between them -- the thumb's actual rendered width -- can
    // balloon out mid-flight and collapse back to _thumbSize once both
    // settle (the "liquid travel" effect described in the class doc).
    // Which edge gets the fast spring and which gets the slow one is
    // recomputed fresh from `isOn` on every build, so no separate
    // "previous value"/direction bookkeeping is needed.
    final double leftTarget = isOn ? _innerWidth - _thumbSize : 0.0;
    final double rightTarget = isOn ? _innerWidth : _thumbSize;

    return Semantics(
      container: true,
      toggled: isOn,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: enabled ? () => widget.onChanged!(!isOn) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            // Three fully independent springs are nested here (rather than
            // combined into one): the final width/height/position computed
            // below (in the innermost builder) needs all three values at
            // once every frame, so there is no static subtree that can be
            // hoisted out via `animatedValue`'s `child:` optimization --
            // every level of this nesting depends on the animated value(s)
            // above it.
            child: CruxMotion.animatedValue(
              value: leftTarget,
              // Trailing (slow) while moving toward "on" (leftEdge lags
              // behind rightEdge in that direction, which is what stretches
              // the thumb out behind the leading edge); leading (fast)
              // while moving toward "off".
              slow: isOn,
              builder: (BuildContext context, double leftEdge, Widget? child) {
                return CruxMotion.animatedValue(
                  value: rightTarget,
                  // Leading (fast) while moving toward "on"; trailing
                  // (slow) while moving toward "off".
                  slow: !isOn,
                  builder:
                      (BuildContext context, double rightEdge, Widget? child) {
                        return CruxMotion.animatedValue(
                          // A third, fully independent spring drives the
                          // press-stretch: 0.0 at rest, 1.0 while
                          // `_pressed`. Unlike leftEdge/rightEdge above,
                          // this always uses the plain fast spring
                          // regardless of `isOn`, so press feedback feels
                          // identical on both sides of the track rather
                          // than picking up the liquid-travel spring's
                          // direction-dependent speed.
                          value: _pressed ? 1.0 : 0.0,
                          builder:
                              (
                                BuildContext context,
                                double pressedFraction,
                                Widget? child,
                              ) {
                                final double stretchAmount =
                                    pressedFraction *
                                    (_thumbStretchedSize - _thumbSize);
                                // Press-stretch grows from whichever edge
                                // the thumb currently occupies -- based on
                                // the logical `isOn` state, not the
                                // in-flight animated position -- toward the
                                // center. Because this is an additive
                                // offset applied on top of whichever edge's
                                // own live (possibly still mid-flight)
                                // position, rather than a recomputation
                                // that assumes the position spring has
                                // already settled at a fixed 0/1 side, it
                                // stays correctly pinned to the occupied
                                // edge even if a press starts before a
                                // previous toggle's flight has finished --
                                // see the class doc's note on why this
                                // composes without a seam.
                                final double left = isOn
                                    ? leftEdge - stretchAmount
                                    : leftEdge;
                                final double right = isOn
                                    ? rightEdge
                                    : rightEdge + stretchAmount;

                                // The gap between the two edges is the
                                // thumb's rendered width, clamped to a
                                // small positive floor as a guard against a
                                // hypothetical transient crossover (e.g. a
                                // bouncy spring overshoot during a rapid
                                // re-toggle) that would otherwise produce a
                                // negative width and fail Flutter's
                                // BoxConstraints assertion.
                                final double width = (right - left).clamp(
                                  1.0,
                                  double.infinity,
                                );
                                // Roughly area-preserving: as the thumb
                                // stretches wider it also reads as thinner,
                                // like a droplet being pulled thin. Floored
                                // at [_thumbMinHeight] so it never gets
                                // absurdly thin, and capped at [_thumbSize]
                                // so a spring overshoot that briefly
                                // narrows the gap below resting never
                                // renders the thumb *taller* than resting.
                                final double height =
                                    (_thumbSize * _thumbSize / width).clamp(
                                      _thumbMinHeight,
                                      _thumbSize,
                                    );

                                return Container(
                                  width: _trackWidth,
                                  height: _trackHeight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _thumbInset,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: trackColor,
                                    shape: RoundedSuperellipseBorder(
                                      borderRadius: BorderRadius.circular(
                                        _trackHeight / 2,
                                      ),
                                    ),
                                  ),
                                  // Explicit left/top/width/height
                                  // positioning is required here: an
                                  // Align-based edge-pinning approach only
                                  // stays correct at the exact -1/+1
                                  // alignment extremes and cannot express
                                  // two independently-animated edges at
                                  // once. The Stack sizes itself to the
                                  // Container's tight, padding-deflated
                                  // inner content box (_innerWidth x
                                  // _trackHeight), and Positioned places the
                                  // thumb by its actual
                                  // left/top/width/height every frame.
                                  child: Stack(
                                    children: <Widget>[
                                      Positioned(
                                        left: left,
                                        top: (_trackHeight - height) / 2,
                                        width: width,
                                        height: height,
                                        child: Container(
                                          decoration: ShapeDecoration(
                                            color: colors.surface,
                                            shape: RoundedSuperellipseBorder(
                                              // A constant, comfortably
                                              // oversized radius (equal to
                                              // resting [_thumbSize], well
                                              // over half of any
                                              // width/height this thumb ever
                                              // takes) always yields a true
                                              // stadium/pill regardless of
                                              // the live width/height -- the
                                              // same oversized-radius trick
                                              // [CruxRadii.pill] uses
                                              // elsewhere in the package to
                                              // force a pill shape without
                                              // conditional math.
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    _thumbSize,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        );
                      },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves the track's fill color: [CruxColors.accent] when on,
/// [CruxColors.separator] when off, both only while enabled. When
/// disabled, the on-track instead uses [CruxColors.muted] so a
/// disabled-and-on switch still visibly differs from a disabled-and-off one
/// instead of collapsing both into the same gray. The off-track keeps
/// [CruxColors.separator] regardless of [enabled]: it is already a faint
/// neutral hairline color, so disabling it needs no further desaturation.
Color _resolveTrackColor({
  required CruxColors colors,
  required bool value,
  required bool enabled,
}) {
  if (!value) {
    return colors.separator;
  }
  return enabled ? colors.accent : colors.muted;
}
