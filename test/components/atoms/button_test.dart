// Behavior tests for CruxButton, in the order specified by
// unknowns/button-atom/plan.md section 3. The animated "how bouncy does it
// feel" quality is out of scope here (per plan) and is checked visually via
// the example app instead; these tests only assert that scale moves below
// 1.0 while pressed and returns to 1.0 after release.
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxButton needs to lay out and
/// paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light].
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

void main() {
  group('tap handling', () {
    testWidgets('invokes onPressed exactly once per tap', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        _wrap(CruxButton(label: 'はじめる', onPressed: () => calls++)),
      );

      await tester.tap(find.byType(CruxButton));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets(
      'does not invoke onPressed and renders the disabled background when '
      'onPressed is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxButton(label: 'はじめる', onPressed: null)),
        );

        // Disabled buttons must not throw or call anything on tap.
        await tester.tap(find.byType(CruxButton));
        await tester.pump();

        final Container container = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration decoration =
            container.decoration! as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;
        expect(decoration.color, CruxColors.light.separator);
        expect(shape.side, BorderSide.none);

        final Text text = tester.widget<Text>(find.text('はじめる'));
        expect(text.style?.color, CruxColors.light.muted);
      },
    );
  });

  group('overflow safety (KB8)', () {
    testWidgets(
      'does not overflow when squeezed into an 80px width with a very long '
      'label',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const SizedBox(
              width: 80,
              child: CruxButton(
                label: 'とてもとても長いラベルのボタンです。あふれてはいけません。',
                onPressed: null,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('tap target', () {
    testWidgets(
      'keeps a 44x44 minimum tap target even at small size, and the whole '
      'area (not just the visible pill) is tappable',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxButton(
                label: 'OK',
                size: CruxButtonSize.small,
                onPressed: () => calls++,
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxButton));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));

        // Tap near the top-left corner of the 44x44 box: the visible pill
        // at small size is only 36 tall, so this point sits in the padding
        // area outside the pill but still inside the tap target.
        final Offset topLeft = tester.getTopLeft(find.byType(CruxButton));
        await tester.tapAt(topLeft + const Offset(2, 2));
        await tester.pump();

        expect(calls, 1);
      },
    );
  });

  group('sizing (hug content)', () {
    testWidgets(
      'hugs its label width instead of stretching to fill a wide loose '
      'parent (regression: CruxButton was expanding to its parent\'s max '
      'width because of an alignment-driven Container/Center, per '
      'unknowns/button-atom/implementation-notes.md "Post-ship layout '
      'fix")',
      (WidgetTester tester) async {
        // Shrink the whole test surface to 402 logical pixels wide (a
        // typical phone width), rather than nesting a SizedBox under the
        // test binding's default (already-tight) 800px-wide root: a tight
        // incoming constraint can't be narrowed by a descendant SizedBox
        // (BoxConstraints.enforce clamps to the incoming range), so only
        // shrinking the surface itself reproduces a real "loose, bounded"
        // parent width.
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(402, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxButton(
                label: 'S',
                size: CruxButtonSize.small,
                onPressed: null,
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxButton));

        // A one-character small-size label plus its S16 horizontal padding
        // on each side is nowhere near the 402px surface: if CruxButton
        // hugs its content, this must be well under 120px, not 402.
        expect(size.width, isNot(402));
        expect(size.width, lessThan(120));
      },
    );
  });

  group('press animation', () {
    // Reads the horizontal scale factor directly off the transform matrix's
    // (0, 0) entry, rather than Matrix4.getMaxScaleOnAxis(): Transform.scale
    // always leaves the Z axis at a fixed 1.0, so getMaxScaleOnAxis() would
    // report 1.0 regardless of the (smaller) X/Y press scale and could never
    // observe a value below 1.0.
    testWidgets('scales down while pressed and returns to 1.0 on release', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxButton(label: 'はじめる', onPressed: () {})),
      );

      expect(
        tester.widget<Transform>(find.byType(Transform)).transform.entry(0, 0),
        1.0,
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxButton)),
      );
      // A zero-duration pump first lets the pending setState from onTapDown
      // actually rebuild and call animateTo (which starts the spring's
      // ticker at elapsed = 0); only *then* does advancing the clock below
      // move the spring forward from its start.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        tester.widget<Transform>(find.byType(Transform)).transform.entry(0, 0),
        lessThan(1.0),
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.widget<Transform>(find.byType(Transform)).transform.entry(0, 0),
        closeTo(1.0, 0.001),
      );
    });
  });

  group('semantics', () {
    testWidgets(
      "label is announced exactly once, not duplicated with the child "
      "Text's own automatic semantics",
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', onPressed: () {})),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(CruxButton),
        );
        expect(node.label, 'はじめる');

        handle.dispose();
      },
    );
  });

  group('disabling mid-press (regression)', () {
    testWidgets(
      'does not throw and settles back to scale 1.0 when onPressed flips '
      'from a callback to null while the finger is still down',
      (WidgetTester tester) async {
        int calls = 0;

        Widget buildButton(VoidCallback? onPressed) {
          return _wrap(CruxButton(label: 'はじめる', onPressed: onPressed));
        }

        await tester.pumpWidget(buildButton(() => calls++));

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxButton)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          lessThan(1.0),
        );

        // Disable the button while the gesture is still held down, the same
        // way a common "prevent double submit" pattern would from inside
        // its own onPressed via setState.
        await tester.pumpWidget(buildButton(null));

        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          closeTo(1.0, 0.001),
        );
        expect(calls, 0);
      },
    );
  });

  group('minimum press feedback (fast tap)', () {
    // Reproduces the real bug this guarantee fixes: inside a scrollable
    // list, Flutter's TapGestureRecognizer (kPressTimeout = 100ms) often
    // resolves the gesture arena and delivers onTapDown immediately
    // followed by onTapUp with no frame ever rendered in between, so a
    // naive `_pressed = true` then `_pressed = false` collapses to a no-op
    // before the pressed state is ever painted. `tester.tap()` reproduces
    // this exactly: it calls `TestGesture.down()` then `.up()` back-to-back
    // with no `pump()` between them (see `WidgetController.tapAt` in
    // flutter_test/lib/src/controller.dart), unlike this file's own "press
    // animation" group above, which deliberately pumps 80ms between down
    // and up to sample a *slow*, already-working press instead.
    testWidgets(
      'stays visibly pressed for a minimum duration even when down and up '
      'are delivered back-to-back, then springs back to 1.0',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', onPressed: () {})),
        );

        await tester.tap(find.byType(CruxButton));
        // Zero-duration pump lets the pending setState from the fast
        // down+up actually rebuild (see the "press animation" group's
        // identical comment above); the second pump then samples the
        // spring partway through its flight.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          lessThan(0.995),
        );

        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          closeTo(1.0, 0.001),
        );
      },
    );

    testWidgets(
      "does not throw, and still invokes onPressed once per tap, when "
      "tapped again while a previous fast tap's minimum-hold guarantee is "
      'still pending',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', onPressed: () => calls++)),
        );

        await tester.tap(find.byType(CruxButton));
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(find.byType(CruxButton));
        await tester.pump(const Duration(milliseconds: 10));

        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(calls, 2);
        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          closeTo(1.0, 0.001),
        );
      },
    );

    testWidgets(
      'does not throw and leaves no pending timer when disposed while the '
      'minimum-hold guarantee is still pending',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', onPressed: () {})),
        );

        await tester.tap(find.byType(CruxButton));
        await tester.pump(const Duration(milliseconds: 10));

        // Unmount the button while the minimum-hold guarantee's Timer is
        // still pending: flutter_test's automated binding fails the test
        // if any Timer is still pending after the widget tree is torn
        // down, so this also exercises "no pending timer left behind"
        // without needing to inspect the timer directly.
        await tester.pumpWidget(const SizedBox.shrink());

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('variant color resolution', () {
    testWidgets('filled: accent background, no border, onAccent text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxButton(label: 'Go', onPressed: () {})),
      );

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(decoration.color, CruxColors.light.accent);
      expect(shape.side, BorderSide.none);

      final Text text = tester.widget<Text>(find.text('Go'));
      expect(text.style?.color, CruxColors.light.onAccent);
    });

    testWidgets(
      'tonal: accentTint background, accentLine border, textPrimary text',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxButton(
              label: 'Go',
              variant: CruxButtonVariant.tonal,
              onPressed: () {},
            ),
          ),
        );

        final Container container = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration decoration =
            container.decoration! as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;
        expect(decoration.color, CruxColors.light.accentTint);
        expect(shape.side.color, CruxColors.light.accentLine);

        final Text text = tester.widget<Text>(find.text('Go'));
        expect(text.style?.color, CruxColors.light.textPrimary);
      },
    );

    testWidgets('ghost: no fill, no border, textPrimary text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxButton(
            label: 'Go',
            variant: CruxButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
      );

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(decoration.color, isNull);
      expect(shape.side, BorderSide.none);

      final Text text = tester.widget<Text>(find.text('Go'));
      expect(text.style?.color, CruxColors.light.textPrimary);
    });
  });

  // CruxButton's loading state is built on CruxSpinner, which animates
  // continuously for as long as it is on screen (see spinner_test.dart's
  // file doc): every test in this group samples at fixed pumped durations
  // (or none at all), never tester.pumpAndSettle(), which would time out
  // waiting for an animation that never stops.
  group('loading state', () {
    testWidgets(
      'does not invoke onPressed and does not scale down on tap while '
      'loading, even though onPressed is set',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            CruxButton(
              label: 'はじめる',
              loading: true,
              onPressed: () => calls++,
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxButton)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          1.0,
        );

        await gesture.up();
        await tester.pump();

        expect(calls, 0);
      },
    );

    testWidgets(
      'renders a small CruxSpinner in place of the label while loading',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', loading: true, onPressed: () {})),
        );

        expect(find.byType(CruxSpinner), findsOneWidget);
        expect(
          tester.widget<CruxSpinner>(find.byType(CruxSpinner)).size,
          CruxSpinnerSize.small,
        );
      },
    );

    testWidgets(
      'renders the loading CruxSpinner at its natural 16x16 size even '
      'when the label is narrower than that, instead of being squeezed '
      'into the label\'s width',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'S', loading: true, onPressed: () {})),
        );

        expect(tester.getSize(find.byType(CruxSpinner)), const Size(16, 16));
      },
    );

    testWidgets(
      'colors the loading spinner onAccent on the default filled variant',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', loading: true, onPressed: () {})),
        );

        expect(
          tester.widget<CruxSpinner>(find.byType(CruxSpinner)).color,
          CruxColors.light.onAccent,
        );
      },
    );

    testWidgets(
      'colors the loading spinner to match the label foreground color on '
      'the tonal variant',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxButton(
              label: 'はじめる',
              variant: CruxButtonVariant.tonal,
              loading: true,
              onPressed: () {},
            ),
          ),
        );

        expect(
          tester.widget<CruxSpinner>(find.byType(CruxSpinner)).color,
          CruxColors.light.textPrimary,
        );
      },
    );

    testWidgets('is not enabled in semantics while loading', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxButton(label: 'はじめる', loading: true, onPressed: () {})),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxButton));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });

    testWidgets(
      'keeps announcing the label while loading, instead of going silent '
      '(WCAG 4.1.2: a screen reader still needs a name for the button)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', loading: true, onPressed: () {})),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(CruxButton),
        );
        expect(node.label, 'はじめる');

        handle.dispose();
      },
    );

    testWidgets(
      'keeps the same size whether loading is true or false, for the same '
      'label and size',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', onPressed: () {})),
        );
        final Size notLoadingSize = tester.getSize(find.byType(CruxButton));

        await tester.pumpWidget(
          _wrap(CruxButton(label: 'はじめる', loading: true, onPressed: () {})),
        );
        final Size loadingSize = tester.getSize(find.byType(CruxButton));

        expect(loadingSize, notLoadingSize);
      },
    );
  });
}
