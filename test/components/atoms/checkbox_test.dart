// Behavior tests for CruxCheckbox, following the front-loaded pattern
// established by button_test.dart / switch_test.dart: semantics (checked
// trait, not toggled), the 44 minimum tap target, disabled-press safety, and
// the checkmark's spring-driven appear/disappear animation (sampled via
// pump(), never pumpAndSettle(), while it is still in flight).
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxCheckbox needs to lay out
/// and paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light] (same convention as
/// button_test.dart / switch_test.dart).
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// Finds the box [Container] inside a rendered [CruxCheckbox] -- the only
/// [Container] this widget builds.
Finder _boxFinder() {
  return find.byWidgetPredicate((Widget widget) {
    return widget is Container && widget.decoration != null;
  });
}

/// Finds the [Transform] that scales the checkmark specifically -- distinct
/// from the outer press-scale [Transform] CruxCheckbox also builds
/// (mirroring button_test.dart's "read the transform matrix directly"
/// convention). [find.ancestor] walks upward from the checkmark's
/// [CustomPaint] and returns ancestors nearest-first, so `.first` is the
/// checkmark's own immediately-wrapping [Transform], not the outer
/// press-scale one further up the tree.
Finder _checkmarkTransformFinder() {
  return find
      .ancestor(of: find.byType(CustomPaint), matching: find.byType(Transform))
      .first;
}

/// The fixed side length of the outer tap-target [SizedBox]
/// [_pressTransformFinder] anchors on -- mirrors checkbox.dart's private
/// `_minTapTarget` constant, which this test file cannot import since it is
/// not exported.
const double _tapTargetSize = 44;

/// Finds the outer press-scale [Transform] CruxCheckbox wraps its whole
/// tap target in -- distinct from the checkmark-only [Transform]
/// [_checkmarkTransformFinder] returns. [find.ancestor] walks upward from
/// the fixed-size [SizedBox] that sizes the 44x44 tap target (matched by its
/// [_tapTargetSize] width, since the checkmark's own inner [SizedBox] is a
/// different, smaller size and would otherwise be ambiguous) and returns
/// ancestors nearest-first, so `.first` is the press-scale [Transform] built
/// directly around it by `CruxMotion.scale` (the checkmark's own
/// [Transform] is a *descendant* of the tap-target [SizedBox], not an
/// ancestor, so it can never match here).
Finder _pressTransformFinder() {
  return find
      .ancestor(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is SizedBox && widget.width == _tapTargetSize,
        ),
        matching: find.byType(Transform),
      )
      .first;
}

/// Finds the box [Container]'s tight layout constraints -- used to sample
/// the box's animated side length ([_boxPulseAmplitude]'s effect) the same
/// way [_checkmarkTransformFinder] samples the checkmark's animated scale.
double _boxWidth(WidgetTester tester) {
  final Container box = tester.widget<Container>(_boxFinder());
  return box.constraints!.maxWidth;
}

/// The box's resting (unscaled) side length -- mirrors checkbox.dart's
/// private `_boxSize` constant, which this test file cannot import since it
/// is not exported.
const double _restingBoxSize = 22;

