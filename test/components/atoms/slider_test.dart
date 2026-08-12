// Behavior tests for CruxSlider, the package's first horizontal-drag
// component. Per plans/atoms-batch-3.md's "Slider" test seam, these tests
// fix the *observable* contract only: onChanged updates monotonically while
// dragging, min/max clamping, that a `divisions`-snapped slider only ever
// reports grid values, disabled unresponsiveness, the 44 logical pixel tap
// target, the increase/decrease semantics actions, and that the value bubble
// only shows up while dragging. Exact pixel geometry (thumb size, track
// position) is a visual detail checked in the example app / widgetbook, not
// asserted here -- per the plan's "avoid frame-precise pixel-tied
// assertions" instruction, expected values below are always computed from
// the public min/max/divisions contract (or as a directional/monotonic
// comparison), never from this file's own copy of the pixel-to-value
// formula, so a test can't tautologically validate the implementation
// against itself.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxSlider needs to lay out and
/// paint (a [Directionality]), without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light] (same convention as
/// switch_test.dart / checkbox_test.dart).
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// Wraps [child] in a fixed-width box, since CruxSlider (like Flutter's own
/// Slider) expects a bounded width from its parent rather than sizing itself
/// intrinsically.
Widget _wrapSized(Widget child, {double width = 300}) {
  return _wrap(SizedBox(width: width, child: child));
}

/// Finds the single [Opacity] widget CruxSlider renders -- the value
/// bubble's visibility toggle. Mirrors switch_test.dart's [_trackFinder]
/// (structural, not key-based) in spirit: CruxSlider's implementation uses
/// [Opacity] for nothing else, matching button.dart's identical
/// "Opacity while loading" precedent for an instant (unanimated)
/// show/hide toggle.
Finder _bubbleOpacityFinder() => find.byType(Opacity);

/// Invokes [action] on [node] via the [SemanticsOwner] that actually owns
/// it. `tester.binding.pipelineOwner` (the obvious spot) is deprecated in
/// favor of `RendererBinding.rootPipelineOwner`, but that root owner sits
/// *above* the per-[RenderView] owner an ordinary single-view widget test's
/// semantics tree is actually attached to -- `performAction` on the root is
/// silently a no-op for a node owned by a child. `tester.binding.renderViews
/// .single.owner!.semanticsOwner!` is the same non-deprecated owner
/// `WidgetTester.getSemantics` itself reads through internally (confirmed
/// against the Flutter 3.44.6 SDK's `flutter_test/src/finders.dart`, whose
/// `_SemanticsLocator` reads `renderView.owner!.semanticsOwner!.
/// rootSemanticsNode!`), so it is guaranteed to be the correct target for a
/// node [tester.getSemantics] just returned.
void _performSemanticsAction(
  WidgetTester tester,
  SemanticsNode node,
  SemanticsAction action,
) {
  tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
    node.id,
    action,
  );
}

/// Finds the thumb cap's own [BoxShadow] stack, structural (not key-based)
/// like [_bubbleOpacityFinder] above. CruxSlider renders several
/// [DecoratedBox]es (the track, the fill, each division tick, the value
/// bubble, and the thumb cap itself), but the thumb cap is the only one
/// whose [ShapeDecoration] ever sets a non-empty `shadows` list -- the
/// track/fill/bubble decorations never set `shadows` at all (so it reads
/// `null`), and the division ticks use a plain [BoxDecoration], not a
/// [ShapeDecoration]. That makes "has a non-empty `shadows` list" a safe,
/// implementation-detail-free way to pick out the thumb cap's decoration
/// specifically without depending on tree order or a pixel-tied geometry
/// check.
List<BoxShadow> _thumbCapShadows(WidgetTester tester) {
  final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  );
  for (final DecoratedBox box in boxes) {
    final Decoration decoration = box.decoration;
    if (decoration is ShapeDecoration &&
        decoration.shadows != null &&
        decoration.shadows!.isNotEmpty) {
      return decoration.shadows!;
    }
  }
  fail(
    'CruxSlider: no DecoratedBox with a non-empty shadows list found '
    '-- expected the thumb cap to have one.',
  );
}

