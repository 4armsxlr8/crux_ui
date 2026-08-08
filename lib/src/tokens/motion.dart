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
  /// `CupertinoMotion.snappy()` at its default 0.15 bounce gives the
  /// "releases with a slight bounce" feel this package wants; its own
  /// default 500ms duration reads as sluggish for a press/toggle response,
  /// so `duration` is shortened to 200ms here while `bounce` is left at the
  /// default -- only the spring's speed changes, not its bounciness.
  static const motor.Motion _spring = motor.CupertinoMotion.snappy(
    duration: Duration(milliseconds: 200),
  );

  /// A slower sibling of [_spring], for atoms that need two independently
  /// animated values to visibly move at different paces within the same
  /// gesture rather than in lockstep.
  ///
  /// Drives [CruxSwitch]'s "liquid travel" thumb: the leading edge (nearer
  /// the destination) is driven by [_spring] as normal, while the trailing
  /// edge (nearer the side it's leaving) is driven by [_slowSpring], so the
  /// leading edge arrives first and the trailing edge catches up afterward
  /// -- ballooning the gap between them (the thumb's rendered width) during
  /// the flight and collapsing it back to resting once both edges settle.
  ///
  /// Same `CupertinoMotion.snappy` family and bounce as [_spring], so the
  /// two edges read as the same spring "material" moving at two different
  /// speeds rather than two different feels -- only `duration` differs.
  static const motor.Motion _slowSpring = motor.CupertinoMotion.snappy(
    duration: Duration(milliseconds: 350),
  );

  /// A bouncier sibling of [_spring] for the checkbox checkmark's pop-in.
  /// `extraBounce: 0.33` (total bounce 0.48) yields ~15% overshoot, matching
  /// the spec'd "scale 0 -> ~1.15 -> 1.0"; [_spring]'s own 0.15 bounce
  /// overshoots <1%, which reads as no bounce at all. Same 200ms duration as
  /// [_spring] so the pace matches every other press response.
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
  /// direction). Safe to change from one build to the next even mid-flight:
  /// changing the underlying motion redirects the simulation from its
  /// current position and velocity toward the same target, never jumping.
  ///
  /// Pass `playful: true` to drive this value with [_playfulSpring] instead
  /// -- reserved for [CruxCheckbox]'s checkmark, the one moment this
  /// package wants a pronounced overshoot. Mutually exclusive with `slow` in
  /// practice; if both are passed, `playful` wins.
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
  /// changes, using the same shared spring [scale] and [animatedValue] use,
  /// so a color change settles with the same timing and bounce as everything
  /// else this class animates rather than snapping instantly.
  ///
  /// Interpolates per-channel in RGB space (via `motor`'s
  /// [motor.ColorRgbMotionConverter]), carrying alpha through the same
  /// spring as the RGB channels -- relevant because this package's dark
  /// palette uses translucent tokens (`muted`, `separator`), so animating to
  /// or from one of those fades its opacity in step with its hue instead of
  /// snapping it. Because the interpolation is per-channel rather than
  /// perceptual, animating between two very different hues can pass through
  /// a slightly muddier intermediate color; acceptable for this package's
  /// short, small-swatch transitions.
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
  /// Untuned placeholder, as is [shakeAmplitude] -- revisit both on a device
  /// before release (unknowns/textfield-atom/ledger.md).
  static const Duration shakeDuration = Duration(milliseconds: 400);

  /// The peak horizontal displacement [shake] moves the shaken widget by, in
  /// logical pixels, at the strongest point of its decaying oscillation.
  static const double shakeAmplitude = 8;

  /// The number of full left-right oscillations [shake] completes over
  /// [shakeDuration].
  ///
  /// Deliberately an integer: the oscillation term below
  /// (`sin(_shakeCycles * 2 * pi * progress)`) is then mathematically zero
  /// at both `progress == 0` and `progress == 1`, matching a shake that
  /// both starts and ends at rest. [shake] still hard-clamps its output to
  /// exactly `0.0` once `progress >= 1.0` rather than trusting that
  /// mathematical zero to survive floating-point rounding.
  static const int _shakeCycles = 3;

  /// Shapes how quickly [shake]'s oscillation decays: applied as
  /// `exp(-_shakeDecayRate * progress)`, so a higher value front-loads more
  /// of the displacement into the first swing and tapers later swings
  /// faster, the way a real "wrong password" wobble reads (one clear kick,
  /// a couple of diminishing echoes) rather than a uniform back-and-forth.
  static const double _shakeDecayRate = 4.5;

  /// The motor motion driving [shake]'s internal 0->1 progress value: a
  /// fixed-duration linear curve (`Motion.curved`), not a spring. A spring's
  /// settle is asymptotic -- it approaches its target but is not guaranteed
  /// to reach it bit-exactly -- while `Motion.curved` returns its `end`
  /// value bit-exactly once [shakeDuration] elapses, which is what lets
  /// [shake] hard-clamp its own output to exactly `0.0` once progress
  /// reaches `1.0`.
  static const motor.Motion _shakeMotion = motor.Motion.curved(shakeDuration);

  /// Builds [child] wrapped in a horizontal shake -- a decaying left-right
  /// wobble, the familiar "wrong password" reaction to a validation error --
  /// that plays once each time [trigger] changes from whatever value it had
  /// on the previous build.
  ///
  /// Unlike [scale] and [animatedValue], which spring a value toward a
  /// persisted target and stay there, a shake is a one-shot effect that
  /// must be able to play again even when nothing about the *represented
  /// state* changed (for example, a repeated failed submit with an
  /// identical error message shakes again): the caller increments [trigger]
  /// by exactly 1 every time a new shake should play. An unchanged [trigger]
  /// across a rebuild plays no new shake.
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
        // increases by exactly 1 per shake, so `trigger - 1` is the value
        // this leg started from.
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

  /// Builds a widget that plays a `0.0 -> 1.0` progress value once, every
  /// time [trigger] changes from whatever value it had on the previous
  /// build, and hands that raw progress to [builder] -- for a one-shot
  /// paint effect (e.g. a diagonal sheen sweep) that doesn't reduce to a
  /// single formula the way [shake]'s horizontal offset does.
  ///
  /// **Contract**: [trigger] must be incremented by exactly 1 per new shot
  /// -- never skipped ahead by more, never decremented -- for [duration] to
  /// time that shot correctly end-to-end; a caller-side jump of more than 1
  /// would otherwise make the underlying curve cover a larger span of value
  /// in the same wall-clock [duration], finishing early. As insurance, this
  /// method also normalizes internally: its play count advances by exactly
  /// 1 per detected [trigger] change regardless of that change's own
  /// magnitude, and the normalized count -- not [trigger] itself -- drives
  /// the underlying motor value. This normalization is not a substitute for
  /// a caller correctly gating its own trigger to only the events meant for
  /// it, though. `progress` reads a steady `0.0` for as long as [trigger]
  /// has never changed, including on the widget's very first build.
  ///
  /// A retrigger before the previous shot settles redirects the underlying
  /// simulation without a value jump, but the *rescaled* `progress` this
  /// method reports can briefly read low (clamped toward `0.0`) rather than
  /// perfectly continuing from its pre-retrigger fraction. This is bounded
  /// (progress never leaves `[0.0, 1.0]`) and still reaches `1.0` once the
  /// new leg's [duration] elapses -- a rapid retrigger of the same one-shot
  /// is a rare interaction, and briefly compressing is an acceptable
  /// cosmetic trade-off.
  ///
  /// Drives progress with `Motion.curved(duration)`, not a spring, so
  /// [progress] reaches *exactly* `1.0` once [duration] elapses rather than
  /// merely settling near it. Unlike [_shakeMotion] (a `static const`
  /// because [shakeDuration] is fixed), [duration] here is caller-supplied,
  /// so one `Motion.curved` instance is cached per element for the lifetime
  /// of a given [duration] rather than rebuilt every rebuild -- a shot
  /// in flight is never redirected by an unrelated rebuild.
  ///
  /// Pass `reduceMotion: true` -- from [MediaQuery.disableAnimationsOf] --
  /// to suppress the effect entirely: no motor widget is built at all, and
  /// [builder] is called exactly once with `progress` pinned at `1.0` (the
  /// one-shot's settled end state).
  ///
  /// [duration] must be positive (`duration > Duration.zero`), matching
  /// [repeat]'s own `period` contract: enforced with a debug-only `assert`.
  static Widget playOnce({
    required int trigger,
    required Duration duration,
    required Widget Function(
      BuildContext context,
      double progress,
      Widget? child,
    )
    builder,
    Widget? child,
    bool reduceMotion = false,
  }) {
    assert(
      duration > Duration.zero,
      'CruxMotion.playOnce: duration must be positive.',
    );
    if (reduceMotion) {
      return Builder(
        builder: (BuildContext context) => builder(context, 1.0, child),
      );
    }
    return _PlayOnce(
      trigger: trigger,
      duration: duration,
      builder: builder,
      child: child,
    );
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
  /// [motor.LinearMotion] and set to [motor.LoopMode.seamless]: once the
  /// `1.0` phase finishes, `LoopMode.seamless` jumps back to `0.0` with no
  /// animation and immediately starts animating toward `1.0` again, so the
  /// rendered value is an uninterrupted linear sawtooth rather than a value
  /// that visibly reverses or pauses at the seam. `LoopMode.loop` is
  /// deliberately not used: for a two-phase sequence it would play the
  /// simulation backwards before going forward again, reading as a
  /// back-and-forth wobble rather than a one-directional repeating ramp.
  ///
  /// [child] is an optional subtree that does not itself depend on the
  /// animated progress and is rebuilt only when it changes, the same
  /// `child` optimization [animatedValue] and [scale] offer.
  ///
  /// [period] must be positive (`period > Duration.zero`): a zero or
  /// negative duration would not produce the `0.0 -> 1.0` ramp this method
  /// promises, so [builder] would only ever be called with the loop's
  /// endpoints and never see the ramp in between. Enforced with a
  /// debug-only `assert` rather than silently clamping.
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

/// Backs [CruxMotion.playOnce] as a stateful widget so it can cache a
/// [motor.Motion] instance across rebuilds (see that method's doc).
class _PlayOnce extends StatefulWidget {
  const _PlayOnce({
    required this.trigger,
    required this.duration,
    required this.builder,
    this.child,
  });

  final int trigger;
  final Duration duration;
  final Widget Function(BuildContext context, double progress, Widget? child)
  builder;
  final Widget? child;

  @override
  State<_PlayOnce> createState() => _PlayOnceState();
}

class _PlayOnceState extends State<_PlayOnce> {
  late motor.Motion _motion = motor.Motion.curved(widget.duration);

  // Play count, normalized to advance by exactly 1 per detected
  // widget.trigger change regardless of that change's own magnitude (see
  // playOnce's contract doc). Drives the motor value in `build`, not
  // widget.trigger directly.
  int _normalizedTrigger = 0;

  // The _normalizedTrigger value `animatedValue` is currently relative to
  // (subtracting it should read 0.0 as "not started"). Both start at 0 and
  // _baselineTrigger only advances once a real trigger change is observed.
  int _baselineTrigger = 0;

  @override
  void didUpdateWidget(covariant _PlayOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _motion = motor.Motion.curved(widget.duration);
    }
    if (widget.trigger != oldWidget.trigger) {
      _baselineTrigger = _normalizedTrigger;
      _normalizedTrigger++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return motor.SingleMotionBuilder(
      motion: _motion,
      value: _normalizedTrigger.toDouble(),
      builder: (BuildContext context, double animatedValue, Widget? child) {
        final double progress = (animatedValue - _baselineTrigger).clamp(
          0.0,
          1.0,
        );
        return widget.builder(context, progress, child);
      },
      child: widget.child,
    );
  }
}
