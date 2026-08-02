// Behavior tests for CruxMotion.playOnce, the generic one-shot primitive
// added alongside CruxSegmentedControl's "kira" sheen (plans/atoms-batch-3.md).
// Unlike shake (motion_test.dart has no dedicated file for it -- it is
// exercised via text_form_field_test.dart instead), this is tested directly
// at the token level per its own file, since it has no baked-in formula: it
// only hands a caller raw 0->1 progress.
//
// Because every case here drives a fixed-duration one-shot rather than a
// settling spring, tests sample with tester.pump() at fixed steps -- never
// pumpAndSettle(), which would time out on a controller motor considers
// "not animating" between triggers but that this file still wants to poke
// forward in time to prove nothing moves.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry needed to lay out and paint (a
/// [Directionality]), matching the convention in motion_test.dart.
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

void main() {
  group('CruxMotion.playOnce', () {
    testWidgets('plays nothing while trigger stays unchanged', (
      WidgetTester tester,
    ) async {
      final List<double> samples = <double>[];

      Widget build(int trigger) {
        return _wrap(
          CruxMotion.playOnce(
            trigger: trigger,
            duration: const Duration(milliseconds: 200),
            builder: (BuildContext context, double progress, Widget? child) {
              samples.add(progress);
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pumpWidget(build(0));
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(samples, everyElement(0.0));
    });

    testWidgets(
      'plays a 0 -> 1 progress ramp once trigger increments, reaching '
      'exactly 1.0 once duration has fully elapsed',
      (WidgetTester tester) async {
        int trigger = 0;
        double lastProgress = 0;

        Widget build() {
          return _wrap(
            CruxMotion.playOnce(
              trigger: trigger,
              duration: const Duration(milliseconds: 200),
              builder: (BuildContext context, double progress, Widget? child) {
                lastProgress = progress;
                return const SizedBox.shrink();
              },
            ),
          );
        }

        await tester.pumpWidget(build());
        await tester.pump();
        expect(lastProgress, 0.0);

        trigger = 1;
        await tester.pumpWidget(build());
        await tester.pump();
        expect(lastProgress, 0.0);

        await tester.pump(const Duration(milliseconds: 100));
        expect(lastProgress, greaterThan(0.0));
        expect(lastProgress, lessThan(1.0));

        await tester.pump(const Duration(milliseconds: 150));
        expect(lastProgress, 1.0);

        // Stays pinned at exactly 1.0 well after duration has elapsed,
        // rather than drifting.
        await tester.pump(const Duration(milliseconds: 500));
        expect(lastProgress, 1.0);
      },
    );

    testWidgets(
      'a retrigger before the previous shot settles stays bounded, throws '
      'no exception, and still reaches exactly 1.0 once the new shot\'s own '
      'duration elapses (the same "rare and harmless" tolerance shake '
      'documents for the identical scenario -- see playOnce\'s own doc)',
      (WidgetTester tester) async {
        int trigger = 0;
        final List<double> samples = <double>[];

        Widget build() {
          return _wrap(
            CruxMotion.playOnce(
              trigger: trigger,
              duration: const Duration(milliseconds: 200),
              builder: (BuildContext context, double progress, Widget? child) {
                samples.add(progress);
                return const SizedBox.shrink();
              },
            ),
          );
        }

        await tester.pumpWidget(build());
        trigger = 1;
        await tester.pumpWidget(build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(samples.last, greaterThan(0.0));

        // Retrigger mid-flight, well before the first shot's 200ms duration
        // has elapsed.
        trigger = 2;
        await tester.pumpWidget(build());
        for (int i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(tester.takeException(), isNull);
        expect(samples, everyElement(inInclusiveRange(0.0, 1.0)));
        expect(samples.last, 1.0);
      },
    );

    testWidgets(
      'an unrelated rebuild mid-flight (trigger unchanged) does not reset '
      'or stall the ramp',
      (WidgetTester tester) async {
        // Regression coverage for a real bug caught during implementation:
        // building a fresh Motion.curved(duration) instance on every call
        // (rather than caching one for the lifetime of a given duration)
        // would compare unequal to the previous build's instance on every
        // rebuild, redirecting -- and therefore restarting -- the
        // in-flight simulation even when nothing about trigger/duration
        // actually changed, which would prevent progress from ever
        // reaching 1.0 under repeated rebuilds.
        int trigger = 0;
        double lastProgress = 0;
        int unrelated = 0;

        Widget build() {
          return _wrap(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('unrelated: $unrelated'),
                CruxMotion.playOnce(
                  trigger: trigger,
                  duration: const Duration(milliseconds: 200),
                  builder:
                      (BuildContext context, double progress, Widget? child) {
                        lastProgress = progress;
                        return const SizedBox.shrink();
                      },
                ),
              ],
            ),
          );
        }

        await tester.pumpWidget(build());
        trigger = 1;
        await tester.pumpWidget(build());
        await tester.pump();

        // Advance in small steps, forcing an unrelated rebuild (a new
        // widget instance, same trigger/duration) between every step.
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          unrelated++;
          await tester.pumpWidget(build());
        }

        expect(
          lastProgress,
          1.0,
          reason:
              'progress should still reach the exact end value even when '
              'unrelated rebuilds happen throughout the ramp',
        );
      },
    );

    testWidgets(
      'a trigger jump of more than 1 in a single change still takes the '
      'full duration to reach 1.0, not a fraction of it (insurance against '
      'a caller violating the "increment by exactly 1" contract documented '
      'on playOnce)',
      (WidgetTester tester) async {
        int trigger = 0;
        double lastProgress = 0;

        Widget build() {
          return _wrap(
            CruxMotion.playOnce(
              trigger: trigger,
              duration: const Duration(milliseconds: 200),
              builder: (BuildContext context, double progress, Widget? child) {
                lastProgress = progress;
                return const SizedBox.shrink();
              },
            ),
          );
        }

        await tester.pumpWidget(build());
        await tester.pump();
        expect(lastProgress, 0.0);

        // A caller-side jump of +5 in a single change violates playOnce's
        // "increment by exactly 1" contract -- duration must still be
        // honored end-to-end rather than reaching 1.0 in a fraction of it.
        trigger = 5;
        await tester.pumpWidget(build());
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 100));
        expect(
          lastProgress,
          lessThan(1.0),
          reason:
              'halfway through duration, progress should not have already '
              'finished just because trigger jumped by more than 1',
        );

        await tester.pump(const Duration(milliseconds: 150));
        expect(lastProgress, 1.0);
      },
    );

    testWidgets(
      'reduceMotion suppresses the ramp entirely, calling builder once with '
      'progress already at its settled end value',
      (WidgetTester tester) async {
        final List<double> samples = <double>[];
        int trigger = 0;

        Widget build() {
          return _wrap(
            CruxMotion.playOnce(
              trigger: trigger,
              duration: const Duration(milliseconds: 200),
              reduceMotion: true,
              builder: (BuildContext context, double progress, Widget? child) {
                samples.add(progress);
                return const SizedBox.shrink();
              },
            ),
          );
        }

        await tester.pumpWidget(build());
        trigger = 1;
        await tester.pumpWidget(build());
        await tester.pump(const Duration(milliseconds: 300));

        expect(samples, everyElement(1.0));
      },
    );

    test('asserts that duration is positive', () {
      expect(
        () => CruxMotion.playOnce(
          trigger: 0,
          duration: Duration.zero,
          builder: (BuildContext context, double progress, Widget? child) {
            return const SizedBox.shrink();
          },
        ),
        throwsAssertionError,
      );
    });
  });
}
