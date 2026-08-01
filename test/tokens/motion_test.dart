// Behavior tests for CruxMotion.repeat, the continuous-loop animation API
// added for CruxSpinner (plans/atoms-batch-2.md). This wraps motor's
// SequenceMotionBuilder + LoopMode.seamless (confirmed against motor 1.1.0's
// source: motion_controller.dart's playSequence/_handleSequencePhaseCompletion
// jumps back to the first phase without animation once the sequence's last
// phase completes, then immediately continues, producing an uninterrupted
// 0->1 ramp repeated forever).
//
// Because this drives a never-settling animation, every test here samples
// at fixed pumped durations -- never tester.pumpAndSettle(), which would
// time out waiting for an animation that never stops.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry needed to lay out and paint (a
/// [Directionality]), matching the convention in button_test.dart /
/// switch_test.dart.
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

void main() {
  group('CruxMotion.repeat', () {
    testWidgets(
      'advances the progress value forward as time passes, without ever '
      'settling',
      (WidgetTester tester) async {
        final List<double> samples = <double>[];
        await tester.pumpWidget(
          _wrap(
            CruxMotion.repeat(
              period: const Duration(milliseconds: 200),
              builder: (BuildContext context, double progress, Widget? child) {
                samples.add(progress);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // A zero-duration pump first lets the pending initState-scheduled
        // ticker actually start (its elapsed clock begins at 0 on that
        // frame); only *then* does advancing the clock below move it
        // forward from its start -- the same two-pump pattern
        // button_test.dart's "press animation" group uses for its spring.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final double first = samples.last;
        await tester.pump(const Duration(milliseconds: 40));
        final double second = samples.last;

        expect(second, greaterThan(first));
      },
    );

    testWidgets(
      'loops seamlessly back toward the start once a full period elapses, '
      'instead of stopping at 1.0',
      (WidgetTester tester) async {
        final List<double> samples = <double>[];
        await tester.pumpWidget(
          _wrap(
            CruxMotion.repeat(
              period: const Duration(milliseconds: 200),
              builder: (BuildContext context, double progress, Widget? child) {
                samples.add(progress);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Zero-duration pump first, per the same reasoning as the previous
        // test.
        await tester.pump();

        // Sample in small steps across several periods (50 * 20ms = 1000ms
        // = 5 laps of the 200ms period), rather than asserting an exact
        // value at an exact elapsed time: motor's SequenceMotionController
        // only actually advances a phase's simulation on the *next* tick
        // after the phase transition is detected (confirmed empirically --
        // there is a one-frame lag between a lap completing and the next
        // lap's ramp becoming visible), so asserting a precise value at a
        // precise pumped duration would be coupled to that internal timing
        // rather than to the behavior this API promises.
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        // Stays within a single lap's range the whole time: it never runs
        // away past 1.0.
        expect(samples, everyElement(inInclusiveRange(0.0, 1.0)));

        // It climbed close to the top of a lap...
        final int peakIndex = samples.indexWhere((double v) => v > 0.8);
        expect(peakIndex, greaterThanOrEqualTo(0));

        // ...and, after doing so, came back down close to the bottom again
        // -- the signature of a seamless loop, as opposed to a one-shot
        // animation that settles and stays pinned at 1.0 forever.
        final Iterable<double> afterPeak = samples.skip(peakIndex + 1);
        expect(afterPeak, anyElement(lessThan(0.2)));

        // A seamless sawtooth's *only* backward movement between adjacent
        // samples is the instantaneous same-frame reset from ~1.0 back to
        // ~0.0 at the seam -- everywhere else the value only ever advances.
        // `LoopMode.loop`'s reverse ping-pong, in contrast, would spend many
        // consecutive 20ms samples gradually descending from its peak back
        // toward 0 before climbing again, which shows up here as a run of
        // small negative step-to-step differences rather than a single
        // large one. Asserting that no *small* negative difference exists
        // -- only the one big jump-back -- is what a seamless one-directional
        // ramp guarantees and a ping-pong loop does not.
        final List<double> stepDiffs = <double>[
          for (int i = 1; i < samples.length; i++) samples[i] - samples[i - 1],
        ];
        final Iterable<double> smallBackslides = stepDiffs.where(
          (double d) => d < 0 && d > -0.5,
        );
        expect(
          smallBackslides,
          isEmpty,
          reason:
              'a seamless sawtooth should only ever move backward via one '
              'large same-frame reset at the seam, never a gradual '
              'step-by-step descent (which would indicate a reversing '
              'ping-pong loop instead)',
        );
      },
    );

    test('asserts that period is positive', () {
      expect(
        () => CruxMotion.repeat(
          period: Duration.zero,
          builder: (BuildContext context, double progress, Widget? child) {
            return const SizedBox.shrink();
          },
        ),
        throwsAssertionError,
      );
    });
  });

  group('CruxMotion.animatedValue playful', () {
    // Introduced alongside CruxCheckbox's checkmark overshoot fix (see
    // checkbox_test.dart's "checkmark overshoot" group): `playful: true`
    // must actually pick a bouncier spring than the default, not merely
    // exist as an unused parameter.
    testWidgets(
      'overshoots well past 1.0 when playful is true, springing 0 -> 1',
      (WidgetTester tester) async {
        double peak = 0.0;

        Widget build(double value) {
          return _wrap(
            CruxMotion.animatedValue(
              value: value,
              playful: true,
              builder: (BuildContext context, double animated, Widget? child) {
                if (animated > peak) {
                  peak = animated;
                }
                return const SizedBox.shrink();
              },
            ),
          );
        }

        await tester.pumpWidget(build(0.0));
        await tester.pumpWidget(build(1.0));
        await tester.pump();
        for (int i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }

        expect(peak, greaterThan(1.08));
      },
    );

    testWidgets(
      'overshoots far less than playful does when playful is left false, '
      'springing 0 -> 1',
      (WidgetTester tester) async {
        double peak = 0.0;

        Widget build(double value) {
          return _wrap(
            CruxMotion.animatedValue(
              value: value,
              builder: (BuildContext context, double animated, Widget? child) {
                if (animated > peak) {
                  peak = animated;
                }
                return const SizedBox.shrink();
              },
            ),
          );
        }

        await tester.pumpWidget(build(0.0));
        await tester.pumpWidget(build(1.0));
        await tester.pump();
        for (int i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }

        expect(peak, lessThan(1.02));
      },
    );
  });
}