void main() {
  group('tap handling', () {
    testWidgets('notifies onChanged(true) exactly once when tapped unchecked', (
      WidgetTester tester,
    ) async {
      final List<bool> notifications = <bool>[];
      await tester.pumpWidget(
        _wrap(CruxCheckbox(checked: false, onChanged: notifications.add)),
      );

      await tester.tap(find.byType(CruxCheckbox));
      await tester.pump();

      expect(notifications, <bool>[true]);
    });

    testWidgets('notifies onChanged(false) exactly once when tapped checked', (
      WidgetTester tester,
    ) async {
      final List<bool> notifications = <bool>[];
      await tester.pumpWidget(
        _wrap(CruxCheckbox(checked: true, onChanged: notifications.add)),
      );

      await tester.tap(find.byType(CruxCheckbox));
      await tester.pump();

      expect(notifications, <bool>[false]);
    });
  });

  group('disabled', () {
    testWidgets(
      'does not invoke onChanged and stays tappable-safe when onChanged is '
      'null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxCheckbox(checked: false, onChanged: null)),
        );

        await tester.tap(find.byType(CruxCheckbox));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders a different box decoration for disabled-checked (muted fill) '
      'than for disabled-unchecked (no fill, bordered)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxCheckbox(checked: true, onChanged: null)),
        );
        final Container checkedBox = tester.widget<Container>(_boxFinder());
        final ShapeDecoration checkedDecoration =
            checkedBox.decoration! as ShapeDecoration;

        await tester.pumpWidget(
          _wrap(const CruxCheckbox(checked: false, onChanged: null)),
        );
        final Container uncheckedBox = tester.widget<Container>(_boxFinder());
        final ShapeDecoration uncheckedDecoration =
            uncheckedBox.decoration! as ShapeDecoration;

        expect(checkedDecoration.color, CruxColors.light.muted);
        expect(uncheckedDecoration.color, isNull);
        final RoundedSuperellipseBorder uncheckedShape =
            uncheckedDecoration.shape as RoundedSuperellipseBorder;
        expect(uncheckedShape.side, isNot(BorderSide.none));
        final RoundedSuperellipseBorder checkedShape =
            checkedDecoration.shape as RoundedSuperellipseBorder;
        expect(checkedShape.side, BorderSide.none);
      },
    );
  });

  group('tap target', () {
    testWidgets(
      'keeps a 44x44 minimum tap target and the whole area (not just the '
      'visible box) is tappable',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxCheckbox(checked: false, onChanged: (_) => calls++),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxCheckbox));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));

        final Offset topLeft = tester.getTopLeft(find.byType(CruxCheckbox));
        await tester.tapAt(topLeft + const Offset(2, 2));
        await tester.pump();

        expect(calls, 1);
      },
    );

    testWidgets(
      'stays exactly 44x44 -- not stretched to fill its parent -- under a '
      'loose, generously sized finite constraint (a Center inside a wide '
      'SizedBox), matching CruxIconButton\'s fixed-size tap target '
      "instead of growing with a ConstrainedBox's unbounded max",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Center(
                  child: CruxCheckbox(checked: false, onChanged: null),
                ),
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxCheckbox));
        expect(size.width, 44);
        expect(size.height, 44);
      },
    );
  });

  group('press animation', () {
    // Reads the horizontal scale factor directly off the outer press
    // Transform's matrix, the same technique button_test.dart /
    // icon_button_test.dart use and for the same reason (Transform.scale
    // always leaves the Z axis at 1.0).
    testWidgets(
      'scales down toward pressedScale while held and returns to 1.0 on '
      'release',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxCheckbox(checked: false, onChanged: (_) {})),
        );

        expect(
          tester
              .widget<Transform>(_pressTransformFinder())
              .transform
              .entry(0, 0),
          1.0,
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxCheckbox)),
        );
        // A zero-duration pump first lets the pending setState from
        // onTapDown actually rebuild and start the spring (matches
        // button_test.dart's/icon_button_test.dart's identical two-pump
        // sampling pattern).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          tester
              .widget<Transform>(_pressTransformFinder())
              .transform
              .entry(0, 0),
          lessThan(1.0),
        );

        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Transform>(_pressTransformFinder())
              .transform
              .entry(0, 0),
          closeTo(1.0, 0.001),
        );
      },
    );
  });

  group('minimum press feedback (fast tap)', () {
    // Reproduces the same fast-tap-in-a-scroll-view bug button_test.dart's
    // and icon_button_test.dart's identical groups guard against:
    // `tester.tap()` delivers down and up back-to-back with no frame
    // rendered in between, so a naive `_pressed = true` then `_pressed =
    // false` (no PressFeedbackController) collapses to a no-op before the
    // pressed state is ever painted -- see press_feedback.dart's class doc
    // for the bug this guards against.
    testWidgets(
      'stays visibly pressed for a minimum duration even when down and up '
      'are delivered back-to-back, then springs back to 1.0',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxCheckbox(checked: false, onChanged: (_) {})),
        );

        await tester.tap(find.byType(CruxCheckbox));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          tester
              .widget<Transform>(_pressTransformFinder())
              .transform
              .entry(0, 0),
          lessThan(0.995),
        );

        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Transform>(_pressTransformFinder())
              .transform
              .entry(0, 0),
          closeTo(1.0, 0.001),
        );
      },
    );
  });

  group('semantics', () {
    testWidgets(
      'exposes a checked-state semantics node (not a toggled one) that '
      'follows checked, and enabled follows onChanged',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(CruxCheckbox(checked: true, onChanged: (_) {})),
        );

        final SemanticsNode checkedNode = tester.getSemantics(
          find.byType(CruxCheckbox),
        );
        expect(checkedNode.flagsCollection.isChecked, CheckedState.isTrue);
        expect(checkedNode.flagsCollection.isToggled, Tristate.none);
        expect(checkedNode.flagsCollection.isEnabled, Tristate.isTrue);

        await tester.pumpWidget(
          _wrap(const CruxCheckbox(checked: false, onChanged: null)),
        );
        final SemanticsNode uncheckedNode = tester.getSemantics(
          find.byType(CruxCheckbox),
        );
        expect(uncheckedNode.flagsCollection.isChecked, CheckedState.isFalse);
        expect(uncheckedNode.flagsCollection.isToggled, Tristate.none);
        expect(uncheckedNode.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      },
    );
  });

  group('checkmark animation', () {
    testWidgets(
      'the checkmark scales up from 0 when checked flips from false to '
      'true, mid-flight sitting strictly between 0 and its settled scale',
      (WidgetTester tester) async {
        bool checked = false;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxCheckbox(
                  checked: checked,
                  onChanged: (bool next) => setState(() => checked = next),
                );
              },
            ),
          ),
        );

        expect(
          tester
              .widget<Transform>(_checkmarkTransformFinder())
              .transform
              .entry(0, 0),
          0.0,
        );

        await tester.tap(find.byType(CruxCheckbox));
        // Zero-duration pump first lets the pending setState actually
        // rebuild and start the spring (mirrors button_test.dart /
        // switch_test.dart's identical two-pump sampling pattern); only
        // *then* does advancing the clock move it forward from its start.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final double midFlight = tester
            .widget<Transform>(_checkmarkTransformFinder())
            .transform
            .entry(0, 0);
        expect(midFlight, greaterThan(0.0));

        await tester.pumpAndSettle();

        final double settled = tester
            .widget<Transform>(_checkmarkTransformFinder())
            .transform
            .entry(0, 0);
        expect(settled, closeTo(1.0, 0.001));
      },
    );

    testWidgets(
      'the checkmark scales back down to 0 when checked flips from true to '
      'false',
      (WidgetTester tester) async {
        bool checked = true;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxCheckbox(
                  checked: checked,
                  onChanged: (bool next) => setState(() => checked = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CruxCheckbox));
        await tester.pumpAndSettle();

        final double settled = tester
            .widget<Transform>(_checkmarkTransformFinder())
            .transform
            .entry(0, 0);
        expect(settled, closeTo(0.0, 0.001));
      },
    );
  });

  group('checkmark overshoot', () {
    // Confirms the checkmark's appear animation actually overshoots past
    // its resting scale (the "scale 0 -> ~1.15 -> 1.0" spec this package
    // agreed on -- see plans/atoms-batch-2.md and checkbox.dart's own class
    // doc), and that the box's pulse -- derived from that same overshoot --
    // is large enough to read as a visible bulge rather than a sub-pixel
    // no-op. Samples every millisecond across the whole flight (rather than
    // pumpAndSettle(), which would only ever show the *settled* value) so
    // the brief overshoot peak, which lasts a few tens of milliseconds, is
    // never skipped over.
    testWidgets(
      'the checkmark scale peaks between 1.08 and 1.22, and the box width '
      'peaks at least 0.8px past its 22px resting size, while checking',
      (WidgetTester tester) async {
        bool checked = false;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxCheckbox(
                  checked: checked,
                  onChanged: (bool next) => setState(() => checked = next),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(CruxCheckbox));
        await tester.pump();

        double peakCheckScale = 0.0;
        double peakBoxWidth = 0.0;
        for (int i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 1));
          final double checkScale = tester
              .widget<Transform>(_checkmarkTransformFinder())
              .transform
              .entry(0, 0);
          if (checkScale > peakCheckScale) {
            peakCheckScale = checkScale;
          }
          final double boxWidth = _boxWidth(tester);
          if (boxWidth > peakBoxWidth) {
            peakBoxWidth = boxWidth;
          }
        }

        expect(peakCheckScale, inInclusiveRange(1.08, 1.22));
        expect(peakBoxWidth, greaterThanOrEqualTo(_restingBoxSize + 0.8));
      },
    );

    testWidgets(
      'never renders a negative checkmark scale while unchecking (the '
      "spring's undershoot doesn't mirror-flip the checkmark)",
      (WidgetTester tester) async {
        bool checked = true;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxCheckbox(
                  checked: checked,
                  onChanged: (bool next) => setState(() => checked = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CruxCheckbox));
        await tester.pump();

        for (int i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 1));
          final double checkScale = tester
              .widget<Transform>(_checkmarkTransformFinder())
              .transform
              .entry(0, 0);
          expect(checkScale, greaterThanOrEqualTo(0.0));
        }
      },
    );
  });
}
