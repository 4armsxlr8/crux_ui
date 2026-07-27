// Behavior tests for CruxCard, per unknowns/atoms-batch-1/spec.md's
// CruxCard section.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxCard needs to lay out and
/// paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light].
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

void main() {
  group('tap handling', () {
    testWidgets('invokes onTap exactly once per tap', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        _wrap(CruxCard(onTap: () => calls++, child: const Text('card'))),
      );

      await tester.tap(find.byType(CruxCard));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets(
      'is a pure, non-interactive container with no press feedback when '
      'onTap is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxCard(onTap: null, child: Text('card'))),
        );

        // Tapping a non-interactive card must not throw.
        await tester.tap(find.byType(CruxCard));
        await tester.pump();

        // "Pure container, no feedback" (spec) means: no press-scale
        // transform is even built for a non-interactive card.
        expect(find.byType(Transform), findsNothing);
      },
    );
  });

  group('appearance', () {
    testWidgets('renders surface background, a 1px separator border, and the '
        'default CruxRadii.l corner radius', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const CruxCard(child: Text('x'))));

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(decoration.color, CruxColors.light.surface);
      expect(shape.side.color, CruxColors.light.separator);
      expect(shape.side.width, 1);
      expect(shape.borderRadius, BorderRadius.circular(CruxRadii.l));

      // No shadow (spec: "影なし").
      expect(decoration.shadows, anyOf(isNull, isEmpty));
    });

    testWidgets('clips its child to the card\'s rounded-corner shape via '
        'Clip.antiAlias, so a full-bleed child (e.g. a pressed '
        'CruxListTile\'s state layer) never paints past the rounded '
        'corners', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const CruxCard(child: Text('x'))));

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      expect(container.clipBehavior, Clip.antiAlias);
    });

    testWidgets('applies a custom radius, with the clip tracking it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CruxCard(radius: CruxRadii.m, child: Text('x'))),
      );

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      expect(container.clipBehavior, Clip.antiAlias);
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(shape.borderRadius, BorderRadius.circular(CruxRadii.m));
    });

    testWidgets('resolves colors from the ambient CruxTheme (dark)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        CruxTheme(
          data: CruxThemeData.dark(),
          child: _wrap(const CruxCard(child: Text('x'))),
        ),
      );

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(decoration.color, CruxColors.dark.surface);
      expect(shape.side.color, CruxColors.dark.separator);
    });
  });

  group('press feedback (interactive only)', () {
    testWidgets(
      'scales down to pressedScaleSubtle and tints the background while '
      'pressed, then springs back on release',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxCard(onTap: () {}, child: const Text('x'))),
        );

        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          1.0,
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxCard)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final double pressedScale = tester
            .widget<Transform>(find.byType(Transform))
            .transform
            .entry(0, 0);
        expect(pressedScale, lessThan(1.0));

        final Container pressedContainer = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration pressedDecoration =
            pressedContainer.decoration! as ShapeDecoration;
        expect(pressedDecoration.color, isNot(CruxColors.light.surface));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0),
          closeTo(1.0, 0.001),
        );
        final Container idleContainer = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration idleDecoration =
            idleContainer.decoration! as ShapeDecoration;
        expect(idleDecoration.color, CruxColors.light.surface);
      },
    );
  });

  group('minimum press feedback (fast tap)', () {
    // Thin confirmation of the same guarantee CruxButton implements; see
    // button_test.dart's "minimum press feedback (fast tap)" group for the
    // full coverage (fast-tap reproduction via `tester.tap()`, re-tap
    // during the guarantee window, and dispose during the guarantee
    // window) and its rationale.
    testWidgets(
      'stays visibly pressed for a minimum duration even when down and up '
      'are delivered back-to-back, then springs back to 1.0',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxCard(onTap: () {}, child: const Text('x'))),
        );

        await tester.tap(find.byType(CruxCard));
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

    testWidgets('does not throw when tapped again, or when disposed, while the '
        'minimum-hold guarantee from a fast tap is still pending', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxCard(onTap: () {}, child: const Text('x'))),
      );

      await tester.tap(find.byType(CruxCard));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byType(CruxCard));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('tap target', () {
    testWidgets(
      'keeps a 44x44 minimum tap target when interactive, even with a '
      'tiny child',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxCard(
                onTap: () {},
                padding: EdgeInsets.zero,
                child: const SizedBox(width: 4, height: 4),
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxCard));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      },
    );
  });

  group('sizing (does not hug, unlike CruxButton)', () {
    testWidgets(
      'fills a wide loose parent instead of shrinking to its content, '
      'because CruxCard is a block-level surface (spec: 幅はボタンと違い '
      'hug しない)',
      (WidgetTester tester) async {
        // Shrink the test surface itself to a known width and wrap only in
        // Center: the surface's root constraints are always *tight*, so a
        // nested SizedBox alone cannot narrow them (enforce() clamps a
        // smaller declared width right back up to the tight incoming
        // value) — only Center genuinely *loosens* what it received into a
        // bounded-but-loose constraint a descendant can choose to fill or
        // not. Same technique button_test.dart uses for its "hugs content"
        // regression test, applied here to prove the opposite: unlike
        // CruxButton, CruxCard fills this loose width instead of
        // shrinking to its tiny 10x10 child.
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(300, 600);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          _wrap(
            const Center(
              child: CruxCard(child: SizedBox(width: 10, height: 10)),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxCard));
        expect(size.width, 300);
      },
    );
  });

  group('disabling mid-press (regression)', () {
    testWidgets(
      'does not throw when onTap flips from a callback to null while the '
      'finger is still down (mirrors button_test.dart\'s identical '
      'regression: swapping out the GestureDetector subtree mid-gesture '
      'tears out the in-flight TapGestureRecognizer and crashes)',
      (WidgetTester tester) async {
        int calls = 0;

        Widget buildCard(VoidCallback? onTap) {
          return _wrap(CruxCard(onTap: onTap, child: const Text('card')));
        }

        await tester.pumpWidget(buildCard(() => calls++));

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxCard)),
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

        // Disable the card while the gesture is still held down (e.g. an
        // app disabling a card after validation, from state unrelated to
        // the card's own onTap).
        await tester.pumpWidget(buildCard(null));

        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(calls, 0);
      },
    );
  });

  group('semantics', () {
    testWidgets('is announced as a button when onTap is set', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxCard(onTap: () {}, child: const Text('x'))),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxCard));
      expect(node.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('is not announced as a button when onTap is null', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const CruxCard(child: Text('x'))));

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && (w.properties.button ?? false),
        ),
        findsNothing,
      );

      handle.dispose();
    });
  });
}