void main() {
  group('dragging updates the value', () {
    testWidgets('dragging right increases the value monotonically', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: values.add)),
      );

      await tester.drag(find.byType(CruxSlider), const Offset(100, 0));
      await tester.pump();

      expect(values, isNotEmpty);
      expect(values.last, greaterThan(50));
    });

    testWidgets('dragging left decreases the value monotonically', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: values.add)),
      );

      await tester.drag(find.byType(CruxSlider), const Offset(-100, 0));
      await tester.pump();

      expect(values, isNotEmpty);
      expect(values.last, lessThan(50));
    });
  });

  group('min/max clamping', () {
    testWidgets('dragging far past the right edge clamps to max', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: values.add)),
      );

      await tester.drag(find.byType(CruxSlider), const Offset(10000, 0));
      await tester.pump();

      expect(values.last, 100);
    });

    testWidgets('dragging far past the left edge clamps to min', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: values.add)),
      );

      await tester.drag(find.byType(CruxSlider), const Offset(-10000, 0));
      await tester.pump();

      expect(values.last, 0);
    });
  });

  group('track tap', () {
    testWidgets('tapping near the left edge moves the value down', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: values.add)),
      );

      final Offset topLeft = tester.getTopLeft(find.byType(CruxSlider));
      await tester.tapAt(topLeft + const Offset(5, 22));
      await tester.pump();

      expect(values, isNotEmpty);
      expect(values.last, lessThan(50));
    });

    testWidgets('tapping near the right edge moves the value up', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: values.add)),
      );

      final Offset topRight = tester.getTopRight(find.byType(CruxSlider));
      await tester.tapAt(topRight + const Offset(-5, 22));
      await tester.pump();

      expect(values, isNotEmpty);
      expect(values.last, greaterThan(50));
    });
  });

  group('divisions snap the reported value', () {
    testWidgets(
      'every onChanged value during a drag lands exactly on a division',
      (WidgetTester tester) async {
        final List<double> values = <double>[];
        await tester.pumpWidget(
          _wrapSized(
            CruxSlider(
              value: 50,
              max: 100,
              divisions: 4, // grid: 0, 25, 50, 75, 100
              onChanged: values.add,
            ),
          ),
        );

        const List<double> grid = <double>[0, 25, 50, 75, 100];

        final TestGesture gesture = await tester.startGesture(
          tester.getTopLeft(find.byType(CruxSlider)) + const Offset(10, 22),
        );
        await tester.pump();
        for (final double dx in <double>[37, 71, 133, 210, 260, 3]) {
          await gesture.moveBy(Offset(dx, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(values, isNotEmpty);
        for (final double value in values) {
          expect(grid, contains(value));
        }
      },
    );
  });

  group('disabled', () {
    testWidgets(
      'dragging a disabled slider never calls onChanged and does not throw',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrapSized(const CruxSlider(value: 50, onChanged: null)),
        );

        await tester.drag(find.byType(CruxSlider), const Offset(100, 0));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'disabling mid-drag stops further onChanged calls without throwing',
      (WidgetTester tester) async {
        double value = 50;
        int calls = 0;
        ValueChanged<double>? onChanged = (double next) {
          calls++;
          value = next;
        };

        late StateSetter setState;
        await tester.pumpWidget(
          _wrapSized(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setter) {
                setState = setter;
                return CruxSlider(value: value, onChanged: onChanged);
              },
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSlider)),
        );
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();

        expect(calls, greaterThan(0));
        final int callsBeforeDisable = calls;

        setState(() => onChanged = null);
        await tester.pump();

        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(calls, callsBeforeDisable);
      },
    );
  });

  group('tap target', () {
    testWidgets('keeps a 44 logical pixel minimum tap height', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, onChanged: (double _) {})),
      );

      final Size size = tester.getSize(find.byType(CruxSlider));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets(
      'the whole 44-tall band (not just the visible track) is tappable',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrapSized(CruxSlider(value: 50, onChanged: (double _) => calls++)),
        );

        final Offset topLeft = tester.getTopLeft(find.byType(CruxSlider));
        // 2 logical pixels from the top edge: outside the 6px visible
        // track (vertically centered within the 44-tall hit area), but
        // still inside the 44-tall tap target.
        await tester.tapAt(topLeft + const Offset(150, 2));
        await tester.pump();

        expect(calls, 1);
      },
    );
  });

  group('value bubble', () {
    testWidgets('is hidden while at rest', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, onChanged: (double _) {})),
      );

      final Opacity bubble = tester.widget<Opacity>(_bubbleOpacityFinder());
      expect(bubble.opacity, 0);
    });

    testWidgets('becomes visible while dragging and hides again on release', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, onChanged: (double _) {})),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSlider)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      final Opacity midDrag = tester.widget<Opacity>(_bubbleOpacityFinder());
      expect(midDrag.opacity, 1);

      await gesture.up();
      await tester.pump();

      final Opacity afterRelease = tester.widget<Opacity>(
        _bubbleOpacityFinder(),
      );
      expect(afterRelease.opacity, 0);
    });
  });

  group('thumb shadow', () {
    testWidgets('the thumb cap uses CruxShadows.thumb at rest and switches to '
        'CruxShadows.thumbLifted while dragging, per the confirmed spec\'s '
        '"つまみ専用の一段濃い輪郭寄り影 ... ドラッグ中はさらに浮く"', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: (double _) {})),
      );

      expect(_thumbCapShadows(tester), CruxShadows.light.thumb);

      // Mirrors the "value bubble" group's drag pattern above: a plain
      // startGesture+pump with no movement resolves as an ambiguous tap
      // (CruxSlider's GestureDetector has both tap and horizontal-drag
      // recognizers racing in the same gesture arena -- see this file's
      // top-of-class wiring comment), not yet a drag, so `_dragging` only
      // flips to true once the pointer actually moves past touch slop and
      // the drag recognizer wins.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSlider)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      expect(_thumbCapShadows(tester), CruxShadows.light.thumbLifted);

      await gesture.up();
      await tester.pump();

      expect(_thumbCapShadows(tester), CruxShadows.light.thumb);
    });

    testWidgets(
      'in dark mode, the thumb cap uses CruxShadows.dark.thumb at rest '
      'and CruxShadows.dark.thumbLifted while dragging',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxTheme(
              data: CruxThemeData.dark(),
              child: SizedBox(
                width: 300,
                child: CruxSlider(
                  value: 50,
                  max: 100,
                  onChanged: (double _) {},
                ),
              ),
            ),
          ),
        );

        expect(_thumbCapShadows(tester), CruxShadows.dark.thumb);

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSlider)),
        );
        await tester.pump();
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();

        expect(_thumbCapShadows(tester), CruxShadows.dark.thumbLifted);

        await gesture.up();
        await tester.pump();

        expect(_thumbCapShadows(tester), CruxShadows.dark.thumb);
      },
    );
  });

  group('programmatic value changes spring instead of teleporting', () {
    testWidgets(
      'a value change while at rest springs toward the new position over '
      'several frames rather than jumping there on the very next frame',
      (WidgetTester tester) async {
        double value = 0;
        late StateSetter setState;
        await tester.pumpWidget(
          _wrapSized(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setter) {
                setState = setter;
                return CruxSlider(
                  value: value,
                  max: 100,
                  onChanged: (double _) {},
                );
              },
            ),
          ),
        );

        final double restingX = tester.getCenter(find.byType(CustomPaint)).dx;

        setState(() => value = 100);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final double midFlightX = tester.getCenter(find.byType(CustomPaint)).dx;

        await tester.pumpAndSettle();
        final double settledX = tester.getCenter(find.byType(CustomPaint)).dx;

        expect(settledX, greaterThan(restingX));
        // If the position teleported instead of springing, midFlightX would
        // already equal settledX one frame after the value changed.
        expect(midFlightX, greaterThan(restingX));
        expect(midFlightX, lessThan(settledX));
      },
    );

    testWidgets(
      'releasing a drag does not jump the thumb before any further value '
      'change (the spring picks up from the drag'
      "'"
      's ending position)',
      (WidgetTester tester) async {
        double value = 50;
        await tester.pumpWidget(
          _wrapSized(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setter) {
                return CruxSlider(
                  value: value,
                  max: 100,
                  onChanged: (double next) => setter(() => value = next),
                );
              },
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSlider)),
        );
        await tester.pump();
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();

        final double duringDragX = tester
            .getCenter(find.byType(CustomPaint))
            .dx;

        await gesture.up();
        await tester.pump();

        final double justAfterReleaseX = tester
            .getCenter(find.byType(CustomPaint))
            .dx;

        expect(justAfterReleaseX, closeTo(duringDragX, 0.5));
      },
    );
  });

  group('RTL mirrors the drag direction and layout', () {
    testWidgets(
      'dragging right decreases the value in RTL (mirrored from LTR, where '
      'the same drag increases it)',
      (WidgetTester tester) async {
        final List<double> values = <double>[];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 300,
              child: CruxSlider(value: 50, max: 100, onChanged: values.add),
            ),
          ),
        );

        await tester.drag(find.byType(CruxSlider), const Offset(100, 0));
        await tester.pump();

        expect(values, isNotEmpty);
        expect(values.last, lessThan(50));
      },
    );

    testWidgets('at the max value, the thumb renders on the left half in RTL '
        '(mirrored from where LTR renders it, on the right half)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 300,
            child: CruxSlider(value: 100, max: 100, onChanged: (double _) {}),
          ),
        ),
      );

      final double thumbX = tester.getCenter(find.byType(CustomPaint)).dx;
      final double sliderLeftX = tester.getTopLeft(find.byType(CruxSlider)).dx;
      final double sliderWidth = tester.getSize(find.byType(CruxSlider)).width;

      expect(thumbX, lessThan(sliderLeftX + sliderWidth / 2));
    });
  });

  group('unbounded width', () {
    testWidgets(
      'throws a clear assertion instead of a layout crash when given an '
      'unbounded width (e.g. placed directly inside a Row with no Expanded)',
      (WidgetTester tester) async {
        // Placing CruxSlider directly inside a Row with no Expanded gives
        // its LayoutBuilder an unbounded width -- the exact scenario the
        // assertion under test guards against. That unbounded width also
        // makes the surrounding RenderFlex itself report its own
        // (unrelated, cascading) overflow error once CruxSlider's own
        // layout fails, so `tester.takeException()` -- which can only ever
        // hand back one exception -- would report flutter_test's own
        // "Multiple exceptions (2) were detected" placeholder instead of
        // either underlying error. FlutterError.onError is swapped out for
        // the duration of this one pump so every error raised during it is
        // captured individually instead of being collapsed.
        final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
        final void Function(FlutterErrorDetails)? previousOnError =
            FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(
            _wrap(
              Row(
                children: <Widget>[
                  CruxSlider(value: 50, onChanged: (double _) {}),
                ],
              ),
            ),
          );
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(errors, isNotEmpty);
        expect(errors.first.exception, isA<AssertionError>());
        expect(errors.first.exception.toString(), contains('CruxSlider'));
      },
    );
  });

  group('disabling mid-drag (behavior)', () {
    testWidgets(
      'freezes the thumb at the last confirmed value and ignores further '
      'drag movement once onChanged flips to null mid-drag',
      (WidgetTester tester) async {
        double value = 50;
        ValueChanged<double>? onChanged = (double next) {
          value = next;
        };

        late StateSetter setState;
        await tester.pumpWidget(
          _wrapSized(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setter) {
                setState = setter;
                return CruxSlider(value: value, max: 100, onChanged: onChanged);
              },
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxSlider)),
        );
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();

        final double xWhileEnabled = tester
            .getCenter(find.byType(CustomPaint))
            .dx;

        setState(() => onChanged = null);
        await tester.pump();

        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();

        final double xAfterDisabledMove = tester
            .getCenter(find.byType(CustomPaint))
            .dx;

        expect(tester.takeException(), isNull);
        expect(xAfterDisabledMove, closeTo(xWhileEnabled, 0.5));

        await gesture.up();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('onChangeStart / onChangeEnd', () {
    testWidgets('fires onChangeStart once and onChangeEnd once per drag', (
      WidgetTester tester,
    ) async {
      int startCalls = 0;
      int endCalls = 0;
      await tester.pumpWidget(
        _wrapSized(
          CruxSlider(
            value: 50,
            onChanged: (double _) {},
            onChangeStart: (double _) => startCalls++,
            onChangeEnd: (double _) => endCalls++,
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSlider)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      expect(startCalls, 1);
      expect(endCalls, 0);

      await gesture.up();
      await tester.pump();

      expect(startCalls, 1);
      expect(endCalls, 1);
    });
  });

  group('semantics', () {
    testWidgets('exposes an adjustable slider semantics node', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, onChanged: (double _) {})),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      expect(node.flagsCollection.isSlider, isTrue);

      handle.dispose();
    });

    testWidgets('the increase action raises the value by 10% of the range when '
        'continuous', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      double value = 50;
      await tester.pumpWidget(
        _wrapSized(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxSlider(
                value: value,
                max: 100,
                onChanged: (double next) => setState(() => value = next),
              );
            },
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      _performSemanticsAction(tester, node, SemanticsAction.increase);
      await tester.pump();

      expect(value, 60);

      handle.dispose();
    });

    testWidgets('the decrease action steps by exactly one division', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      double value = 50;
      await tester.pumpWidget(
        _wrapSized(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxSlider(
                value: value,
                max: 100,
                divisions: 4, // grid: 0, 25, 50, 75, 100
                onChanged: (double next) => setState(() => value = next),
              );
            },
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      _performSemanticsAction(tester, node, SemanticsAction.decrease);
      await tester.pump();

      expect(value, 25);

      handle.dispose();
    });

    testWidgets('exposes a disabled semantics node when onChanged is null', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrapSized(const CruxSlider(value: 50, onChanged: null)),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);

      handle.dispose();
    });
  });

  group('default value formatting (codex review item 1)', () {
    // Confirmed against the Flutter 3.44.6 SDK's material/slider.dart,
    // `_RenderSlider.describeSemanticsConfiguration`'s no-formatter branch:
    // `config.value = '${(value * 100).round()}%'`, where `value` there is
    // already the 0..1 fraction, i.e. Material's own default is "percentage
    // of the range", not "round the raw value". CruxSlider's default used
    // to be `value.round().toString()`, which on the default 0.0..1.0 range
    // reads every value below 0.5 as "0" and everything from 0.5 up as "1".
    testWidgets(
      'defaults to a rounded percentage of the min..max range, not the '
      'raw value rounded to the nearest integer',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrapSized(
            CruxSlider(value: 0.42, onChanged: (double _) {}),
          ), // default min 0.0, max 1.0
        );

        final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
        expect(node.value, '42%');

        handle.dispose();
      },
    );

    testWidgets(
      'formats the percentage relative to a non-default min..max range',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrapSized(CruxSlider(value: 25, max: 200, onChanged: (double _) {})),
        );

        final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
        expect(node.value, '13%'); // 25 / 200 = 12.5% -> rounds to 13%

        handle.dispose();
      },
    );

    testWidgets(
      'still uses a provided valueLabelBuilder instead of the default '
      'percentage format',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrapSized(
            CruxSlider(
              value: 50,
              max: 100,
              valueLabelBuilder: (double value) => '${value.round()}pt',
              onChanged: (double _) {},
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
        expect(node.value, '50pt');

        handle.dispose();
      },
    );

    testWidgets('the drag bubble also uses the default percentage format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: 50, max: 100, onChanged: (double _) {})),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSlider)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      final Text bubbleText = tester.widget<Text>(
        find.descendant(
          of: _bubbleOpacityFinder(),
          matching: find.byType(Text),
        ),
      );
      expect(bubbleText.data, endsWith('%'));

      await gesture.up();
      await tester.pump();
    });
  });

  group('out-of-range value handling (codex review item 2)', () {
    testWidgets(
      'a value above max is clamped for the semantics announcement, not '
      'reported as a raw over-range percentage',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrapSized(
            CruxSlider(value: 150, max: 100, onChanged: (double _) {}),
          ),
        );

        final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
        expect(node.value, '100%');

        handle.dispose();
      },
    );

    testWidgets('a value below min is clamped for the semantics announcement', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrapSized(CruxSlider(value: -50, max: 100, onChanged: (double _) {})),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      expect(node.value, '0%');

      handle.dispose();
    });

    // The two tests above pass a raw, un-clamped value through
    // `_fractionFromValue` (the default percentage formatter's own
    // clamping), which would mask a bug in the *display value* itself
    // still being un-clamped -- a caller-supplied `valueLabelBuilder`
    // (exactly what `example/lib/screens/settings_screen.dart` uses for
    // both of its sliders) receives the value directly with no such
    // internal clamp, so it is the one path that actually proves the
    // *widget* clamps before handing a value to any formatter, default or
    // custom.
    testWidgets('a value above max is clamped before being handed to a custom '
        'valueLabelBuilder, not passed through raw', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrapSized(
          CruxSlider(
            value: 150,
            max: 100,
            valueLabelBuilder: (double value) => value.toStringAsFixed(1),
            onChanged: (double _) {},
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      expect(node.value, '100.0');

      handle.dispose();
    });

    testWidgets('a value below min is clamped before being handed to a custom '
        'valueLabelBuilder', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrapSized(
          CruxSlider(
            value: -50,
            max: 100,
            valueLabelBuilder: (double value) => value.toStringAsFixed(1),
            onChanged: (double _) {},
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(CruxSlider));
      expect(node.value, '0.0');

      handle.dispose();
    });

    testWidgets(
      'a non-finite value fails a clear assertion instead of throwing '
      'deep inside value formatting',
      (WidgetTester tester) async {
        expect(
          () => CruxSlider(value: double.nan, onChanged: (double _) {}),
          throwsA(
            isA<AssertionError>().having(
              (AssertionError e) => e.toString(),
              'message',
              contains('CruxSlider'),
            ),
          ),
        );
      },
    );
  });

  group('disabling mid-drag ends the interaction immediately (codex review '
      'item 3)', () {
    testWidgets('hides the bubble and drops the lifted thumb shadow as soon as '
        'onChanged flips to null mid-drag, with no further pointer movement, '
        'and suppresses onChangeEnd on release', (WidgetTester tester) async {
      ValueChanged<double>? onChanged = (double _) {};
      int endCalls = 0;

      late StateSetter setState;
      await tester.pumpWidget(
        _wrapSized(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setter) {
              setState = setter;
              return CruxSlider(
                value: 50,
                max: 100,
                onChanged: onChanged,
                onChangeEnd: (double _) => endCalls++,
              );
            },
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CruxSlider)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      // Sanity check: dragging actually started.
      expect(tester.widget<Opacity>(_bubbleOpacityFinder()).opacity, 1);
      expect(_thumbCapShadows(tester), CruxShadows.light.thumbLifted);

      setState(() => onChanged = null);
      await tester.pump();

      // No further move event delivered yet -- the interaction must
      // already have ended right here.
      expect(tester.widget<Opacity>(_bubbleOpacityFinder()).opacity, 0);
      expect(_thumbCapShadows(tester), CruxShadows.light.thumb);

      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(endCalls, 0);
    });
  });

  group('onChangeStart reports the pre-interaction value (codex review '
      'item 4)', () {
    testWidgets(
      'a track tap passes onChangeStart the value from before the tap, '
      'not the value at the tapped position',
      (WidgetTester tester) async {
        final List<double> startValues = <double>[];
        final List<double> changedValues = <double>[];
        await tester.pumpWidget(
          _wrapSized(
            CruxSlider(
              value: 50,
              max: 100,
              onChanged: changedValues.add,
              onChangeStart: startValues.add,
            ),
          ),
        );

        final Offset topRight = tester.getTopRight(find.byType(CruxSlider));
        await tester.tapAt(topRight + const Offset(-5, 22));
        await tester.pump();

        expect(startValues, <double>[50]);
        expect(changedValues, isNotEmpty);
        expect(changedValues.last, greaterThan(50));
      },
    );

    testWidgets('a drag start also passes onChangeStart the pre-drag value', (
      WidgetTester tester,
    ) async {
      final List<double> startValues = <double>[];
      await tester.pumpWidget(
        _wrapSized(
          CruxSlider(
            value: 50,
            max: 100,
            onChanged: (double _) {},
            onChangeStart: startValues.add,
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(CruxSlider)) + const Offset(5, 22),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(startValues, <double>[50]);
    });
  });
}
