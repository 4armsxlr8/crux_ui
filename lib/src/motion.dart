import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart' as motor;

/// Motion tokens for Crux UI: the press feedback used by pressable atoms
/// such as `CruxButton`.
///
/// This wraps the `motor` package: `motor`'s types never appear in this
/// class's public API, so swapping the underlying animation engine later
/// stays a non-breaking change for Crux UI's consumers, the same
/// guarantee [CruxColors] gives for color values.
class CruxMotion {
  const CruxMotion._();

  /// The scale a pressable element animates to while pressed: 1.0 at rest,
  /// [pressedScale] while held down.
  static const double pressedScale = 0.96;

  /// A subtler press scale for large-surface pressables (e.g. `CruxCard`),
  /// where [pressedScale]'s 4% shrink would read as an exaggerated wobble
  /// once applied across a whole card rather than a compact pill. 2% keeps
  /// the same "the surface is responding to touch" cue without it.
  static const double pressedScaleSubtle = 0.98;

  /// The spring used to interpolate every value [CruxMotion] animates:
  /// press/release scale changes ([scale]) and any other single [double]
  /// value an atom needs to spring toward a target ([animatedValue], for
  /// example [CruxSwitch]'s thumb position).
  ///
  /// `CupertinoMotion`'s own default constructor is a critically-damped
  /// spring with zero bounce ("standard iOS spring motion behavior"), which
  /// would not satisfy the "releases with a slight bounce" behavior recorded
  /// in KB6/plan.md. `CupertinoMotion.snappy()` is motor's preset for "a
  /// small amount of bounce", so it is used here instead — see
  /// implementation-notes.md's Deviations section for the full reasoning.
  ///
  /// `CupertinoMotion.snappy()`'s own default duration is 500ms (confirmed
  /// against motor 1.1.0's source, `CupertinoMotion.snappy`'s `duration`
  /// parameter default), which reads as sluggish for a press/toggle
  /// response: user feedback on the initial tuning was that button/chip/card
  /// press feedback and the switch thumb both felt slow to respond.
  /// `duration` is shortened to 200ms here (500ms → 250ms → 200ms, tuned
  /// live against the running example — see implementation-notes.md's
  /// "Motion tuning (2026-07-25)" entry) — while `bounce` is left at
  /// `snappy()`'s default 0.15 (via its `extraBounce: 0` default, left
  /// unspecified below) so the KB6 "releases with a slight bounce" behavior
  /// is unchanged: only the spring's speed changed, not its bounciness.
  static const motor.Motion _spring = motor.CupertinoMotion.snappy(
    duration: Duration(milliseconds: 200),
  );

  /// A slower sibling of [_spring], for atoms that need two independently
  /// animated values to visibly move at different paces within the same
  /// gesture rather than in lockstep.
  ///
  /// Introduced for [CruxSwitch]'s "liquid travel" thumb (agreed
  /// 2026-07-25, see implementation-notes.md's "Switch liquid travel"
  /// section): the thumb's leading edge (the edge nearer the destination
  /// side) is driven by [_spring] as normal, while its trailing edge (the
  /// edge nearer the side it's leaving) is driven by [_slowSpring], so the
  /// leading edge arrives first and the trailing edge catches up afterward
  /// -- ballooning the gap between them (the thumb's rendered width) during
  /// the flight and collapsing it back to resting once both edges settle.
  ///
  /// Same `CupertinoMotion.snappy` family and the same 0.15 bounce as
  /// [_spring] (`extraBounce` is left at its default 0 here too), so the two
  /// edges read as the same spring "material" moving at two different
  /// speeds rather than two different feels -- only `duration` differs.
  /// 350ms is 1.75x of [_spring]'s 200ms, comfortably inside the
  /// "roughly 1.5x-2x" range agreed for this feature: a round number picked
  /// within that range rather than tuned live against the running example
  /// the way [_spring]'s 200ms was (see implementation-notes.md's "Motion
  /// tuning" entry for that live-tuning process); revisit if the liquid
  /// travel effect ever gets its own live tuning pass.
  static const motor.Motion _slowSpring = motor.CupertinoMotion.snappy(
    duration: Duration(milliseconds: 350),
  );

  /// Builds [child] wrapped in a scale animation that springs toward
  /// [value] whenever it changes, using Crux's shared spring.
  ///
  /// This is how [CruxMotion] applies its spring without ever exposing a
  /// `motor` type: callers pass and receive only plain Flutter types
  /// ([double], [Widget]).
  static Widget scale({required double value, required Widget child}) {
    return motor.SingleMotionBuilder(
      motion: _spring,
      value: value,
      builder: (BuildContext context, double animatedValue, Widget? child) {
        return Transform.scale(scale: animatedValue, child: child);
      },
      child: child,
    );
  }

  /// Builds a widget that springs an arbitrary [double] toward [value]
  /// whenever it changes, using the same shared spring [scale] uses, for
  /// atoms that animate something other than a scale transform (for example
  /// [CruxSwitch]'s thumb sliding between its off/on [Alignment]s).
  ///
  /// [builder] is called on every animation frame with the
  /// currently-animated value; [child] is an optional subtree that does not
  /// itself depend on the animated value and is rebuilt only when it
  /// changes, the same `child` optimization [AnimatedBuilder] offers.
  ///
  /// Pass `slow: true` to drive this value with [_slowSpring] (the same
  /// spring family, just a longer duration) instead of the default
  /// [_spring] -- for an atom that needs a second, independently-animated
  /// value to visibly lag behind a first one within the same gesture (for
  /// example [CruxSwitch]'s thumb, whose leading and trailing edges use
  /// this on the same widget across different builds depending on travel
  /// direction). This is safe to change from one build to the next even
  /// while a value is mid-flight: [SingleMotionBuilder] applies a changed
  /// `motion` before a changed `value` on the same rebuild, and changing the
  /// underlying `motor` controller's motion while a simulation is in flight
  /// restarts it from the current position and velocity toward the same
  /// current target, never jumping (confirmed against `motor` 1.1.0's
  /// source, `base_motion_builder.dart`'s `didUpdateWidget` and
  /// `motion_controller.dart`'s `_redirectSimulation`).
  ///
  /// Like [scale], this is the single choke point atoms route a spring
  /// through so the underlying animation engine can change later without
  /// breaking Crux UI's public API: [builder] and [child] are both plain
  /// Flutter types, never a `motor` type.
  static Widget animatedValue({
    required double value,
    required Widget Function(BuildContext context, double value, Widget? child)
    builder,
    Widget? child,
    bool slow = false,
  }) {
    return motor.SingleMotionBuilder(
      motion: slow ? _slowSpring : _spring,
      value: value,
      builder: builder,
      child: child,
    );
  }
}
