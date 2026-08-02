// Behavior tests for CruxConfirmDialog: the title/message/cancel+confirm
// content that composes on top of CruxDialog.show (per
// plans/atoms-batch-3.md's "confirmation layer" spec). Mirrors
// test/components/atoms/dialog_test.dart's bare-Overlay wrap for the
// CruxConfirmDialog.show tests, since that static method is itself just a
// thin CruxDialog.show call.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Same bare-[Overlay] ancestry as dialog_test.dart's `_wrap`: no
/// [Navigator]/`MaterialApp` involved, so these tests also exercise
/// [CruxDialog.show]'s "works from under a plain Overlay" contract for
/// its [CruxConfirmDialog.show] caller.
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

void main() {
  group('CruxConfirmDialog (content widget, rendered standalone)', () {
    testWidgets(
      'renders the title, message, and both action labels with no Overlay '
      'or CruxDialog.show involved',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxConfirmDialog(
              title: '下書きを削除しますか？',
              message: '削除すると元に戻せません。',
              cancelLabel: 'キャンセル',
              confirmLabel: '削除する',
              onConfirm: () {},
            ),
          ),
        );

        expect(find.text('下書きを削除しますか？'), findsOneWidget);
        expect(find.text('削除すると元に戻せません。'), findsOneWidget);
        expect(find.widgetWithText(CruxButton, 'キャンセル'), findsOneWidget);
        expect(find.widgetWithText(CruxButton, '削除する'), findsOneWidget);
      },
    );

    testWidgets(
      'lays its action row out as ghost-cancel / filled-confirm, cancel '
      'leading and confirm trailing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxConfirmDialog(
              title: 'タイトル',
              message: '本文',
              cancelLabel: 'キャンセル',
              confirmLabel: '実行する',
              onConfirm: () {},
            ),
          ),
        );

        final CruxButton cancelButton = tester.widget<CruxButton>(
          find.widgetWithText(CruxButton, 'キャンセル'),
        );
        final CruxButton confirmButton = tester.widget<CruxButton>(
          find.widgetWithText(CruxButton, '実行する'),
        );
        expect(cancelButton.variant, CruxButtonVariant.ghost);
        expect(confirmButton.variant, CruxButtonVariant.filled);

        // Cancel must be the leading (leftmost) action, confirm trailing.
        final double cancelLeft = tester
            .getTopLeft(find.widgetWithText(CruxButton, 'キャンセル'))
            .dx;
        final double confirmLeft = tester
            .getTopLeft(find.widgetWithText(CruxButton, '実行する'))
            .dx;
        expect(cancelLeft, lessThan(confirmLeft));
      },
    );

    testWidgets('splits the available width roughly evenly between cancel and '
        'confirm, instead of only using as much width as each label needs', (
      WidgetTester tester,
    ) async {
      const double contentWidth = 300;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: contentWidth,
            child: CruxConfirmDialog(
              title: 'タイトル',
              message: '本文',
              cancelLabel: 'キャンセル',
              confirmLabel: '実行する',
              onConfirm: () {},
            ),
          ),
        ),
      );

      final double cancelWidth = tester
          .getSize(find.widgetWithText(CruxButton, 'キャンセル'))
          .width;
      final double confirmWidth = tester
          .getSize(find.widgetWithText(CruxButton, '実行する'))
          .width;

      // Roughly equal halves, not "however wide each label happens to
      // need" -- a one-pixel slack covers flex layout's rounding when the
      // content width doesn't divide evenly.
      expect((cancelWidth - confirmWidth).abs(), lessThanOrEqualTo(1));
      // Together the two buttons (plus the gap between them) fill almost
      // all of the available width -- the old space-between layout left
      // most of it empty.
      expect(cancelWidth + confirmWidth, greaterThan(contentWidth * 0.8));
    });

    testWidgets(
      'both the cancel and confirm actions meet the 44x44 minimum tap '
      'target, regardless of how short their labels are',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxConfirmDialog(
              title: 'タイトル',
              message: '本文',
              cancelLabel: 'キャンセル',
              confirmLabel: '実行する',
              onConfirm: () {},
            ),
          ),
        );

        final Size cancelSize = tester.getSize(
          find.widgetWithText(CruxButton, 'キャンセル'),
        );
        final Size confirmSize = tester.getSize(
          find.widgetWithText(CruxButton, '実行する'),
        );

        expect(cancelSize.width, greaterThanOrEqualTo(44));
        expect(cancelSize.height, greaterThanOrEqualTo(44));
        expect(confirmSize.width, greaterThanOrEqualTo(44));
        expect(confirmSize.height, greaterThanOrEqualTo(44));
      },
    );

    testWidgets(
      'disables the cancel action when onCancel is null, matching every '
      'other Crux control\'s "nullable callback disables" convention',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxConfirmDialog(
              title: 'タイトル',
              message: '本文',
              cancelLabel: 'キャンセル',
              confirmLabel: '実行する',
              onConfirm: () {},
            ),
          ),
        );

        final CruxButton cancelButton = tester.widget<CruxButton>(
          find.widgetWithText(CruxButton, 'キャンセル'),
        );
        expect(cancelButton.onPressed, isNull);
      },
    );
  });

  group('CruxConfirmDialog.show (floating, via CruxDialog.show)', () {
    testWidgets('tapping cancel calls onCancel and closes the dialog', (
      WidgetTester tester,
    ) async {
      int cancelCalls = 0;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => CruxConfirmDialog.show(
                  context,
                  title: 'タイトル',
                  message: '本文',
                  cancelLabel: 'キャンセル',
                  onCancel: () => cancelCalls++,
                  confirmLabel: '実行する',
                  onConfirm: () {},
                ),
                child: const SizedBox(width: 44, height: 44),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(find.byType(CruxDialogCard), findsOneWidget);

      await tester.tap(find.widgetWithText(CruxButton, 'キャンセル'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(cancelCalls, 1);
      expect(find.byType(CruxDialogCard), findsNothing);
    });

    testWidgets('tapping confirm calls onConfirm and closes the dialog', (
      WidgetTester tester,
    ) async {
      int confirmCalls = 0;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => CruxConfirmDialog.show(
                  context,
                  title: 'タイトル',
                  message: '本文',
                  cancelLabel: 'キャンセル',
                  confirmLabel: '削除する',
                  onConfirm: () => confirmCalls++,
                ),
                child: const SizedBox(width: 44, height: 44),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(find.byType(CruxDialogCard), findsOneWidget);

      await tester.tap(find.widgetWithText(CruxButton, '削除する'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(confirmCalls, 1);
      expect(find.byType(CruxDialogCard), findsNothing);
    });

    testWidgets(
      'tapping confirm twice in quick succession -- the second tap landing '
      'while the exit fade is still mid-flight -- only calls onConfirm '
      'once, not twice',
      (WidgetTester tester) async {
        int confirmCalls = 0;
        await tester.pumpWidget(
          _wrap(
            // Align (rather than placing the trigger directly, as this
            // file's other CruxConfirmDialog.show tests do) keeps the
            // trigger pinned to its own 44x44 footprint in the corner:
            // Overlay always sizes its bottom entry to the full test
            // surface regardless of _wrap's SizedBox, which would otherwise
            // force an unwrapped SizedBox(44, 44) trigger to expand and
            // cover the whole screen -- and this test deliberately taps
            // where nothing should be hit-testable, so a fullscreen trigger
            // underneath would swallow that tap and reopen a fresh dialog,
            // masking the very regression this test exists to catch.
            Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (BuildContext context) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => CruxConfirmDialog.show(
                      context,
                      title: 'タイトル',
                      message: '本文',
                      cancelLabel: 'キャンセル',
                      confirmLabel: '削除する',
                      onConfirm: () => confirmCalls++,
                    ),
                    child: const SizedBox(width: 44, height: 44),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        final Finder confirmButton = find.widgetWithText(CruxButton, '削除する');
        await tester.tap(confirmButton);
        expect(confirmCalls, 1);

        // Land a second tap mid-fade, before the exit animation settles --
        // this is the window in which the card (and its confirm button)
        // used to remain hit-testable.
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(confirmButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(confirmCalls, 1);
        expect(find.byType(CruxDialogCard), findsNothing);
      },
    );

    testWidgets(
      'cancel still closes the dialog when onCancel is not supplied',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => CruxConfirmDialog.show(
                    context,
                    title: 'タイトル',
                    message: '本文',
                    cancelLabel: 'キャンセル',
                    confirmLabel: '実行する',
                    onConfirm: () {},
                  ),
                  child: const SizedBox(width: 44, height: 44),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.byType(CruxDialogCard), findsOneWidget);

        await tester.tap(find.widgetWithText(CruxButton, 'キャンセル'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(CruxDialogCard), findsNothing);
      },
    );

    testWidgets(
      'names its semantics route after title automatically, with no extra '
      'argument required from the caller',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => CruxConfirmDialog.show(
                    context,
                    title: '下書きを削除しますか？',
                    message: '削除すると元に戻せません。',
                    cancelLabel: 'キャンセル',
                    confirmLabel: '削除する',
                    onConfirm: () {},
                  ),
                  child: const SizedBox(width: 44, height: 44),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        final Semantics scopesRouteWidget = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((Semantics s) => s.properties.scopesRoute == true);
        expect(scopesRouteWidget.properties.namesRoute, isTrue);
        expect(scopesRouteWidget.properties.label, '下書きを削除しますか？');

        handle.dispose();
      },
    );
  });
}
