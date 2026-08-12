// Behavior tests for CruxChip, following the same structure as
// button_test.dart (per spec.md's instruction to use CruxButton as
// precedent for press演出・hug レイアウト・ellipsis).
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxChip needs to lay out and
/// paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately, exercising the documented
/// fallback to [CruxThemeData.light] (same convention as button_test.dart).
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
        _wrap(CruxChip(label: 'すべて', onTap: () => calls++)),
      );

      await tester.tap(find.byType(CruxChip));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets(
      'does not invoke onTap and renders the disabled colors when onTap is '
      'null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxChip(label: 'すべて', onTap: null)),
        );

        // Disabled chips must not throw or call anything on tap.
        await tester.tap(find.byType(CruxChip));
        await tester.pump();

        final Container container = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration decoration =
            container.decoration! as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;
        expect(decoration.color, CruxColors.light.surface);
        expect(shape.side.color, CruxColors.light.separator);

        final Text text = tester.widget<Text>(find.text('すべて'));
        expect(text.style?.color, CruxColors.light.muted);
      },
    );
  });

  group('overflow safety', () {
    testWidgets(
      'does not overflow when squeezed into an 80px width with a very long '
      'label',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const SizedBox(
              width: 80,
              child: CruxChip(
                label: 'とてもとても長いラベルのチップです。あふれてはいけません。',
                onTap: null,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        final Text text = tester.widget<Text>(
          find.text('とてもとても長いラベルのチップです。あふれてはいけません。'),
        );
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      },
    );
  });

  group('tap target', () {
    testWidgets(
      'keeps a 44x44 minimum tap target even though the visible pill is 36 '
      'tall, and the whole area (not just the visible pill) is tappable',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxChip(label: 'OK', onTap: () => calls++),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxChip));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));

        // Tap near the top-left corner of the 44x44 box: the visible pill
        // is only 36 tall, so this point sits in the padding area outside
        // the pill but still inside the tap target.
        final Offset topLeft = tester.getTopLeft(find.byType(CruxChip));
        await tester.tapAt(topLeft + const Offset(2, 2));
        await tester.pump();

        expect(calls, 1);
      },
    );
  });

  group('sizing (hug content)', () {
    testWidgets(
      'hugs its label width instead of stretching to fill a wide loose '
      'parent',
      (WidgetTester tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(402, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxChip(label: 'S', onTap: () {}),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxChip));

        expect(size.width, isNot(402));
        expect(size.width, lessThan(120));
      },
    );
  });

  group('press animation', () {
    // Same technique as button_test.dart: read the (0, 0) entry of the
    // Transform's matrix directly, since Transform.scale always leaves the
    // Z axis at 1.0.
    testWidgets('scales down while pressed and returns to 1.0 on release', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CruxChip(label: 'すべて', onTap: () {})));

      expect(
        tester.widget<Transform>(find.byType(Transform)).transform.entry(0, 0),
        1.0,
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxChip)),
      );
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

    testWidgets(
      'does not scale or invoke onTap while disabled, even under a held '
      'gesture',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxChip(label: 'すべて', onTap: null)),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxChip)),
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
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'layers a translucent textPrimary state layer over the background '
      'while pressed',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(CruxChip(label: 'すべて', onTap: () {})));

        final Color restBackground =
            (tester.widget<Container>(find.byType(Container)).decoration!
                    as ShapeDecoration)
                .color!;
        expect(restBackground, CruxColors.light.surface);

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxChip)),
        );
        await tester.pump();

        final Color pressedBackground =
            (tester.widget<Container>(find.byType(Container)).decoration!
                    as ShapeDecoration)
                .color!;
        // The state layer must visibly change the background away from the
        // flat rest-state surface color, and must not simply be transparent
        // (i.e. it actually blends something on top).
        expect(pressedBackground, isNot(restBackground));

        await gesture.up();
        await tester.pumpAndSettle();
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
        await tester.pumpWidget(_wrap(CruxChip(label: 'すべて', onTap: () {})));

        await tester.tap(find.byType(CruxChip));
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
      await tester.pumpWidget(_wrap(CruxChip(label: 'すべて', onTap: () {})));

      await tester.tap(find.byType(CruxChip));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byType(CruxChip));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('state color resolution', () {
    testWidgets('unselected+enabled: surface background, separator border, '
        'textSecondary text', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(CruxChip(label: 'すべて', onTap: () {})));

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(decoration.color, CruxColors.light.surface);
      expect(shape.side.color, CruxColors.light.separator);

      final Text text = tester.widget<Text>(find.text('すべて'));
      expect(text.style?.color, CruxColors.light.textSecondary);
    });

    testWidgets('selected+enabled: accentTint background, accentLine border, '
        'textPrimary text', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(CruxChip(label: 'すべて', selected: true, onTap: () {})),
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

      final Text text = tester.widget<Text>(find.text('すべて'));
      expect(text.style?.color, CruxColors.light.textPrimary);
    });

    testWidgets('disabled (onTap null), even if selected: surface background, '
        'separator border, muted text', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const CruxChip(label: 'すべて', selected: true, onTap: null)),
      );

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(decoration.color, CruxColors.light.surface);
      expect(shape.side.color, CruxColors.light.separator);

      final Text text = tester.widget<Text>(find.text('すべて'));
      expect(text.style?.color, CruxColors.light.muted);
    });
  });

  group('onTap is a plain optional parameter (not required)', () {
    testWidgets('CruxChip can be constructed with no onTap argument at all and '
        'renders disabled, matching CruxCard/CruxListTile\'s convention '
        'for the same nullable-callback-disables pattern', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CruxChip(label: 'すべて')));

      final Text text = tester.widget<Text>(find.text('すべて'));
      expect(text.style?.color, CruxColors.light.muted);
    });
  });

  group('semantics', () {
    testWidgets('exposes button semantics with the selected state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxChip(label: 'すべて', selected: true, onTap: () {})),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxChip));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      expect(node.label, 'すべて');

      handle.dispose();
    });

    testWidgets('exposes disabled semantics when onTap is null', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const CruxChip(label: 'すべて', onTap: null)));

      final SemanticsNode node = tester.getSemantics(find.byType(CruxChip));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });
}
