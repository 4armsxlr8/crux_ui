// Behavior tests for CruxSwitch, per spec.md's "CruxSwitch" section
// (unknowns/atoms-batch-1/spec.md). Visual metrics (exact pixel sizes) are
// checked visually via the example app; these tests assert the observable
// behavior spec.md calls out: tap notification, disabled state, the 44
// minimum tap target, semantics, per-state color resolution, and that the
// thumb actually moves (spring-animated) between the off/on positions.
//
// CruxSwitch has no text child (unlike CruxButton/CruxChip/
// CruxListTile), so there is no ellipsis-overflow test here: the spec's
// generic "ellipsis 耐性" note does not apply to this atom.
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxSwitch needs to lay out and
/// paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light] (same convention as
/// button_test.dart / chip_test.dart).
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// Finds the track [Container] (the pill-shaped one, i.e. not the thumb)
/// inside a rendered [CruxSwitch]. Distinguished from the thumb by
/// [Container.padding]: the track is the only [Container] here that sets
/// one (the inset that centers the thumb within the pill).
///
/// This used to distinguish the two by `decoration.shape == BoxShape.circle`
/// instead, but the thumb stretch feature (2026-07-25) made the thumb's
/// width vary independently of its height, and [BoxShape.circle] always
/// inscribes its circle using a box's *shortest* side (confirmed against
/// the Flutter SDK's `box_decoration.dart`) -- so a wider-than-tall
/// `BoxShape.circle` box would not have actually looked stretched, just an
/// undersized circle floating in extra empty space. The thumb now uses
/// [BoxDecoration.borderRadius] instead (see switch.dart), which is why
/// this helper switched to a shape-independent signal.
Finder _trackFinder() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! Container) {
      return false;
    }
    return widget.decoration != null && widget.padding != null;
  });
}

/// Finds the thumb [Container] inside a rendered [CruxSwitch]. See
/// [_trackFinder]'s dartdoc for why this is padding-based rather than
/// shape-based.
Finder _thumbFinder() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! Container) {
      return false;
    }
    return widget.decoration != null && widget.padding == null;
  });
}

