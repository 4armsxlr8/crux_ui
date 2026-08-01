// Behavior tests for CruxIconButton, following button_test.dart's and
// switch_test.dart's established patterns for this package: semantics
// (label announced exactly once, enabled/disabled trait), the 44x44 minimum
// tap target, press animation (read off the Transform matrix), the fast-tap
// minimum press feedback guarantee, disabled-press safety, per-tone color
// resolution, and (added for the medium/large size split) the visible
// circle's and tap target's actual pixel geometry per CruxIconButtonSize.
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxIconButton needs to lay out
/// and paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light] (same convention as
/// button_test.dart / switch_test.dart).
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// A trivial, semantics-free icon widget for tests that don't care what the
/// icon looks like, only that a `label` is separately supplied.
const Widget _dummyIcon = SizedBox(width: 16, height: 16);

/// Finds the [DecoratedBox] painting CruxIconButton's visible filled
/// circle -- the only [DecoratedBox] a rendered CruxIconButton contains.
Finder _circleFinder() => find.byType(DecoratedBox);

void main() {
  group('tap handling', () {
    testWidgets('invokes onPressed exactly once per tap', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(
            icon: _dummyIcon,
            label: '閉じる',
            onPressed: () => calls++,
          ),
        ),
      );

      await tester.tap(find.byType(CruxIconButton));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets(
      'does not invoke onPressed and does not throw when onPressed is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const CruxIconButton(
              icon: _dummyIcon,
              label: '閉じる',
              onPressed: null,
            ),
          ),
        );

        await tester.tap(find.byType(CruxIconButton));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('tap target', () {
    testWidgets(
      'keeps a 44x44 minimum tap target, and the whole area (not just the '
      'visible circle) is tappable',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxIconButton(
                icon: _dummyIcon,
                label: '閉じる',
                onPressed: () => calls++,
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxIconButton));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));

        // At the default medium size the visible circle is the same 44x44
        // as the tap target square around it (see
        // CruxIconButtonSize.medium's own doc) -- but it is still a
        // *circle* inscribed in that square, so its corners remain outside
        // the circle's rounded edge. Tap near the top-left corner, outside
        // the visible circle but still inside the square tap target.
        final Offset topLeft = tester.getTopLeft(find.byType(CruxIconButton));
        await tester.tapAt(topLeft + const Offset(2, 2));
        await tester.pump();

        expect(calls, 1);
      },
    );
  });

  group('size variants', () {
    testWidgets('renders a 44x44 visible circle by default (medium)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(icon: _dummyIcon, label: '閉じる', onPressed: () {}),
        ),
      );

      final Size circleSize = tester.getSize(_circleFinder());
      expect(circleSize.width, 44);
      expect(circleSize.height, 44);
    });

    testWidgets(
      'size: large renders a 56x56 visible circle and a 56x56 tap target',
      (WidgetTester tester) async {
        // Wrapped in Center, the same way the "tap target" group above
        // wraps its own fixture: without it, the widget tree's root gives
        // CruxIconButton *tight* constraints matching the whole test
        // viewport, and it would report that viewport's size rather than
        // its own natural 56x56 -- Center loosens those constraints so the
        // widget can size itself.
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxIconButton(
                icon: _dummyIcon,
                label: '閉じる',
                size: CruxIconButtonSize.large,
                onPressed: () {},
              ),
            ),
          ),
        );

        final Size tapTargetSize = tester.getSize(
          find.byType(CruxIconButton),
        );
        expect(tapTargetSize.width, 56);
        expect(tapTargetSize.height, 56);

        final Size circleSize = tester.getSize(_circleFinder());
        expect(circleSize.width, 56);
        expect(circleSize.height, 56);
      },
    );

    testWidgets(
      'size: large keeps announcing its label with button/enabled traits',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            CruxIconButton(
              icon: _dummyIcon,
              label: '閉じる',
              size: CruxIconButtonSize.large,
              onPressed: () {},
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(CruxIconButton),
        );
        expect(node.label, '閉じる');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);

        handle.dispose();
      },
    );

    testWidgets(
      'size: large exposes a disabled semantics node when onPressed is null',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            const CruxIconButton(
              icon: _dummyIcon,
              label: '閉じる',
              size: CruxIconButtonSize.large,
              onPressed: null,
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(CruxIconButton),
        );
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      },
    );

    testWidgets(
      'size: large scales down while pressed and returns to 1.0 on release',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxIconButton(
              icon: _dummyIcon,
              label: '閉じる',
              size: CruxIconButtonSize.large,
              onPressed: () {},
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxIconButton)),
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

        await gesture.up();
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
  });

  group('press animation', () {
    // Reads the horizontal scale factor directly off the transform matrix's
    // (0, 0) entry, the same technique button_test.dart uses and for the
    // same reason (Transform.scale always leaves the Z axis at 1.0).
    testWidgets('scales down while pressed and returns to 1.0 on release', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(icon: _dummyIcon, label: '閉じる', onPressed: () {}),
        ),
      );

      expect(
        tester.widget<Transform>(find.byType(Transform)).transform.entry(0, 0),
        1.0,
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxIconButton)),
      );
      // A zero-duration pump first lets the pending setState from onTapDown
      // actually rebuild and start the spring (matches button_test.dart's
      // identical two-pump sampling pattern).
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
      'does not scale down while pressed when the button is disabled',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const CruxIconButton(
              icon: _dummyIcon,
              label: '閉じる',
              onPressed: null,
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxIconButton)),
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
        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('minimum press feedback (fast tap)', () {
    // Reproduces the same fast-tap-in-a-scroll-view bug button_test.dart's
    // identical group guards against: `tester.tap()` delivers down and up
    // back-to-back with no frame rendered in between.
    testWidgets(
      'stays visibly pressed for a minimum duration even when down and up '
      'are delivered back-to-back, then springs back to 1.0',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxIconButton(icon: _dummyIcon, label: '閉じる', onPressed: () {}),
          ),
        );

        await tester.tap(find.byType(CruxIconButton));
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
  });

  group('tone color resolution', () {
    testWidgets('neutral + enabled: mutedFill circle, textPrimary icon', (
      WidgetTester tester,
    ) async {
      Color? iconColor;
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(
            icon: Builder(
              builder: (BuildContext context) {
                iconColor = IconTheme.of(context).color;
                return const SizedBox(width: 16, height: 16);
              },
            ),
            label: '閉じる',
            onPressed: () {},
          ),
        ),
      );

      final DecoratedBox box = tester.widget<DecoratedBox>(_circleFinder());
      final ShapeDecoration decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, CruxColors.light.mutedFill);
      expect(iconColor, CruxColors.light.textPrimary);
    });

    testWidgets('primary + enabled: accent circle, onAccent icon', (
      WidgetTester tester,
    ) async {
      Color? iconColor;
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(
            icon: Builder(
              builder: (BuildContext context) {
                iconColor = IconTheme.of(context).color;
                return const SizedBox(width: 16, height: 16);
              },
            ),
            label: '送信',
            tone: CruxIconButtonTone.primary,
            onPressed: () {},
          ),
        ),
      );

      final DecoratedBox box = tester.widget<DecoratedBox>(_circleFinder());
      final ShapeDecoration decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, CruxColors.light.accent);
      expect(iconColor, CruxColors.light.onAccent);
    });

    testWidgets('neutral + disabled: mutedFill circle, muted icon', (
      WidgetTester tester,
    ) async {
      Color? iconColor;
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(
            icon: Builder(
              builder: (BuildContext context) {
                iconColor = IconTheme.of(context).color;
                return const SizedBox(width: 16, height: 16);
              },
            ),
            label: '閉じる',
            onPressed: null,
          ),
        ),
      );

      final DecoratedBox box = tester.widget<DecoratedBox>(_circleFinder());
      final ShapeDecoration decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, CruxColors.light.mutedFill);
      expect(iconColor, CruxColors.light.muted);
    });

    testWidgets('primary + disabled: mutedFill circle, muted icon', (
      WidgetTester tester,
    ) async {
      Color? iconColor;
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(
            icon: Builder(
              builder: (BuildContext context) {
                iconColor = IconTheme.of(context).color;
                return const SizedBox(width: 16, height: 16);
              },
            ),
            label: '送信',
            tone: CruxIconButtonTone.primary,
            onPressed: null,
          ),
        ),
      );

      final DecoratedBox box = tester.widget<DecoratedBox>(_circleFinder());
      final ShapeDecoration decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, CruxColors.light.mutedFill);
      expect(iconColor, CruxColors.light.muted);
    });
  });

  group('semantics', () {
    testWidgets('label is announced exactly once, with button/enabled traits', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          CruxIconButton(icon: _dummyIcon, label: '閉じる', onPressed: () {}),
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(CruxIconButton),
      );
      expect(node.label, '閉じる');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);

      handle.dispose();
    });

    testWidgets('exposes a disabled semantics node when onPressed is null', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const CruxIconButton(
            icon: _dummyIcon,
            label: '閉じる',
            onPressed: null,
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(CruxIconButton),
      );
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('disabling mid-press (regression)', () {
    testWidgets(
      'does not throw and settles back to scale 1.0 when onPressed flips '
      'from a callback to null while the finger is still down',
      (WidgetTester tester) async {
        int calls = 0;

        Widget buildIconButton(VoidCallback? onPressed) {
          return _wrap(
            CruxIconButton(
              icon: _dummyIcon,
              label: '閉じる',
              onPressed: onPressed,
            ),
          );
        }

        await tester.pumpWidget(buildIconButton(() => calls++));

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxIconButton)),
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

        await tester.pumpWidget(buildIconButton(null));

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
}
