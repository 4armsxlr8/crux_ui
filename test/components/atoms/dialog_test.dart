// Behavior tests for CruxDialogCard (the "blank card" layer) and
// CruxDialog.show (the floating card + scrim + open/close animation
// layer), per plans/atoms-batch-3.md and the confirmed shape in
// unknowns/atoms-batch-3/ledger.md. Following button_test.dart's own file
// doc convention: animated "how bouncy does it feel" fine-tuning is not
// asserted at frame-exact precision here (see the "entrance animation"
// group), matching the plan's explicit "assert behavior, not frame-exact
// spring values" instruction.
import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry a [CruxDialog.show] caller
/// needs: a [Directionality], a fixed-size box (so the scrim's full-screen
/// coverage is a known, tappable size rather than whatever the test
/// binding's default surface happens to be), and -- critically -- a bare
/// [Overlay] with no [Navigator]/`MaterialApp` involved at all. This is the
/// "verify from under a bare Overlay" ability the plan calls out as a hard
/// requirement for CruxDialog's display mechanism (see
/// unknowns/session-handoff-2026-07-26.md's Overlay pitfalls): [child] is
/// built as that Overlay's own initial entry, so a [BuildContext] taken from
/// inside it can call `Overlay.of(context)` and find this same Overlay --
/// exactly the mechanism [CruxDialog.show] itself uses.
Widget _wrap(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 400,
      height: 800,
      child: Overlay(
        initialEntries: <OverlayEntry>[OverlayEntry(builder: (_) => child)],
      ),
    ),
  );
}

/// A trigger widget: opens a [CruxDialog] built from [builder] when its
/// 44x44 tap target is tapped, using the [BuildContext] it is built with (a
/// descendant of the [Overlay] in [_wrap]). Exposes an accessible label so
/// modal-semantics tests can check whether it is still reachable via
/// `find.semantics.byLabel` once a dialog is open on top of it.
class _OpenTrigger extends StatelessWidget {
  const _OpenTrigger({
    required this.builder,
    this.barrierDismissible = true,
    this.routeSemanticLabel,
  });

  final Widget Function(BuildContext context, VoidCallback close) builder;
  final bool barrierDismissible;
  final String? routeSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'open trigger',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => CruxDialog.show(
          context,
          barrierDismissible: barrierDismissible,
          routeSemanticLabel: routeSemanticLabel,
          builder: builder,
        ),
        child: const SizedBox(width: 44, height: 44),
      ),
    );
  }
}