void main() {
  group('tap handling', () {
    testWidgets('notifies onChanged(true) exactly once when tapped while off', (
      WidgetTester tester,
    ) async {
      final List<bool> notifications = <bool>[];
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: false, onChanged: notifications.add)),
      );

      await tester.tap(find.byType(CruxSwitch));
      await tester.pump();

      expect(notifications, <bool>[true]);
    });

    testWidgets('notifies onChanged(false) exactly once when tapped while on', (
      WidgetTester tester,
    ) async {
      final List<bool> notifications = <bool>[];
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: true, onChanged: notifications.add)),
      );

      await tester.tap(find.byType(CruxSwitch));
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
          _wrap(const CruxSwitch(value: true, onChanged: null)),
        );

        await tester.tap(find.byType(CruxSwitch));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders a muted track color when disabled and on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CruxSwitch(value: true, onChanged: null)),
      );

      final Container track = tester.widget<Container>(_trackFinder());
      final ShapeDecoration decoration = track.decoration! as ShapeDecoration;
      expect(decoration.color, CruxColors.light.muted);
    });

    testWidgets('renders the same off-track color when disabled and off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CruxSwitch(value: false, onChanged: null)),
      );

      final Container track = tester.widget<Container>(_trackFinder());
      final ShapeDecoration decoration = track.decoration! as ShapeDecoration;
      expect(decoration.color, CruxColors.light.separator);
    });
  });

  group('tap target', () {
    testWidgets(
      'keeps a 44x44 minimum tap target and the whole area (not just the '
      'visible track) is tappable',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            Center(child: CruxSwitch(value: false, onChanged: (_) => calls++)),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxSwitch));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));

        // The visible track is only 32 tall; tap near the top edge of the
        // 44-tall hit area, outside the visible track but inside the tap
        // target.
        final Offset topLeft = tester.getTopLeft(find.byType(CruxSwitch));
        await tester.tapAt(topLeft + const Offset(4, 2));
        await tester.pump();

        expect(calls, 1);
      },
    );
  });

  group('color resolution', () {
    testWidgets('on + enabled renders an accent track', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: true, onChanged: (_) {})),
      );

      final Container track = tester.widget<Container>(_trackFinder());
      final ShapeDecoration decoration = track.decoration! as ShapeDecoration;
      expect(decoration.color, CruxColors.light.accent);
    });

    testWidgets('off + enabled renders a separator track', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: false, onChanged: (_) {})),
      );

      final Container track = tester.widget<Container>(_trackFinder());
      final ShapeDecoration decoration = track.decoration! as ShapeDecoration;
      expect(decoration.color, CruxColors.light.separator);
    });

    testWidgets('the thumb is always surface-colored', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: true, onChanged: (_) {})),
      );

      final Container thumb = tester.widget<Container>(_thumbFinder());
      final ShapeDecoration decoration = thumb.decoration! as ShapeDecoration;
      expect(decoration.color, CruxColors.light.surface);
    });
  });

  group('thumb motion', () {
    testWidgets(
      'springs the thumb from the left side to the right side when toggled '
      'from off to on',
      (WidgetTester tester) async {
        bool value = false;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSwitch(
                  value: value,
                  onChanged: (bool next) => setState(() => value = next),
                );
              },
            ),
          ),
        );

        final double leftX = tester.getCenter(_thumbFinder()).dx;

        await tester.tap(find.byType(CruxSwitch));
        await tester.pumpAndSettle();

        final double rightX = tester.getCenter(_thumbFinder()).dx;

        expect(rightX, greaterThan(leftX));
      },
    );
  });

  group('thumb stretch', () {
    testWidgets('widens the thumb while pressed, past its resting width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: false, onChanged: (_) {})),
      );

      final double restingWidth = tester.getSize(_thumbFinder()).width;

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSwitch)),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(_thumbFinder()).width, greaterThan(restingWidth));

      // Release cleanly so the gesture doesn't leak into the next test.
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'returns the thumb to its resting width after releasing a tap that '
      'toggles the switch',
      (WidgetTester tester) async {
        bool value = false;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSwitch(
                  value: value,
                  onChanged: (bool next) => setState(() => value = next),
                );
              },
            ),
          ),
        );

        final double restingWidth = tester.getSize(_thumbFinder()).width;

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSwitch)),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(_thumbFinder()).width, greaterThan(restingWidth));

        await gesture.up();
        await tester.pumpAndSettle();

        // A spring settles close to, but not always bit-for-bit exactly at,
        // its target (pumpAndSettle stops once frame-to-frame change drops
        // below its own tolerance, not once the value is exactly equal), so
        // this compares within a tight tolerance rather than with `==`.
        expect(
          tester.getSize(_thumbFinder()).width,
          closeTo(restingWidth, 0.01),
        );
      },
    );

    testWidgets(
      'returns the thumb to its resting width after a cancelled press, '
      'without toggling the switch',
      (WidgetTester tester) async {
        final List<bool> notifications = <bool>[];
        await tester.pumpWidget(
          _wrap(CruxSwitch(value: false, onChanged: notifications.add)),
        );

        final double restingWidth = tester.getSize(_thumbFinder()).width;

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSwitch)),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(_thumbFinder()).width, greaterThan(restingWidth));

        await gesture.cancel();
        await tester.pumpAndSettle();

        // See the previous test for why this is a tolerance, not `==`.
        expect(
          tester.getSize(_thumbFinder()).width,
          closeTo(restingWidth, 0.01),
        );
        expect(notifications, isEmpty);
      },
    );

    testWidgets(
      'does not widen the thumb while pressed when the switch is disabled',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxSwitch(value: false, onChanged: null)),
        );

        final double restingWidth = tester.getSize(_thumbFinder()).width;

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSwitch)),
        );
        await tester.pumpAndSettle();

        expect(tester.getSize(_thumbFinder()).width, restingWidth);
        expect(tester.takeException(), isNull);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('thumb liquid travel', () {
    testWidgets(
      'mid-flight after a toggle, the thumb is wider and thinner than '
      'resting (stretching toward the destination side)',
      (WidgetTester tester) async {
        bool value = false;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSwitch(
                  value: value,
                  onChanged: (bool next) => setState(() => value = next),
                );
              },
            ),
          ),
        );

        final Size restingSize = tester.getSize(_thumbFinder());

        await tester.tap(find.byType(CruxSwitch));
        // A zero-duration pump first lets the pending setState from the tap
        // actually rebuild and start the springs (which start their
        // tickers at elapsed = 0); only *then* does advancing the clock
        // below move them forward from their start, mirroring
        // button_test.dart's identical two-pump sampling pattern.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final Size midFlightSize = tester.getSize(_thumbFinder());
        expect(midFlightSize.width, greaterThan(restingSize.width));
        expect(midFlightSize.height, lessThan(restingSize.height));
      },
    );

    testWidgets('settles back into a 28x28 circle once the flight finishes', (
      WidgetTester tester,
    ) async {
      bool value = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxSwitch(
                value: value,
                onChanged: (bool next) => setState(() => value = next),
              );
            },
          ),
        ),
      );

      final Size restingSize = tester.getSize(_thumbFinder());

      await tester.tap(find.byType(CruxSwitch));
      await tester.pumpAndSettle();

      // A spring settles close to, but not always bit-for-bit exactly at,
      // its target (see the "thumb stretch" group above for the same
      // observation), so this compares within a tight tolerance rather
      // than with `==`.
      final Size settledSize = tester.getSize(_thumbFinder());
      expect(settledSize.width, closeTo(restingSize.width, 0.01));
      expect(settledSize.height, closeTo(restingSize.height, 0.01));
    });

    testWidgets('rapid re-toggle before the previous flight settles redirects '
        'smoothly instead of jumping or throwing', (WidgetTester tester) async {
      bool value = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxSwitch(
                value: value,
                onChanged: (bool next) => setState(() => value = next),
              );
            },
          ),
        ),
      );

      final Size restingSize = tester.getSize(_thumbFinder());
      final double offCenterX = tester.getCenter(_thumbFinder()).dx;

      // Toggle off -> on, then sample mid-flight (not settled).
      await tester.tap(find.byType(CruxSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // Toggle again (on -> off) while the first flight is still in
      // progress, then let everything settle.
      await tester.tap(find.byType(CruxSwitch));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(value, isFalse);
      expect(tester.getCenter(_thumbFinder()).dx, closeTo(offCenterX, 0.01));
      expect(
        tester.getSize(_thumbFinder()).width,
        closeTo(restingSize.width, 0.01),
      );
      expect(
        tester.getSize(_thumbFinder()).height,
        closeTo(restingSize.height, 0.01),
      );
    });
  });

  group('disabling mid-press (regression)', () {
    testWidgets('does not throw, never invokes onChanged, and settles the '
        'press-stretch back to resting width when onChanged flips from a '
        'callback to null while the finger is still down', (
      WidgetTester tester,
    ) async {
      int calls = 0;

      Widget buildSwitch(ValueChanged<bool>? onChanged) {
        return _wrap(CruxSwitch(value: false, onChanged: onChanged));
      }

      await tester.pumpWidget(buildSwitch((_) => calls++));

      final double restingWidth = tester.getSize(_thumbFinder()).width;

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSwitch)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(tester.getSize(_thumbFinder()).width, greaterThan(restingWidth));

      // Disable the switch while the gesture is still held down, the
      // same way a common "prevent double toggle" pattern would from
      // inside its own onChanged via setState (mirrors button_test.dart
      // and card_test.dart's identical regression test for this same
      // hazard).
      await tester.pumpWidget(buildSwitch(null));

      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(_thumbFinder()).width, closeTo(restingWidth, 0.01));
      expect(calls, 0);
    });
  });

  group('onChanged is a plain optional parameter (not required)', () {
    testWidgets(
      'CruxSwitch can be constructed with no onChanged argument at all '
      'and renders disabled, matching CruxCard/CruxListTile\'s '
      'convention for the same nullable-callback-disables pattern',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxSwitch(value: false)));

        final Container track = tester.widget<Container>(_trackFinder());
        final ShapeDecoration decoration = track.decoration! as ShapeDecoration;
        expect(decoration.color, CruxColors.light.separator);
      },
    );
  });

  group('semantics', () {
    testWidgets('exposes a toggled switch semantics node that follows value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxSwitch(value: true, onChanged: (_) {})),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSwitch));
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);

      handle.dispose();
    });

    testWidgets(
      'exposes a disabled switch semantics node when onChanged is null',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(const CruxSwitch(value: false, onChanged: null)),
        );

        final SemanticsNode node = tester.getSemantics(find.byType(CruxSwitch));
        expect(node.flagsCollection.isToggled, Tristate.isFalse);
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      },
    );
  });
}
