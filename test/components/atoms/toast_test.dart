// Behavior tests for CruxToastCard (the static, unfloated card body) and
// CruxToastHost/showCruxToast (the stacking, deduping, auto-dismissing
// notification layer), per plans/atoms-batch-3.md and
// unknowns/atoms-batch-3/ledger.md's confirmed Toast behavior. Following
// button_test.dart's/checkbox_test.dart's own file doc convention: animated
// "how bouncy does it feel" fine-tuning is not asserted at frame-exact
// precision here -- these tests assert observable behavior (a card shakes
// horizontally, a card disappears, a callback fires), not internal spring
// values.
//
// Timer-driven behavior (auto-dismiss, the longer action grace period, the
// dedup timer reset) is verified deterministically via tester.pump(Duration)
// -- flutter_test virtualizes dart:async Timer under testWidgets, so no
// wall-clock waiting is involved.
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxToastCard/CruxToastHost
/// need to lay out and paint (a [Directionality] plus a fixed-size box, so
/// tests have a known, bounded viewport to position/measure against) without
/// pulling in a full app shell -- mirrors button_test.dart's/dialog_test.
/// dart's own `_wrap` convention.
Widget _wrap(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 400, height: 800, child: child),
  );
}

/// Wraps [card] the way [CruxToastHost] actually lays it out in
/// production: inside a [Column] with [MainAxisSize.min] (matching the
/// host's own toast-stack `Column`), which hands the card a genuinely
/// *unbounded* height constraint.
///
/// This is deliberately *not* `_wrap(Center(child: card))`: `_wrap`'s fixed
/// `SizedBox(height: 800)` gets overridden by flutter_test's own
/// tight-to-window ambient constraint (800x600 by default), so a `Center`
/// wrapped directly around the card hands it a *finite* (not infinite)
/// max-height of ~600. [CruxToastCard]'s action button centers its label
/// in a plain `Center` too, and `Center` only shrink-wraps an axis whose
/// incoming max is literally infinite -- given a finite-but-large bound
/// instead, it expands to fill it. Under `_wrap(Center(...))` this makes
/// the button (and, cascading up, the whole card) measure hundreds of
/// pixels tall, which has nothing to do with the card's real, ~64px
/// content-driven height. Any test asserting an *exact* pixel height or
/// tap-region geometry must use this helper instead; the existing
/// `greaterThanOrEqualTo`-style assertions elsewhere in this file happen to
/// hold either way, so they were not affected by this and were left alone.
Widget _wrapForExactHeight(Widget card) {
  return _wrap(
    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[card]),
  );
}

/// Pumps a [CruxToastHost] and hands back a [BuildContext] descending from
/// it, for tests to call [showCruxToast] with directly -- the same
/// "capture a BuildContext via Builder" technique used to call context-scoped
/// APIs (`Navigator.of(context)`-style) from outside a widget's own build
/// method.
Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    _wrap(
      CruxToastHost(
        child: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return hostContext;
}

/// Finds the 44x44-minimum [ConstrainedBox] a toast action button wraps its
/// tap target in -- mirrors checkbox_test.dart's `_boxFinder`-style
/// structural predicate for a private implementation widget this test file
/// cannot import a type for.
Finder _actionTapTargetFinder() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is ConstrainedBox &&
        widget.constraints.minWidth == 44 &&
        widget.constraints.minHeight == 44,
  );
}

