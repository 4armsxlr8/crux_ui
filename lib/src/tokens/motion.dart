import 'dart:math' as math;

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

  /// A bouncier sibling of [_spring], for the single moment this package
  /// deliberately wants to read as playful rather than restrained: the
  /// checkmark [CruxCheckbox] springs in with (see plans/atoms-batch-2.md
  /// -- "checkbox is a bounce/overshoot moment" -- and checkbox.dart's own
  /// class doc for the "scale 0 -> ~1.15 -> 1.0" spec this spring
  /// implements).
  ///
  /// `CupertinoMotion.snappy`'s `bounce` is `0.15 + extraBounce` (confirmed
  /// against motor 1.1.0's source, `motion.dart`'s
  /// `CupertinoMotion.snappy` constructor), and SwiftUI's own `bounce`
  /// parameter -- which `CupertinoMotion` mirrors -- is defined as `1 -
  /// dampingRatio`. A step response's overshoot fraction for a
  /// second-order underdamped system is `exp(-zeta * pi / sqrt(1 -
  /// zeta^2))` for damping ratio `zeta`. For [_spring]'s `bounce = 0.15`
  /// (`zeta = 0.85`), that formula evaluates to ~0.63% overshoot --
  /// imperceptible on screen, and too small to move [CruxCheckbox]'s box
  /// pulse (which is derived from this same overshoot) past a sub-pixel
  /// no-op; a review pass measured both directly (1ms-sampled peaks) and
  /// found [_spring] alone did not satisfy the checkbox's agreed spec (see
  /// `plans/atoms-batch-2/implementation-notes.md`'s review-follow-up entry
  /// for the measurement this constant's `extraBounce` was chosen to fix).
  /// `extraBounce: 0.33` raises the total bounce to `0.48` (`zeta = 0.52`),
  /// which the same formula puts at ~14.8% overshoot -- comfortably inside
  /// the "~1.15" the spec calls for, and confirmed against
  /// `checkbox_test.dart`'s own 1ms-sampled "checkmark overshoot" test.
  /// `duration` is left at [_spring]'s 200ms so the checkmark's overall
  /// pace still matches every other press/toggle response in this package;
  /// only the bounciness changes.
  static const motor.Motion _playfulSpring = motor.CupertinoMotion.snappy(
    duration: Duration(milliseconds: 200),
    extraBounce: 0.33,
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
  /// Pass `playful: true` to drive this value with [_playfulSpring] instead
  /// -- a much bouncier sibling of [_spring], reserved for the one moment
  /// this package wants a pronounced overshoot rather than a barely-there
  /// one (see [_playfulSpring]'s own doc for the math and
  /// [CruxCheckbox]'s checkmark, its only caller so far). Mutually
  /// exclusive with `slow` in practice -- no current atom needs both a
  /// longer duration and extra bounce at once -- but if both are passed,
  /// `playful` wins.
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
    bool playful = false,
  }) {
    return motor.SingleMotionBuilder(
      motion: playful ? _playfulSpring : (slow ? _slowSpring : _spring),
      value: value,
      builder: builder,
      child: child,
    );
  }

  /// Builds a widget that springs a [Color] toward [value] whenever it
  /// changes, using the same shared spring [scale] and [animatedValue] use.
  ///
  /// Introduced for `CruxInputBar`'s send button, whose fill color needs to
  /// change between its enabled and disabled tones: without this, an
  /// enabled/disabled toggle would snap the button's color instantly, which
  /// reads as a flicker next to the button's own spring-driven press feedback
  /// ([scale]). Routing the color through the same [_spring] makes the color
  /// change settle with the same timing and bounce as everything else this
  /// class animates, so it reads as the same "material" responding to state,
  /// not a separate, disconnected transition.
  ///
  /// Interpolates in RGB space via `motor`'s
  /// [motor.ColorRgbMotionConverter] -- confirmed against motor 1.1.0's
  /// source (`motion_converter.dart:126-145`): it normalizes a [Color] to its
  /// four straight (non-premultiplied) `r`/`g`/`b`/`a` components in a single
  /// four-element list and denormalizes by clamping each component back to
  /// `[0, 1]` and reconstructing via `Color.from`. All four channels,
  /// including alpha, are carried through the same spring simulation and
  /// interpolated together, so a color's alpha animates smoothly alongside
  /// its RGB rather than being dropped or held fixed -- relevant because this
  /// package's own dark palette uses translucent colors (`muted` and
  /// `separator` are `Color.fromRGBO(..., 0.45)`, per
  /// `lib/src/tokens/colors.dart`), so animating toward or away from one of
  /// those tokens fades its opacity in step with its hue rather than
  /// snapping the alpha channel.
  ///
  /// Because the interpolation is per-channel in RGB space rather than
  /// perceptual, animating between two hues that differ a lot (for example a
  /// saturated accent color to a desaturated gray) can pass through a
  /// slightly muddier intermediate color than a perceptual color space would
  /// produce; this is `motor`'s only built-in color converter, and is an
  /// acceptable trade-off for the short, small-swatch transitions this
  /// package uses this for (a button fill toggling between two closely
  /// related design tokens), not a longer decorative gradient animation.
  ///
  /// Like [scale] and [animatedValue], this is the single choke point atoms
  /// route a color spring through so the underlying animation engine can
  /// change later without breaking Crux UI's public API: [builder] and
  /// [child] are both plain Flutter types, never a `motor` type.
  static Widget animatedColor({
    required Color value,
    required Widget Function(BuildContext context, Color value, Widget? child)
    builder,
    Widget? child,
  }) {
    return motor.MotionBuilder<Color>(
      motion: _spring,
      converter: const motor.ColorRgbMotionConverter(),
      value: value,
      builder: builder,
      child: child,
    );
  }

  /// The total duration of the horizontal shake [shake] plays each time
  /// [shake]'s `trigger` changes -- see [shake]'s doc for what drives it.
  ///
  /// Un-tuned: a sensible starting point (long enough for [_shakeCycles]
  /// oscillations to read as a wobble rather than a single flick, short
  /// enough not to outstay the validation error it accompanies), not yet
  /// checked against a running app on a device the way [_spring]'s 200ms
  /// was (see this class's "Motion tuning" doc on [_spring]). Revisit on a
  /// device before release.
  static const Duration shakeDuration = Duration(milliseconds: 400);

  /// The peak horizontal displacement [shake] moves the shaken widget by, in
  /// logical pixels, at the strongest point of its decaying oscillation.
  /// Un-tuned -- see [shakeDuration]'s doc for what that means here.
  static const double shakeAmplitude = 8;

  /// The number of full left-right oscillations [shake] completes over
  /// [shakeDuration].
  ///
  /// Deliberately an integer: the oscillation term below
  /// (`sin(_shakeCycles * 2 * pi * progress)`) is then mathematically zero
  /// at both `progress == 0` and `progress == 1`, matching a shake that
  /// both starts and ends at rest. [shake] additionally hard-clamps its
  /// output to exactly `0.0` once `progress >= 1.0` rather than trusting
  /// that mathematical zero to survive floating-point rounding -- see
  /// [_shakeMotion]'s doc for why `progress` itself is guaranteed to reach
  /// exactly `1.0`.
  static const int _shakeCycles = 3;

  /// Shapes how quickly [shake]'s oscillation decays: applied as
  /// `exp(-_shakeDecayRate * progress)`, so a higher value front-loads more
  /// of the displacement into the first swing and tapers later swings
  /// faster, the way a real "wrong password" wobble reads (one clear kick,
  /// a couple of diminishing echoes) rather than a uniform back-and-forth.
  static const double _shakeDecayRate = 4.5;

  /// The motor motion driving [shake]'s internal 0->1 progress value: a
  /// fixed-duration linear curve (`Motion.curved`, motor's duration-based
  /// alternative to a spring -- see the library doc's "unified motion
  /// system" framing), not a spring.
  ///
  /// A shake is not a value settling toward a persisted target the way
  /// [_spring]/[_slowSpring] are used elsewhere in this class: it is a
  /// one-shot effect that must (a) be able to play again from a standing
  /// start on every trigger, even back-to-back with an unchanged target
  /// value (see [shake]'s doc), and (b) return to *exactly* zero
  /// displacement once it finishes, not merely settle near zero. A spring's
  /// settle is asymptotic -- it approaches its target but is not guaranteed
  /// to reach it bit-exactly (this is why this package's own existing
  /// spring-driven values are only ever asserted `closeTo` their resting
  /// value once settled, e.g. button_test.dart's press-animation test
  /// asserting `closeTo(1.0, 0.001)` after `pumpAndSettle()`, never a bare
  /// `1.0`) -- so a spring cannot back requirement (b). `Motion.curved`'s
  /// underlying `CurveSimulation`, in contrast, returns its `end` value
  /// bit-exactly once elapsed time passes [shakeDuration] (confirmed
  /// against motor 1.1.0's source, `simulations/curve_simulation.dart`'s
  /// `x`/`isDone`: `x(time)` short-circuits to `end` once `time` exceeds
  /// the duration, rather than asymptotically approaching it), which is
  /// what lets [shake] hard-clamp its own output to exactly `0.0` once
  /// progress reaches `1.0`.
  static const motor.Motion _shakeMotion = motor.Motion.curved(shakeDuration);

  /// Builds [child] wrapped in a horizontal shake -- a decaying left-right
  /// wobble, the familiar "wrong password" reaction to a validation error --
  /// that plays once each time [trigger] changes from whatever value it had
  /// on the previous build.
  ///
  /// Unlike [scale] and [animatedValue], which spring a value toward a
  /// persisted target and stay there, a shake is a one-shot effect that
  /// must be able to play again even when nothing about the *represented
  /// state* changed -- see `CruxTextFormField`'s "a repeated failed
  /// submit with an identical error message shakes again" requirement, the
  /// reason this takes a `trigger` count rather than, say, a `bool
  /// hasError`: the caller increments [trigger] by exactly 1 every time a
  /// new shake should play (an unchanged [trigger] across a rebuild plays
  /// no new shake, the same "reacts to changes, not levels" contract every
  /// other value passed to this class follows).
  ///
  /// Internally drives a 0->1 progress double via [_shakeMotion] (see its
  /// doc for why a duration-based curve is used instead of a spring here)
  /// and maps it through a fixed decaying sine
  /// (`shakeAmplitude * exp(-_shakeDecayRate * p) * sin(_shakeCycles * 2 *
  /// pi * p)`), then returns a hard `0.0` once progress reaches `1.0`
  /// instead of trusting that formula's own floating-point residual at the
  /// boundary to equal zero exactly.
  ///
  /// Pass `reduceMotion: true` -- from [MediaQuery.disableAnimationsOf],
  /// Flutter's binding for the OS "reduce motion" accessibility setting --
  /// to suppress the shake entirely: [child] is returned unwrapped, with no
  /// motor widget built at all and no offset ever applied, rather than
  /// merely playing a shortened or zero-amplitude version of it.
  static Widget shake({
    required int trigger,
    required Widget child,
    required bool reduceMotion,
  }) {
    if (reduceMotion) {
      return child;
    }
    return motor.SingleMotionBuilder(
      motion: _shakeMotion,
      value: trigger.toDouble(),
      builder: (BuildContext context, double animatedValue, Widget? child) {
        // How far into *this* shake leg the animation has traveled: trigger
        // increases by exactly 1 per shake (see the class doc above), so
        // `trigger - 1` is the value this leg started from whenever the
        // previous shake fully settled first (the common case) -- see
        // [shake]'s class doc for the rare-and-harmless exception (a
        // retrigger before the previous shake finishes).
        final double progress = (animatedValue - (trigger - 1)).clamp(0.0, 1.0);
        final double dx = progress >= 1.0 ? 0.0 : _shakeOffset(progress);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: child,
    );
  }

  /// The decaying-sine formula [shake] maps its 0->1 progress through --
  /// see [shake]'s doc.
  static double _shakeOffset(double progress) {
    return shakeAmplitude *
        math.exp(-_shakeDecayRate * progress) *
        math.sin(_shakeCycles * 2 * math.pi * progress);
  }

  /// Builds a widget that continuously loops a `0.0 -> 1.0` progress value
  /// at a constant (linear) rate, calling [builder] on every frame with the
  /// current progress -- introduced for [CruxSpinner]'s falling dots,
  /// which need an indefinitely-repeating "how far through this lap" value
  /// rather than a value that settles toward a persisted target the way
  /// [scale]/[animatedValue]/[animatedColor] do, or a value that plays once
  /// and stops the way [shake] does.
  ///
  /// [period] is the wall-clock duration of one full `0.0 -> 1.0` lap.
  /// Once a lap completes, this restarts from `0.0` and keeps going: unlike
  /// [shake], there is no `trigger` to replay and no way to stop it short of
  /// unmounting the returned widget -- for [CruxSpinner] that is correct,
  /// since it only exists on screen for as long as its caller is loading.
  ///
  /// Internally wraps `motor`'s [motor.SequenceMotionBuilder] over a
  /// two-phase [motor.MotionSequence.steps] (`[0.0, 1.0]`) driven by
  /// [motor.LinearMotion] and set to [motor.LoopMode.seamless]. This
  /// specific combination was chosen after reading `motor` 1.1.0's source
  /// (`controllers/motion_controller.dart`,
  /// `SequenceMotionController._handleSequencePhaseCompletion` and
  /// `_jumpToSequencePhase`): once the `1.0` phase's `LinearMotion`
  /// simulation finishes, `LoopMode.seamless` jumps back to the `0.0` phase
  /// with no animation (a same-frame value reset, not a reverse animation
  /// like `LoopMode.loop` would play) and then, via a post-frame callback,
  /// immediately starts animating toward `1.0` again -- so the rendered
  /// value is an uninterrupted linear sawtooth (`0.0 -> 1.0`, snap to
  /// `0.0`, `0.0 -> 1.0`, ...) rather than a value that visibly reverses or
  /// pauses at the seam. `LoopMode.loop` was deliberately not used here: for
  /// a two-phase sequence it would play the *same* `LinearMotion` simulation
  /// backwards from `1.0` to `0.0` before going forward again, which reads
  /// as a back-and-forth wobble, not a one-directional repeating ramp.
  ///
  /// The `P` (phase) type parameter `motor.SequenceMotionBuilder` needs is
  /// filled with `int` (the two step-sequence phase indices, `0` and `1`)
  /// and never appears in this method's own signature, so -- like every
  /// other method on this class -- callers only ever see plain Flutter
  /// types ([BuildContext], [double], [Widget]), never a `motor` type.
  ///
  /// [child] is an optional subtree that does not itself depend on the
  /// animated progress and is rebuilt only when it changes, the same
  /// `child` optimization [animatedValue] and [scale] offer.
  ///
  /// [period] must be positive (`period > Duration.zero`): it is passed
  /// straight through to [motor.LinearMotion] as the wall-clock duration of
  /// one lap, and a zero or negative duration would not produce the `0.0 ->
  /// 1.0` ramp this method promises -- a zero-duration `LinearMotion`
  /// simulation reports itself done on the very first tick (confirmed
  /// against motor 1.1.0's source, `simulations/linear_motion.dart`'s
  /// `isDone`, which is `elapsed >= duration` and therefore trivially true
  /// once `duration` is zero), so [builder] would only ever be called with
  /// the loop's endpoints and never see the ramp in between -- the caller
  /// sees a ticker spinning behind a value that looks stuck rather than an
  /// animation. This is enforced with an `assert` (debug-only, per this
  /// package's existing convention) rather than silently clamping, so a
  /// caller passing an invalid period finds out immediately rather than
  /// shipping a silently-broken spinner.
  static Widget repeat({
    required Duration period,
    required Widget Function(
      BuildContext context,
      double progress,
      Widget? child,
    )
    builder,
    Widget? child,
  }) {
    assert(
      period > Duration.zero,
      'CruxMotion.repeat: period must be positive.',
    );
    return motor.SequenceMotionBuilder<int, double>(
      sequence: motor.MotionSequence.steps<double>(
        const <double>[0.0, 1.0],
        motion: motor.LinearMotion(period),
        loop: motor.LoopMode.seamless,
      ),
      converter: const motor.SingleMotionConverter(),
      builder:
          (BuildContext context, double progress, int phase, Widget? child) {
            return builder(context, progress, child);
          },
      child: child,
    );
  }
}