void main() {
  group('CruxDialogCard (static, unfloated card body)', () {
    testWidgets(
      'renders its child directly with no Overlay, scrim, or animation '
      'ancestry -- must be paintable entirely on its own for golden use',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: CruxDialogCard(
                child: Text('内容', textDirection: TextDirection.ltr),
              ),
            ),
          ),
        );

        expect(find.byType(CruxDialogCard), findsOneWidget);
        expect(find.text('内容'), findsOneWidget);
        expect(find.byType(Overlay), findsNothing);
      },
    );

    testWidgets('paints the theme surface color, a superellipse shape with no '
        'border, and the large shadow token -- in both light and dark, '
        'matching the confirmed "scrim draws the edge, no hairline here" '
        'decision', (WidgetTester tester) async {
      for (final CruxThemeData theme in <CruxThemeData>[
        CruxThemeData.light(),
        CruxThemeData.dark(),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxTheme(
              data: theme,
              child: Center(
                child: CruxDialogCard(child: SizedBox(width: 40, height: 40)),
              ),
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

        expect(decoration.color, theme.colors.surface);
        expect(shape.side, BorderSide.none);
        expect(decoration.shadows, theme.shadows.lg);
      }
    });

    testWidgets(
      'caps its own width at 340 logical pixels even inside a much wider '
      'parent, matching mock case B\'s `min(340px, 100%)`',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 1000,
              child: Center(
                child: CruxDialogCard(
                  child: SizedBox(width: 900, height: 40),
                ),
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(CruxDialogCard));
        expect(size.width, lessThanOrEqualTo(340));
      },
    );

    testWidgets(
      'applies the mock\'s 24/24/24/20 padding by default around its child',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: CruxDialogCard(child: SizedBox(width: 40, height: 40)),
            ),
          ),
        );

        final Container container = tester.widget<Container>(
          find.byType(Container),
        );
        expect(container.padding, const EdgeInsets.fromLTRB(24, 24, 24, 20));
      },
    );
  });

  group('CruxDialog.show (floating card + scrim)', () {
    testWidgets('opening renders both a card and a full-screen scrim', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _OpenTrigger(
            builder: (BuildContext context, VoidCallback close) =>
                const Text('dialog content', textDirection: TextDirection.ltr),
          ),
        ),
      );

      expect(find.byType(CruxDialogCard), findsNothing);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(find.byType(CruxDialogCard), findsOneWidget);
      expect(find.text('dialog content'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is ColoredBox &&
              widget.color == CruxThemeData.light().shadows.scrim,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'opening under CruxThemeData.dark() paints the scrim with the dark '
      'theme\'s own scrim color, not the light one',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          CruxTheme(
            data: CruxThemeData.dark(),
            child: _wrap(
              _OpenTrigger(
                builder: (BuildContext context, VoidCallback close) =>
                    const Text(
                      'dialog content',
                      textDirection: TextDirection.ltr,
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(find.byType(CruxDialogCard), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is ColoredBox &&
                widget.color == CruxThemeData.dark().shadows.scrim,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'captures the CruxTheme from the show() call site, not whatever '
      'theme happens to sit above the Overlay -- so a caller nested under '
      'its own local dark CruxTheme gets a dark card even when the '
      'Overlay itself has no ambient theme (falls back to light)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxTheme(
              data: CruxThemeData.dark(),
              child: _OpenTrigger(
                builder: (BuildContext context, VoidCallback close) =>
                    const Text(
                      'dialog content',
                      textDirection: TextDirection.ltr,
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(find.byType(CruxDialogCard), findsOneWidget);
        final Container container = tester.widget<Container>(
          find.descendant(
            of: find.byType(CruxDialogCard),
            matching: find.byType(Container),
          ),
        );
        final ShapeDecoration decoration =
            container.decoration! as ShapeDecoration;
        expect(decoration.color, CruxThemeData.dark().colors.surface);
      },
    );

    testWidgets(
      'tapping the scrim closes the dialog once the exit fade finishes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              builder: (BuildContext context, VoidCallback close) => const Text(
                'dialog content',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        // Tap far from the centered card (which caps at 340 wide on this
        // 400-wide surface) so the tap can only land on the scrim.
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();

        expect(find.byType(CruxDialogCard), findsNothing);
      },
    );

    testWidgets(
      'ignores pointer events across the whole floating layer (scrim and '
      'card alike) once the exit fade has started, so a second, fast tap '
      'while a dialog is closing cannot reach a still-mounted action inside '
      'the card',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              builder: (BuildContext context, VoidCallback close) => const Text(
                'dialog content',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();
        expect(find.byType(CruxDialogCard), findsOneWidget);
        // Not yet closing: nothing should be pointer-ignoring.
        expect(find.byType(IgnorePointer), findsNothing);

        // Tap the scrim to start the exit fade.
        await tester.tapAt(const Offset(8, 8));
        await tester.pump();

        final IgnorePointer ignorePointer = tester.widget<IgnorePointer>(
          find.byType(IgnorePointer),
        );
        expect(ignorePointer.ignoring, isTrue);
        // The card (and whatever the caller put in it) must sit inside the
        // ignoring subtree, not beside it -- otherwise a tap could still
        // reach it during the fade.
        expect(
          find.descendant(
            of: find.byType(IgnorePointer),
            matching: find.byType(CruxDialogCard),
          ),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'barrierDismissible: false ignores scrim taps, keeping the dialog open',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              barrierDismissible: false,
              builder: (BuildContext context, VoidCallback close) => const Text(
                'dialog content',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();

        expect(find.byType(CruxDialogCard), findsOneWidget);
      },
    );

    testWidgets(
      'closes when the builder\'s own close callback is invoked, e.g. from '
      'a Cancel affordance placed by the caller',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              builder: (BuildContext context, VoidCallback close) {
                return GestureDetector(
                  key: const ValueKey('closeFromContent'),
                  behavior: HitTestBehavior.opaque,
                  onTap: close,
                  child: const SizedBox(width: 44, height: 44),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        // Let the entrance spring fully settle before locating/tapping the
        // close target below: while mid-flight, the card's Transform.scale
        // is not yet exactly 1.0, and computing a tap offset from a
        // not-quite-settled scale can miss the target by a sub-pixel margin.
        await tester.pumpAndSettle();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('closeFromContent')));
        await tester.pumpAndSettle();

        expect(find.byType(CruxDialogCard), findsNothing);
      },
    );

    testWidgets('blocks the background from the semantics tree and scopes the '
        'dialog content as its own route while open (modal semantics)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          _OpenTrigger(
            builder: (BuildContext context, VoidCallback close) =>
                const Text('dialog content', textDirection: TextDirection.ltr),
          ),
        ),
      );

      // find.semantics.byLabel walks the actual *compiled* SemanticsNode
      // tree (unlike find.bySemanticsLabel, which inspects each
      // RenderObject's own locally-owned debugSemantics and so cannot see
      // BlockSemantics's effect -- BlockSemantics only changes whether a
      // node is *included* when an ancestor compiles its children, it
      // does not stop the blocked node from independently owning a
      // SemanticsNode).
      expect(find.semantics.byLabel('open trigger'), findsOne);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // The trigger behind the scrim must no longer be reachable via the
      // compiled semantics tree once the dialog is open.
      expect(find.semantics.byLabel('open trigger'), findsNothing);

      final List<Semantics> scopesRouteWidgets = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((Semantics s) => s.properties.scopesRoute == true)
          .toList();
      expect(scopesRouteWidgets, isNotEmpty);

      handle.dispose();
    });

    testWidgets(
      'always marks the dialog route with the dialog semantics role, and '
      'additionally names the route when routeSemanticLabel is supplied',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              routeSemanticLabel: '下書きを削除しますか？',
              builder: (BuildContext context, VoidCallback close) => const Text(
                'dialog content',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        final Semantics scopesRouteWidget = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((Semantics s) => s.properties.scopesRoute == true);
        expect(scopesRouteWidget.properties.role, SemanticsRole.dialog);
        expect(scopesRouteWidget.properties.namesRoute, isTrue);
        expect(scopesRouteWidget.properties.label, '下書きを削除しますか？');

        handle.dispose();
      },
    );

    testWidgets(
      'still marks the dialog semantics role when routeSemanticLabel is '
      'left null, just without naming the route',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              builder: (BuildContext context, VoidCallback close) => const Text(
                'dialog content',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        final Semantics scopesRouteWidget = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((Semantics s) => s.properties.scopesRoute == true);
        expect(scopesRouteWidget.properties.role, SemanticsRole.dialog);
        expect(scopesRouteWidget.properties.namesRoute, isNot(isTrue));

        handle.dispose();
      },
    );

    testWidgets(
      'a close callback captured while the dialog was open does nothing '
      '(no setState-after-dispose crash) once the whole tree -- Overlay '
      'included -- has been torn down without going through it',
      (WidgetTester tester) async {
        late VoidCallback capturedClose;
        await tester.pumpWidget(
          _wrap(
            _OpenTrigger(
              builder: (BuildContext context, VoidCallback close) {
                capturedClose = close;
                return const Text(
                  'dialog content',
                  textDirection: TextDirection.ltr,
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        // Replace the entire tree (including the Overlay this dialog lives
        // in), disposing the dialog's State out from under the still-held
        // close callback -- without ever calling it or tapping the scrim.
        await tester.pumpWidget(const SizedBox.shrink());

        expect(capturedClose, returnsNormally);
      },
    );

    testWidgets(
      'the Future returned by show() still completes when the Overlay it '
      'lives in is torn down from outside, without ever closing via the '
      'scrim or the builder\'s close callback',
      (WidgetTester tester) async {
        late Future<void> dialogFuture;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    dialogFuture = CruxDialog.show(
                      context,
                      builder: (BuildContext context, VoidCallback close) =>
                          const Text(
                            'dialog content',
                            textDirection: TextDirection.ltr,
                          ),
                    );
                  },
                  child: const SizedBox(width: 44, height: 44),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        bool completed = false;
        unawaited(dialogFuture.then((void _) => completed = true));

        // Tear down the whole tree -- Overlay included -- without ever
        // tapping the scrim or invoking the builder's close callback.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(completed, isTrue);
      },
    );

    group('entrance animation', () {
      // Reads the horizontal scale factor directly off the transform
      // matrix's (0, 0) entry, matching button_test.dart's own "press
      // animation" test technique.
      testWidgets(
        'springs away from 1.0 mid-flight, then settles back to 1.0 -- a '
        'behavior assertion, not a frame-exact spring value',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _wrap(
              _OpenTrigger(
                builder: (BuildContext context, VoidCallback close) =>
                    const Text(
                      'dialog content',
                      textDirection: TextDirection.ltr,
                    ),
              ),
            ),
          );

          await tester.tap(find.byType(GestureDetector).first);
          // First frame mounts the new OverlayEntry at its animation's
          // starting value; a second, zero-duration pump lets the pending
          // post-frame setState flip the target and start the spring's
          // ticker at elapsed = 0 (mirrors button_test.dart's identical
          // two-pump comment on the same motor quirk); only *then* does
          // advancing the clock move the spring forward.
          await tester.pump();
          await tester.pump();
          // Sampled early in the 200ms spring's flight (well before it
          // could have climbed from its 0.9 start back up through 1.0 and
          // into its overshoot) so this assertion cannot land on one of the
          // spring's own zero-crossings, unlike a late/arbitrary sample
          // time would risk.
          await tester.pump(const Duration(milliseconds: 20));

          final double midFlightScale = tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0);
          expect(midFlightScale, lessThan(0.99));

          await tester.pumpAndSettle();

          final double settledScale = tester
              .widget<Transform>(find.byType(Transform))
              .transform
              .entry(0, 0);
          expect(settledScale, closeTo(1.0, 0.001));
        },
      );
    });
  });

  group('stays isolated from an ambient MaterialApp\'s "no enclosing Material" '
      'warning text style (H3: Crux\'s look must never depend on, or be '
      'affected by, an ambient Material theme)', () {
    testWidgets(
      'content Text inside a card opened via CruxDialog.show renders '
      'with no text decoration, even under a bare MaterialApp (no '
      'Scaffold, default ThemeData) -- MaterialApp always installs a '
      'yellow double-underline DefaultTextStyle at the app root (meant '
      'to flag Text rendered outside a Material widget) directly above '
      'the Overlay this card floats in, and only a Scaffold\'s Material '
      'normally resets it before reaching ordinary screen content',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  key: const ValueKey('openTrigger'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => CruxDialog.show(
                    context,
                    builder: (BuildContext context, VoidCallback close) =>
                        const Text(
                          'dialog content',
                          textDirection: TextDirection.ltr,
                        ),
                  ),
                  child: const SizedBox(width: 44, height: 44),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('openTrigger')));
        await tester.pump();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        final RichText richText = tester.widget<RichText>(
          find.descendant(
            of: find.text('dialog content'),
            matching: find.byType(RichText),
          ),
        );
        expect(richText.text.style?.decoration, TextDecoration.none);

        await tester.pumpAndSettle();
      },
    );
  });
}