/// Pumps a [CruxToastHost] under an explicit [MediaQuery] (rather than
/// whatever [WidgetTester.pumpWidget] provides by default), so a test can
/// control `MediaQuery.accessibleNavigationOf` -- mirrors [_pumpHost], with
/// the extra [accessibleNavigation] knob this file's accessible-navigation
/// group needs.
Future<BuildContext> _pumpHostWithAccessibleNavigation(
  WidgetTester tester, {
  required bool accessibleNavigation,
}) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(accessibleNavigation: accessibleNavigation),
      child: _wrap(
        CruxToastHost(
          child: Builder(
            builder: (BuildContext context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
  return hostContext;
}

/// Invokes [action] on [node] via the [SemanticsOwner] that actually owns
/// it. `tester.binding.pipelineOwner` (the obvious spot) is deprecated in
/// favor of `RendererBinding.rootPipelineOwner`, but that root owner sits
/// *above* the per-[RenderView] owner an ordinary single-view widget test's
/// semantics tree is actually attached to -- `performAction` on the root is
/// silently a no-op for a node owned by a child. `tester.binding.renderViews
/// .single.owner!.semanticsOwner!` is the same non-deprecated owner
/// `WidgetTester.getSemantics` itself reads through internally (same
/// reasoning slider_test.dart's identical helper already documents).
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

void main() {
  group('CruxToastCard (static, unfloated card body)', () {
    testWidgets(
      'renders the message with no Host/Overlay/animation ancestry -- must '
      'be paintable entirely on its own for golden use',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const Center(child: CruxToastCard(message: '同期が完了しました'))),
        );

        expect(find.text('同期が完了しました'), findsOneWidget);
        expect(find.byType(CruxToastHost), findsNothing);
        expect(find.byType(Overlay), findsNothing);
      },
    );

    testWidgets('renders the caller-supplied leading widget when given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: CruxToastCard(
              message: '同期が完了しました',
              leading: SizedBox(
                key: Key('leading-probe'),
                width: 18,
                height: 18,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('leading-probe')), findsOneWidget);
    });

    testWidgets('omits the action entirely when action is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const Center(child: CruxToastCard(message: '同期が完了しました'))),
      );

      expect(_actionTapTargetFinder(), findsNothing);
    });

    testWidgets(
      'renders the action label at a 44x44 minimum tap target and invokes '
      'onPressed exactly once when tapped',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxToastCard(
                message: '削除しました',
                action: CruxToastAction(
                  label: '元に戻す',
                  onPressed: () => calls++,
                ),
              ),
            ),
          ),
        );

        expect(find.text('元に戻す'), findsOneWidget);
        final Size tapTargetSize = tester.getSize(_actionTapTargetFinder());
        expect(tapTargetSize.width, greaterThanOrEqualTo(44));
        expect(tapTargetSize.height, greaterThanOrEqualTo(44));

        await tester.tap(find.text('元に戻す'));
        await tester.pump();

        expect(calls, 1);
      },
    );

    testWidgets(
      'an action-equipped card is 64 logical pixels tall for a 1-line '
      'message -- the action button\'s minimum 44px tap target must not '
      'push the card past the height a plain two-line toast already uses '
      '(2026-08-02: "アクション付きトーストの高さも64pxに")',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrapForExactHeight(
            CruxToastCard(
              message: '短いメッセージ',
              action: CruxToastAction(label: '元に戻す', onPressed: () {}),
            ),
          ),
        );

        final Size cardSize = tester.getSize(find.byType(CruxToastCard));
        expect(cardSize.height, 64);
      },
    );

    testWidgets(
      'an action-equipped card stays 64 logical pixels tall even when its '
      'own message wraps to the full 2 lines it is allowed',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrapForExactHeight(
            CruxToastCard(
              message: 'とても長いメッセージがここに入って2行に折り返される想定のテスト文言です',
              action: CruxToastAction(label: '元に戻す', onPressed: () {}),
            ),
          ),
        );

        final double messageHeight = tester
            .getRect(find.text('とても長いメッセージがここに入って2行に折り返される想定のテスト文言です'))
            .height;
        expect(
          messageHeight,
          40,
          reason: 'sanity check: the message must actually wrap to 2 lines',
        );

        final Size cardSize = tester.getSize(find.byType(CruxToastCard));
        expect(cardSize.height, 64);
      },
    );

    testWidgets(
      'a tap 1px inside the very top and very bottom edge of the action '
      'button\'s 44px tap target still invokes onPressed -- pins that the '
      'tap region is genuinely, not just nominally, 44px tall',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _wrapForExactHeight(
            CruxToastCard(
              message: '短いメッセージ',
              action: CruxToastAction(label: '元に戻す', onPressed: () => calls++),
            ),
          ),
        );

        final Rect tapTargetRect = tester.getRect(_actionTapTargetFinder());
        expect(
          tapTargetRect.height,
          44,
          reason: 'sanity check: the tap target must actually be 44 tall',
        );

        await tester.tapAt(
          Offset(tapTargetRect.center.dx, tapTargetRect.top + 1),
        );
        await tester.pump();
        expect(calls, 1, reason: 'a tap 1px inside the top edge must land');

        await tester.tapAt(
          Offset(tapTargetRect.center.dx, tapTargetRect.bottom - 1),
        );
        await tester.pump();
        expect(calls, 2, reason: 'a tap 1px inside the bottom edge must land');
      },
    );

    testWidgets(
      'always paints a 1px border in the theme\'s shadow hairline color '
      '(fully transparent in light, so effectively invisible there)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const Center(child: CruxToastCard(message: 'メッセージ'))),
        );

        final Container container = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration decoration =
            container.decoration! as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;

        expect(shape.side.color, CruxShadows.light.hairline);
        expect(shape.side.width, 1);
        expect(decoration.shadows, CruxShadows.light.md);
      },
    );

    testWidgets(
      'exposes a live-region semantics node so screen readers announce a '
      'freshly-shown toast',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(const Center(child: CruxToastCard(message: '保存しました'))),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(CruxToastCard),
        );
        expect(node.flagsCollection.isLiveRegion, isTrue);

        handle.dispose();
      },
    );
  });

  group('showCruxToast requires a CruxToastHost ancestor', () {
    testWidgets('asserts when called with no CruxToastHost ancestor', (
      WidgetTester tester,
    ) async {
      late BuildContext plainContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              plainContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      expect(
        () => showCruxToast(plainContext, message: 'oops'),
        throwsAssertionError,
      );
    });
  });

  group('shows and auto-dismisses', () {
    testWidgets('shows a toast with the given message', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _pumpHost(tester);

      showCruxToast(context, message: '同期が完了しました');
      await tester.pump();

      expect(find.text('同期が完了しました'), findsOneWidget);

      // Drain the pending ~3s auto-dismiss timer before the test ends.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('auto-dismisses a plain (no-action) toast after about 3s', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _pumpHost(tester);

      showCruxToast(context, message: 'A');
      await tester.pump();
      expect(find.text('A'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'should still be showing just before the ~3s mark',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('A'), findsNothing);
    });
  });

  group('3-toast cap', () {
    testWidgets(
      'keeps at most 3 toasts, dropping the oldest once a 4th distinct '
      'message arrives',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'A');
        await tester.pump();
        showCruxToast(context, message: 'B');
        await tester.pump();
        showCruxToast(context, message: 'C');
        await tester.pump();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);

        showCruxToast(context, message: 'D');
        await tester.pump();
        // Long enough for A's leaving-exit to finish removing it from the
        // tree, short enough that nothing's own ~3s timer has fired yet.
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('A'), findsNothing);
        expect(find.text('B'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);
        expect(find.text('D'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
      },
    );
  });

  group('duplicate messages are not stacked', () {
    testWidgets(
      'a duplicate message shakes the existing card horizontally instead '
      'of stacking a second one',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'A');
        await tester.pumpAndSettle();
        final Offset restingCenter = tester.getCenter(find.text('A'));

        showCruxToast(context, message: 'A');
        await tester.pump();

        // Exactly one card for the message, never two.
        expect(find.text('A'), findsOneWidget);

        bool sawDisplacement = false;
        for (int i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          final Offset current = tester.getCenter(find.text('A'));
          if ((current.dx - restingCenter.dx).abs() > 0.5) {
            sawDisplacement = true;
            break;
          }
        }
        expect(
          sawDisplacement,
          isTrue,
          reason: 'expected a horizontal shake displacement',
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'a buried duplicate (not the frontmost toast) moves to the front and '
      'its dismiss timer resets',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'A');
        await tester.pump();
        showCruxToast(context, message: 'B');
        await tester.pump();
        showCruxToast(context, message: 'C');
        await tester.pump();
        // A is now buried at the back (oldest of the three).

        await tester.pump(const Duration(milliseconds: 1500));

        showCruxToast(context, message: 'A');
        await tester.pump();

        // A must now be the frontmost (newest-position) card again -- in
        // this bottom-stacked layout that means visually *below* C, the
        // previously-frontmost card.
        expect(
          tester.getCenter(find.text('A')).dy,
          greaterThan(tester.getCenter(find.text('C')).dy),
        );

        // Without the reset, A's original ~3s-from-first-show deadline
        // (plus the leaving-exit buffer) falls at 1500ms + 220ms = 1720ms
        // after this second push, so it would already be gone by 1800ms.
        // With the reset, its new deadline is a full ~3s+220ms after this
        // second push, so it must still be showing at 1800ms.
        await tester.pump(const Duration(milliseconds: 1800));
        expect(
          find.text('A'),
          findsOneWidget,
          reason: 'a buried duplicate must reset the dismiss timer',
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'a frontmost duplicate (already the newest toast) shakes but does '
      'not reset the dismiss timer',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'A');
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 1500));

        // A is still the only (and therefore frontmost) toast.
        showCruxToast(context, message: 'A');
        await tester.pump();

        // A's original deadline (unreset) is 3000ms + 220ms = 3220ms after
        // its first show; we are at 1500ms, so 1800ms further reaches
        // 3300ms -- past that deadline only if the timer was *not* reset.
        await tester.pump(const Duration(milliseconds: 1800));
        expect(
          find.text('A'),
          findsNothing,
          reason: 'a frontmost duplicate must not reset the dismiss timer',
        );
      },
    );
  });

  group('swipe to dismiss', () {
    testWidgets(
      'a large horizontal drag (past the distance threshold) dismisses the '
      'toast',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'スワイプで消える');
        await tester.pumpAndSettle();
        expect(find.text('スワイプで消える'), findsOneWidget);

        await tester.drag(find.text('スワイプで消える'), const Offset(300, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('スワイプで消える'), findsNothing);
      },
    );

    testWidgets(
      'a fast, short flick (past the velocity threshold) dismisses the '
      'toast even though the distance itself is well under the '
      'distance-fraction threshold',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'フリックで消える');
        await tester.pumpAndSettle();

        // 50 logical pixels clears both Flutter's own 18px touch-slop
        // (kTouchSlop -- below that the gesture never resolves as a drag at
        // all) *and* the minimum travel WidgetTester.fling's synthesized
        // pointer-event stream needs for VelocityTracker to fit a non-zero
        // estimate at all (empirically confirmed: shorter offsets such as
        // 30px reliably reported a velocity of exactly 0 in this harness),
        // while still staying comfortably under this card's own ~40%
        // width-fraction distance threshold -- the high speed is what pushes
        // DragEndDetails.primaryVelocity's magnitude past
        // _swipeDismissVelocity on its own.
        await tester.fling(find.text('フリックで消える'), const Offset(50, 0), 2500);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('フリックで消える'), findsNothing);
      },
    );

    testWidgets(
      'a small, slow drag (under both thresholds) springs back and does '
      'not dismiss',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: '戻る');
        await tester.pumpAndSettle();

        await tester.drag(find.text('戻る'), const Offset(15, 0));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('戻る'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
      },
    );
  });

  group('dragging pauses the auto-dismiss timer', () {
    testWidgets(
      'holding a drag past the default grace period keeps the toast visible; '
      'releasing without dismissing schedules a fresh full grace period '
      'rather than resuming a remaining one',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'ドラッグ中は消えない');
        await tester.pumpAndSettle();

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.text('ドラッグ中は消えない')),
        );
        // 20px clears kTouchSlop (18px, see the flick test's own comment on
        // this) so the gesture resolves as a horizontal drag.
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();

        // Past the plain ~3s deadline (plus the leaving-exit buffer) while
        // still holding the drag -- must not have started leaving.
        await tester.pump(const Duration(milliseconds: 3300));
        expect(
          find.text('ドラッグ中は消えない'),
          findsOneWidget,
          reason: 'auto-dismiss must pause while a drag is held in place',
        );

        await gesture.up();
        await tester.pump();

        // Not yet at a fresh full grace period counted from release.
        await tester.pump(const Duration(milliseconds: 2900));
        expect(
          find.text('ドラッグ中は消えない'),
          findsOneWidget,
          reason:
              'release must restart the *full* grace period, not resume a '
              'shorter remaining one',
        );

        // Past the fresh full grace period (plus the leaving-exit buffer).
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('ドラッグ中は消えない'), findsNothing);
      },
    );
  });

  group('action button', () {
    testWidgets(
      'pressing the action button invokes onPressed and dismisses the '
      'toast',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);
        int actionCalls = 0;

        showCruxToast(
          context,
          message: '削除しました',
          action: CruxToastAction(
            label: '元に戻す',
            onPressed: () => actionCalls++,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('元に戻す'));
        await tester.pump();

        expect(actionCalls, 1);

        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('削除しました'), findsNothing);
      },
    );

    testWidgets(
      'a toast with an action stays visible past the plain ~3s duration, '
      'and is dismissed only after its longer grace period',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(
          context,
          message: '削除しました',
          action: CruxToastAction(label: '元に戻す', onPressed: () {}),
        );
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 3300));
        expect(
          find.text('削除しました'),
          findsOneWidget,
          reason: 'an action toast must outlive the plain ~3s duration',
        );

        await tester.pump(const Duration(milliseconds: 3000));
        expect(find.text('削除しました'), findsNothing);
      },
    );
  });

  group(
    'works directly under a bare Overlay, with no MaterialApp/Navigator',
    () {
      testWidgets(
        'CruxToastHost nested inside a plain Overlay (no Navigator) still '
        'shows toasts',
        (WidgetTester tester) async {
          late BuildContext hostContext;
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 400,
                height: 800,
                child: Overlay(
                  initialEntries: <OverlayEntry>[
                    OverlayEntry(
                      builder: (BuildContext context) => CruxToastHost(
                        child: Builder(
                          builder: (BuildContext innerContext) {
                            hostContext = innerContext;
                            return const SizedBox.expand();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          showCruxToast(hostContext, message: 'Overlay 直下でも動く');
          await tester.pump();

          expect(find.text('Overlay 直下でも動く'), findsOneWidget);

          await tester.pump(const Duration(seconds: 4));
        },
      );
    },
  );

  group('a leaving card ignores pointer input', () {
    testWidgets(
      'tapping the action button on a card that has already started its '
      'exit animation does not invoke onPressed',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHost(tester);
        int calls = 0;

        showCruxToast(
          context,
          message: '削除しました',
          action: CruxToastAction(label: '元に戻す', onPressed: () => calls++),
        );
        await tester.pumpAndSettle();

        // Swipe it away to start the exit animation, but stop right after --
        // the card stays mounted (still `leaving`) for _exitAnimationDuration
        // (~220ms) before it is actually spliced out.
        await tester.drag(find.text('削除しました'), const Offset(300, 0));
        await tester.pump();

        await tester.tap(find.text('元に戻す'), warnIfMissed: false);
        await tester.pump();

        expect(
          calls,
          0,
          reason: 'a leaving card must not accept a tap on its action button',
        );

        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('削除しました'), findsNothing);
      },
    );
  });

  group('render cap keeps active + leaving cards from overflowing', () {
    testWidgets('firing 6 distinct messages back-to-back, faster than any exit '
        'animation can finish, never renders more than 5 cards at once', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _pumpHost(tester);

      // No `await tester.pump()` between these -- each show() call lands
      // before a single frame has run, the same "faster than the exit
      // animation" burst the render cap exists for.
      for (final String message in <String>['A', 'B', 'C', 'D', 'E', 'F']) {
        showCruxToast(context, message: message);
      }
      await tester.pump();

      // 5 = CruxToastHost's self-decided _maxRenderedTotal (3 active +
      // up to 2 still-leaving cards); see toast.dart's own doc for why.
      expect(
        find.byType(CruxToastCard).evaluate().length,
        lessThanOrEqualTo(5),
        reason:
            'active + leaving cards together must never exceed the '
            'render cap',
      );

      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('accessible navigation holds an actioned toast open', () {
    testWidgets('a toast with an action does not auto-dismiss under accessible '
        'navigation, even well past its normal action grace period', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _pumpHostWithAccessibleNavigation(
        tester,
        accessibleNavigation: true,
      );
      int actionCalls = 0;

      showCruxToast(
        context,
        message: '削除しました',
        action: CruxToastAction(label: '元に戻す', onPressed: () => actionCalls++),
      );
      await tester.pump();

      // Well past _actionDismissDuration (6s).
      await tester.pump(const Duration(seconds: 10));
      expect(
        find.text('削除しました'),
        findsOneWidget,
        reason:
            'accessible navigation must hold an actioned toast open past '
            'its normal grace period',
      );

      // Still manually dismissable via its action.
      await tester.tap(find.text('元に戻す'));
      await tester.pump();
      expect(actionCalls, 1);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('削除しました'), findsNothing);
    });

    testWidgets(
      'a toast with no action still auto-dismisses on its normal schedule '
      'under accessible navigation (matching SnackBar\'s own precedent: '
      'persist defaults to false whenever there is no action)',
      (WidgetTester tester) async {
        final BuildContext context = await _pumpHostWithAccessibleNavigation(
          tester,
          accessibleNavigation: true,
        );

        showCruxToast(context, message: 'アクションなし');
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 3300));
        expect(find.text('アクションなし'), findsNothing);
      },
    );
  });

  group('semantics dismiss action', () {
    testWidgets(
      'firing SemanticsAction.dismiss on a toast card dismisses it, the '
      'same way a swipe would',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final BuildContext context = await _pumpHost(tester);

        showCruxToast(context, message: 'セマンティクスで消す');
        await tester.pumpAndSettle();

        final SemanticsNode node = tester.getSemantics(
          find.byType(CruxToastCard),
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.dismiss),
          isTrue,
        );

        _performSemanticsAction(tester, node, SemanticsAction.dismiss);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('セマンティクスで消す'), findsNothing);

        handle.dispose();
      },
    );
  });

  group('captures the caller\'s local theme at show time', () {
    testWidgets(
      'a toast shown from a context nested under a local dark CruxTheme '
      'renders its card with the dark surface color, even though the toast '
      'stack itself sits outside that local subtree',
      (WidgetTester tester) async {
        late BuildContext localDarkContext;
        await tester.pumpWidget(
          _wrap(
            CruxToastHost(
              child: CruxTheme(
                data: CruxThemeData.dark(),
                child: Builder(
                  builder: (BuildContext context) {
                    localDarkContext = context;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        );

        showCruxToast(localDarkContext, message: 'ダークテーマ配下から');
        await tester.pump();

        final Container container = tester.widget<Container>(
          find.byType(Container),
        );
        final ShapeDecoration decoration =
            container.decoration! as ShapeDecoration;

        expect(decoration.color, CruxColors.dark.surface);

        await tester.pump(const Duration(seconds: 4));
      },
    );
  });

  group('stays isolated from an ambient MaterialApp\'s "no enclosing Material" '
      'warning text style (H3: Crux\'s look must never depend on, or be '
      'affected by, an ambient Material theme)', () {
    testWidgets('a toast message shown under a bare MaterialApp (no Scaffold, '
        'default ThemeData) renders with no text decoration, even though '
        'CruxToastHost stacks its cards as an ordinary Stack sibling of '
        '[child] rather than inside any Material widget -- see '
        'dialog_test.dart\'s identically-shaped test for the full "why" of '
        'MaterialApp\'s ambient yellow double-underline DefaultTextStyle', (
      WidgetTester tester,
    ) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          home: CruxToastHost(
            child: Builder(
              builder: (BuildContext context) {
                hostContext = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      showCruxToast(hostContext, message: 'アンビエントスタイル無効化テスト');
      await tester.pump();

      final RichText richText = tester.widget<RichText>(
        find.descendant(
          of: find.text('アンビエントスタイル無効化テスト'),
          matching: find.byType(RichText),
        ),
      );
      expect(richText.text.style?.decoration, TextDecoration.none);

      await tester.pump(const Duration(seconds: 4));
    });
  });
}
