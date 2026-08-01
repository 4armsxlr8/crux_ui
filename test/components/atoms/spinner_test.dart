// Behavior tests for CruxSpinner, Crux UI's "rain" loading indicator
// (plans/atoms-batch-2.md). CruxSpinner animates continuously for as long
// as it is on screen, so every test here samples at fixed pumped durations
// -- never tester.pumpAndSettle(), which would time out waiting for an
// animation that never stops. See test/tokens/motion_test.dart for the same
// convention applied to the underlying CruxMotion.repeat API this widget
// is built on.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxSpinner needs to lay out
/// and paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light] (same convention as
/// button_test.dart / switch_test.dart).
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// Finds every dot [DecoratedBox] CruxSpinner paints -- the rain's three
/// falling circles. Distinguished from any other [DecoratedBox] in the tree
/// by [BoxDecoration.shape]: CruxSpinner is the only widget under test
/// here painting a [BoxShape.circle].
List<DecoratedBox> _dots(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .where(
        (DecoratedBox box) =>
            (box.decoration as BoxDecoration).shape == BoxShape.circle,
      )
      .toList();
}

Color _dotColor(DecoratedBox dot) => (dot.decoration as BoxDecoration).color!;

void main() {
  group('size', () {
    // Wrapped in Center: _wrap's bare Directionality hands down the test
    // surface's own tight constraints, which would force CruxSpinner's
    // inner SizedBox to the surface's size regardless of its intended
    // width/height (BoxConstraints.enforce can only shrink within the
    // *incoming* range, and a tight incoming range has no room to shrink).
    // Center supplies a loose constraint instead, the same convention
    // switch_test.dart's "tap target" group and button_test.dart's "sizing
    // (hug content)" group use to observe a widget's own intrinsic size.
    testWidgets('renders a 16x16 box for CruxSpinnerSize.small', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Center(child: CruxSpinner(size: CruxSpinnerSize.small)),
        ),
      );

      expect(tester.getSize(find.byType(CruxSpinner)), const Size(16, 16));
    });

    testWidgets('renders a 24x24 box for the default medium size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const Center(child: CruxSpinner())));

      expect(tester.getSize(find.byType(CruxSpinner)), const Size(24, 24));
    });

    testWidgets('renders a 36x36 box for CruxSpinnerSize.large', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Center(child: CruxSpinner(size: CruxSpinnerSize.large)),
        ),
      );

      expect(tester.getSize(find.byType(CruxSpinner)), const Size(36, 36));
    });
  });

  group('color resolution', () {
    testWidgets('defaults to the theme accent color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CruxSpinner()));

      final List<DecoratedBox> dots = _dots(tester);
      expect(dots, isNotEmpty);
      for (final DecoratedBox dot in dots) {
        expect(_dotColor(dot), CruxColors.light.accent);
      }
    });

    testWidgets('renders the explicit color when one is passed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxSpinner(color: CruxColors.light.onAccent)),
      );

      final List<DecoratedBox> dots = _dots(tester);
      expect(dots, isNotEmpty);
      for (final DecoratedBox dot in dots) {
        expect(_dotColor(dot), CruxColors.light.onAccent);
      }
    });
  });

  group('theme fallback', () {
    testWidgets('falls back to CruxThemeData.light with no ancestor theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CruxSpinner()));

      final List<DecoratedBox> dots = _dots(tester);
      for (final DecoratedBox dot in dots) {
        expect(_dotColor(dot), CruxColors.light.accent);
      }
    });

    testWidgets('resolves the dark accent under a dark CruxTheme ancestor', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxTheme(
            data: CruxThemeData.dark(),
            child: const CruxSpinner(),
          ),
        ),
      );

      final List<DecoratedBox> dots = _dots(tester);
      for (final DecoratedBox dot in dots) {
        expect(_dotColor(dot), CruxColors.dark.accent);
      }
    });
  });

  group('animation', () {
    testWidgets(
      'keeps animating: the rendered dot positions differ between two '
      'fixed pumped moments',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxSpinner()));

        // Zero-duration pump first lets the pending initState-scheduled
        // ticker actually start (same reasoning as motion_test.dart).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final List<Offset> firstPositions = tester
            .widgetList<Positioned>(
              find.descendant(
                of: find.byType(CruxSpinner),
                matching: find.byType(Positioned),
              ),
            )
            .map((Positioned p) => Offset(p.left ?? 0, p.top ?? 0))
            .toList();

        await tester.pump(const Duration(milliseconds: 300));
        final List<Offset> secondPositions = tester
            .widgetList<Positioned>(
              find.descendant(
                of: find.byType(CruxSpinner),
                matching: find.byType(Positioned),
              ),
            )
            .map((Positioned p) => Offset(p.left ?? 0, p.top ?? 0))
            .toList();

        expect(firstPositions, isNotEmpty);
        expect(secondPositions, isNotEmpty);
        expect(secondPositions, isNot(equals(firstPositions)));
      },
    );

    testWidgets(
      'each dot fades in at the top of its lap, sits at full opacity in '
      'the middle, and fades out at the bottom',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxSpinner()));

        // Zero-duration pump first, per the same reasoning as the previous
        // test.
        await tester.pump();

        // Sample in small steps across more than one full lap (60 * 40ms =
        // 2400ms, versus the widget's 1800ms period) instead of asserting
        // an exact opacity at an exact pumped time -- the same "don't
        // couple to motor's internal per-frame timing" convention
        // motion_test.dart's loop test uses.
        final List<double> opacities = <double>[];
        for (int i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          opacities.addAll(
            tester
                .widgetList<Opacity>(
                  find.descendant(
                    of: find.byType(CruxSpinner),
                    matching: find.byType(Opacity),
                  ),
                )
                .map((Opacity o) => o.opacity),
          );
        }

        expect(opacities, isNotEmpty);
        expect(opacities, everyElement(inInclusiveRange(0.0, 1.0)));

        // Reaches (close to) full opacity somewhere in the middle of a lap
        // -- the plateau between the fade-in and fade-out windows. A dot
        // stuck fading forever, or one whose opacity never climbs past a
        // dim value, would fail this.
        expect(opacities, anyElement(greaterThan(0.99)));

        // Passes through a genuinely partial opacity -- strictly between
        // invisible and fully visible -- at some sampled moment, the fade
        // windows themselves rather than an instantaneous on/off flip. A
        // dot whose opacity were hard-coded to a constant (for example
        // always 1.0) would fail this.
        expect(opacities, anyElement(allOf(greaterThan(0.0), lessThan(1.0))));

        // Fades all the way down close to invisible near the edge of the
        // lap, confirming the fade windows actually reach toward zero
        // rather than bottoming out at some partial floor.
        expect(opacities, anyElement(lessThan(0.05)));
      },
    );
  });

  group('semanticsLabel', () {
    testWidgets('exposes no semantics label when none is passed', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const CruxSpinner()));

      expect(
        find.bySemanticsLabel(RegExp('.+')),
        findsNothing,
        reason:
            'CruxSpinner is a decorative-by-default widget (KB "既定は '
            'semantics に何も出さない装飾扱い"); hosts such as CruxButton '
            'supply their own accessible name and must not get a second, '
            'unwanted label from the spinner itself.',
      );

      handle.dispose();
    });

    testWidgets('exposes exactly one semantics node with the given label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const CruxSpinner(semanticsLabel: 'Loading')),
      );

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);

      handle.dispose();
    });
  });

  group('columns', () {
    testWidgets('renders exactly three falling dots, one per rain column', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CruxSpinner()));
      await tester.pump();

      expect(_dots(tester), hasLength(3));
    });

    testWidgets(
      'the three columns sit at three distinct horizontal positions',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxSpinner()));
        await tester.pump();

        final List<double> lefts = tester
            .widgetList<Positioned>(
              find.descendant(
                of: find.byType(CruxSpinner),
                matching: find.byType(Positioned),
              ),
            )
            .map((Positioned p) => p.left!)
            .toList();

        expect(lefts, hasLength(3));
        // Three columns painted at only one or two distinct x positions
        // would mean a column went missing or two collapsed onto each
        // other, even though the dot count alone (the previous test) could
        // still read as 3.
        expect(lefts.toSet(), hasLength(3));
      },
    );

    testWidgets(
      'the three columns are offset in phase: they never all sit at the '
      'same vertical position at once',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxSpinner()));

        // Zero-duration pump first, per the same reasoning as the
        // 'animation' group above.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final List<double> tops = tester
            .widgetList<Positioned>(
              find.descendant(
                of: find.byType(CruxSpinner),
                matching: find.byType(Positioned),
              ),
            )
            .map((Positioned p) => p.top!)
            .toList();

        expect(tops, hasLength(3));
        // Every column is a third of a lap ahead of the next one (KB "列位
        // 相 1/3 周期ずらし", spinner.dart's _buildDot phaseOffset comment):
        // whatever the current lap progress is, the three columns' own
        // positions within their lap differ from each other by exactly 1/3
        // or 2/3, never 0, so their vertical screen positions can never
        // coincide at a single sampled moment. If the columns ever fell in
        // lockstep instead, this set would collapse to a single repeated
        // value regardless of when the sample was taken.
        expect(tops.toSet(), hasLength(3));
      },
    );
  });
}
