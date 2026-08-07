// Behavior tests for CruxTopFade, per unknowns/navigation-bars.md and
// unknowns/navigation-bars/ledger.md's confirmed progressive-fade spec.
//
// CruxTopFade has no animation of its own (its class doc explains why: it
// is a static mask, not a scroll-position-driven effect), so unlike
// spinner_test.dart or segmented_control_test.dart this file never needs to
// pump specific durations or worry about settling -- every assertion here
// holds on the very first frame.
//
// What's asserted is structural (how many BackdropFilter/ShaderMask layers
// the widget builds for a given blurSigma, and that the blur overlay never
// steals a gesture from the wrapped child) rather than pixel-exact gradient
// values -- the same "assert observable behavior, not internal tuning
// numbers" convention button_test.dart's file doc describes. The confirmed
// layer count (6, see top_fade.dart's `_blurLayerCount`) is asserted as a
// literal here rather than importing a private constant, since
// `lib/src/components/atoms/top_fade.dart`'s privates are not visible
// outside that library.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// The confirmed number of compounding BackdropFilter blur layers
/// CruxTopFade builds whenever `blurSigma > 0` -- see
/// `top_fade.dart`'s `_blurLayerCount` doc for why 6, extracted from
/// `unknowns/navigation-bars/mock-appbar-fade.html`'s own 6 `.blur-layer`
/// divs.
const int _confirmedBlurLayerCount = 6;

/// Wraps [child] with the minimum ancestry CruxTopFade needs to lay out
/// and paint (a [Directionality] plus a fixed-size box, so tests have a
/// known, bounded viewport for the fade band's own `bounds.height`-relative
/// math to resolve against) without pulling in a full app shell -- mirrors
/// button_test.dart's/toast_test.dart's own `_wrap` convention. No
/// [CruxTheme] is provided: CruxTopFade never reads one (it is a pure
/// alpha/blur mask over whatever [child] paints, with no color decoration
/// of its own), so there is nothing here for a theme fallback to matter to.
Widget _wrap(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 400, height: 600, child: child),
  );
}

/// A tall scrollable stand-in for real content: enough rows that the list
/// extends well past the viewport, so a drag can meaningfully move
/// [controller]'s offset.
Widget _demoScrollable(ScrollController controller) {
  return ListView.builder(
    controller: controller,
    itemCount: 60,
    itemBuilder: (BuildContext context, int index) {
      return SizedBox(
        height: 48,
        child: Text('row $index', key: ValueKey<int>(index)),
      );
    },
  );
}

void main() {
  testWidgets('renders its child', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const CruxTopFade(child: Text('hello'))));

    expect(find.text('hello'), findsOneWidget);
  });

  group('blur layers', () {
    testWidgets('the default blurSigma builds the documented layer count of '
        'BackdropFilters', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const CruxTopFade(child: SizedBox.expand())),
      );

      expect(
        find.byType(BackdropFilter),
        findsNWidgets(_confirmedBlurLayerCount),
      );
    });

    testWidgets('blurSigma: 0 builds no BackdropFilter layers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CruxTopFade(blurSigma: 0, child: SizedBox.expand())),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('a smaller explicit blurSigma still builds every layer', (
      WidgetTester tester,
    ) async {
      // Only blurSigma: 0 is documented as the "no layers" escape hatch --
      // any positive value, however small, still builds the full stack of
      // compounding layers (each layer's own radius merely scales down).
      await tester.pumpWidget(
        _wrap(const CruxTopFade(blurSigma: 0.5, child: SizedBox.expand())),
      );

      expect(
        find.byType(BackdropFilter),
        findsNWidgets(_confirmedBlurLayerCount),
      );
    });
  });

  group('ShaderMask', () {
    testWidgets(
      'one ShaderMask drives the alpha fade, plus one per blur layer',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxTopFade(child: SizedBox.expand())),
        );

        // The alpha-fade ShaderMask wrapping the child, plus one
        // decay-mask ShaderMask per compounding blur layer -- see
        // top_fade.dart's class doc for why each blur layer needs its own
        // mask (a BackdropFilter has no built-in way to fade its own
        // effect out; ShaderMask + BlendMode.dstIn is what limits each
        // layer to its own top-to-bottom decay).
        expect(
          find.byType(ShaderMask),
          findsNWidgets(1 + _confirmedBlurLayerCount),
        );
      },
    );

    testWidgets('blurSigma: 0 leaves only the alpha-fade ShaderMask', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CruxTopFade(blurSigma: 0, child: SizedBox.expand())),
      );

      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  group('pointer passthrough', () {
    testWidgets(
      'the blur overlay is wrapped in an actively-ignoring IgnorePointer',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxTopFade(child: _demoScrollable(controller))),
        );

        // Filtered to `ignoring: true` (rather than a bare byType count):
        // ListView's own Scrollable machinery mounts its own unrelated
        // IgnorePointer internally (with `ignoring: false`, i.e. a no-op),
        // so a plain type count would over-count and couple this test to
        // that framework-internal implementation detail. This widget's own
        // overlay is the only one that actually ignores.
        final Iterable<IgnorePointer> ignoring = tester
            .widgetList<IgnorePointer>(find.byType(IgnorePointer))
            .where((IgnorePointer widget) => widget.ignoring);

        expect(ignoring, hasLength(1));
      },
    );

    testWidgets('blurSigma: 0 (no overlay at all) has no actively-ignoring '
        'IgnorePointer', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxTopFade(blurSigma: 0, child: _demoScrollable(controller))),
      );

      final Iterable<IgnorePointer> ignoring = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .where((IgnorePointer widget) => widget.ignoring);

      expect(ignoring, isEmpty);
    });

    testWidgets(
      'a drag starting inside the fade band still scrolls the wrapped '
      'child (the overlay never steals the gesture)',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxTopFade(child: _demoScrollable(controller))),
        );

        expect(controller.offset, 0);

        // Starts the drag well inside the top fade band (well under its
        // 160px height) -- this is exactly the region the blur overlay's
        // layers paint over. If IgnorePointer were missing (or misplaced),
        // this point would hit the overlay instead of the ListView beneath
        // it, and the drag below would never move the ScrollController.
        final Offset bandPoint =
            tester.getTopLeft(find.byType(CruxTopFade)) +
            const Offset(50, 40);
        final TestGesture gesture = await tester.startGesture(bandPoint);
        await gesture.moveBy(const Offset(0, -300));
        await tester.pump();
        await gesture.up();

        expect(controller.offset, greaterThan(0));
      },
    );
  });

  testWidgets('renders without a MediaQuery ancestor', (
    WidgetTester tester,
  ) async {
    // CruxTopFade's fade/blur math is derived entirely from its own
    // rendered size (via ShaderMask's shaderCallback bounds), never from
    // MediaQuery -- so _wrap's bare Directionality (no MediaQuery above
    // it) is exactly the ancestry it needs.
    await tester.pumpWidget(
      _wrap(const CruxTopFade(child: Text('no media query'))),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('no media query'), findsOneWidget);
  });

  group('short content (shorter than the fade band)', () {
    testWidgets('renders without throwing when the child is under 160px', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 80,
              child: CruxTopFade(child: SizedBox.expand()),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CruxTopFade), findsOneWidget);
    });
  });
}
