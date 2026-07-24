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

  /// The spring used to interpolate press/release scale changes.
  ///
  /// `CupertinoMotion`'s own default constructor is a critically-damped
  /// spring with zero bounce ("standard iOS spring motion behavior"), which
  /// would not satisfy the "releases with a slight bounce" behavior recorded
  /// in KB6/plan.md. `CupertinoMotion.snappy()` is motor's preset for "a
  /// small amount of bounce", so it is used here instead — see
  /// implementation-notes.md's Deviations section for the full reasoning.
  static const motor.Motion _pressSpring = motor.CupertinoMotion.snappy();

  /// Builds [child] wrapped in a scale animation that springs toward
  /// [value] whenever it changes, using Crux's press spring.
  ///
  /// This is how [CruxMotion] applies its press spring without ever
  /// exposing a `motor` type: callers pass and receive only plain Flutter
  /// types ([double], [Widget]).
  static Widget scale({required double value, required Widget child}) {
    return motor.SingleMotionBuilder(
      motion: _pressSpring,
      value: value,
      builder: (BuildContext context, double animatedValue, Widget? child) {
        return Transform.scale(scale: animatedValue, child: child);
      },
      child: child,
    );
  }
}
