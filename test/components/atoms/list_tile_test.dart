// Behavior tests for CruxListTile, per spec.md's "CruxListTile" section
// (unknowns/atoms-batch-1/spec.md). Visual metrics (exact spacing, colors as
// pixels) are checked visually via the example app; these tests assert the
// observable behavior spec.md calls out: tap notification, disabled state,
// the 44 minimum tap target, ellipsis overflow safety, semantics, and
// per-state color resolution (title/subtitle/trailing).
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxListTile needs to lay out
/// and paint (a [Directionality]) without pulling in a full app shell. No
/// [CruxTheme] is provided deliberately in most tests, exercising the
/// documented fallback to [CruxThemeData.light].
Widget _wrap(Widget child, {double width = 320}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: width, child: child),
  );
}

/// The same repro text as the widgetbook catalog's "Edge cases" use case
/// (`widgetbook/lib/usecases/list_tile.dart`'s `_longTitle` /
/// `_longSubtitle` / `_longTrailing`), so these regression tests reproduce
/// the exact overflow reported against that page.
const String _edgeCaseLongTitle = '来週の会議までに全員分の資料を確認し修正点をまとめて共有すること';
const String _edgeCaseLongSubtitle = '担当者からの返信を待ってから最終版を印刷し関係者全員に配布する予定です';
const String _edgeCaseLongTrailing = '2026/07/25 23:59';

void main() {
  group('tap handling', () {
    testWidgets('invokes onTap exactly once per tap', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        _wrap(CruxListTile(title: 'タイトル', onTap: () => calls++)),
      );

      await tester.tap(find.byType(CruxListTile));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets(
      'does not throw and does not invoke anything when onTap is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxListTile(title: 'タイトル', onTap: null)),
        );

        await tester.tap(find.byType(CruxListTile));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('tap target', () {
    testWidgets('keeps a minimum height of 44 logical pixels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CruxListTile(title: 'タイトル', onTap: () {})),
      );

      final Size size = tester.getSize(find.byType(CruxListTile));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('follows the parent width instead of hugging content', (
      WidgetTester tester,
    ) async {
      // Shrinks the whole test surface, rather than nesting a SizedBox
      // under the test binding's default (already-tight) 800px-wide root: a
      // tight incoming constraint can't be narrowed by a descendant SizedBox
      // (BoxConstraints.enforce clamps to the incoming range), so only
      // shrinking the surface itself reproduces a real "loose, bounded"
      // parent width. See button_test.dart's "sizing (hug content)" group
      // for the same caveat on CruxButton.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CruxListTile(title: 'タ', onTap: () {}),
        ),
      );

      final Size size = tester.getSize(find.byType(CruxListTile));
      expect(size.width, 320);
    });
  });

  group('overflow safety', () {
    testWidgets(
      'does not overflow when squeezed narrow with long title, subtitle, '
      'and trailing text',
      (WidgetTester tester) async {
        // Narrows the whole test surface rather than nesting a SizedBox
        // under the test binding's default (already-tight) 800px-wide root:
        // a tight incoming constraint can't be narrowed by a descendant
        // SizedBox (BoxConstraints.enforce clamps to the incoming range),
        // so a `_wrap(..., width: 100)` here would silently keep rendering
        // at 800px and never actually exercise the narrow case. See the
        // "follows the parent width" test above and button_test.dart's
        // "sizing (hug content)" group for the same caveat.
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(100, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxListTile(
              leading: const SizedBox(width: 24, height: 24),
              title: 'とてもとても長いタイトルであふれてはいけません',
              subtitle: 'とてもとても長いサブタイトルであふれてはいけません',
              trailing: 'とても長い右側のテキスト',
              onTap: () {},
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'does not overflow at 80 logical pixels with leading, the longest '
      'title/subtitle/trailing text, and tappable (regression: reported '
      'as "RIGHT OVERFLOWED BY 94 PIXELS" in the widgetbook catalog\'s '
      'Edge cases page)',
      (WidgetTester tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(80, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxListTile(
              leading: const SizedBox(width: 24, height: 24),
              title: _edgeCaseLongTitle,
              subtitle: _edgeCaseLongSubtitle,
              trailing: _edgeCaseLongTrailing,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'does not overflow at 44 logical pixels (the minimum tap target '
      'width) with leading, the longest title/trailing text, and tappable '
      '(regression: reported as "RIGHT OVERFLOWED BY 130 PIXELS" in the '
      "widgetbook catalog's Edge cases page)",
      (WidgetTester tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(44, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxListTile(
              leading: const SizedBox(width: 24, height: 24),
              title: _edgeCaseLongTitle,
              trailing: _edgeCaseLongTrailing,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shrinks and ellipsizes trailing (instead of overflowing or leaving '
      'trailing at its natural size) once the row is too narrow to fit '
      'title and trailing at their natural sizes',
      (WidgetTester tester) async {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1.0;

        Widget buildTile() => Directionality(
          textDirection: TextDirection.ltr,
          child: CruxListTile(
            leading: const SizedBox(width: 24, height: 24),
            title: 'タイトル',
            trailing: _edgeCaseLongTrailing,
            onTap: () {},
          ),
        );

        // Ample width: trailing has all the room it wants, so it renders at
        // its natural, un-clipped size.
        tester.view.physicalSize = const Size(1000, 800);
        await tester.pumpWidget(buildTile());
        final double wideTrailingWidth = tester
            .getSize(find.text(_edgeCaseLongTrailing))
            .width;

        // Narrow, but nowhere near the pathological floor (leading's fixed
        // 44px frame plus its gaps): there is room to shrink trailing
        // instead of overflowing.
        tester.view.physicalSize = const Size(200, 800);
        await tester.pumpWidget(buildTile());
        await tester.pump();

        expect(tester.takeException(), isNull);
        final double narrowTrailingWidth = tester
            .getSize(find.text(_edgeCaseLongTrailing))
            .width;
        expect(narrowTrailingWidth, lessThan(wideTrailingWidth));
      },
    );

    testWidgets('title and subtitle are single-line with ellipsis', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CruxListTile(
            title: 'タイトル',
            subtitle: 'サブタイトル',
            trailing: '右',
          ),
        ),
      );

      final Text title = tester.widget<Text>(find.text('タイトル'));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);

      final Text subtitle = tester.widget<Text>(find.text('サブタイトル'));
      expect(subtitle.maxLines, 1);
      expect(subtitle.overflow, TextOverflow.ellipsis);
    });
  });

  group('ambient height constraints (regression)', () {
    // Both tests below put a tile in the "pathological" narrow branch (see
    // list_tile.dart:303-304): its own width is below `fixedNonFlexWidth`
    // (leading's fixed 44px frame + gaps), so the OverflowBox at
    // list_tile.dart:313-320 takes over. Neither test above in "overflow
    // safety" catches these, because they all size the *whole test surface*
    // to the narrow width via `tester.view.physicalSize`, which the test
    // binding's root RenderView always reports as a bounded (though maybe
    // tall) size — never `double.infinity`. A real unbounded height only
    // shows up when the tile is a plain (non-Expanded/Flexible) child of a
    // Column, ListView, or SingleChildScrollView along their main/scroll
    // axis, which none of these tests, nor any test in "overflow safety",
    // exercise.
    testWidgets(
      'does not throw when squeezed narrow inside a Column, whose plain '
      '(non-flex) children always receive an unbounded main-axis '
      'constraint regardless of the Column\'s own height (regression: the '
      "OverflowBox's default fit, OverflowBoxFit.max, made its "
      'RenderConstrainedOverflowBox size itself to `constraints.biggest`, '
      'which is infinite here, throwing "was given an infinite size during '
      'layout")',
      (WidgetTester tester) async {
        // Mirrors the widgetbook catalog's Edge cases page structure
        // (widgetbook/lib/usecases/list_tile.dart's `_buildEdgeCases`): a
        // `Column(mainAxisSize: MainAxisSize.min)` whose direct child is a
        // `SizedBox` narrowing the tile to a fixed width. Per
        // RenderFlex._constraintsForNonFlexChild (flex.dart), a Column's
        // plain (non-flex) children get `BoxConstraints(maxWidth: ...)`
        // for their cross axis, which leaves maxHeight at its default of
        // double.infinity — regardless of how tall or short the Column's
        // own incoming constraints are. That's the unbounded height this
        // test needs; no `tester.view` manipulation is needed to produce
        // it.
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 60, // within the reported ~44-80px crash range
                  child: CruxListTile(
                    leading: const SizedBox(width: 24, height: 24),
                    title: _edgeCaseLongTitle,
                    trailing: _edgeCaseLongTrailing,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'hugs its natural content height instead of stretching to fill a '
      'bounded (not infinite) but tall ambient height, in the same '
      "pathological narrow branch (regression: OverflowBoxFit.max's "
      'default sized the OverflowBox to the full ambient height instead of '
      "the row's actual measured height)",
      (WidgetTester tester) async {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1.0;
        // A generously sized surface: the point of this test is the
        // *bound* it hands down being loose (unlike a bare tight root),
        // not the surface being small.
        tester.view.physicalSize = const Size(1000, 800);

        // `Align` loosens both axes to [0, 1000]x[0, 800] (unlike pumping
        // the tile directly under `Directionality`, whose tight root
        // constraints would force *any* child, buggy or not, to exactly
        // 800 tall and defeat this test). The inner `SizedBox` then
        // tightens only the width, leaving height loose — bounded at 800,
        // but not tight to it, which is exactly what a `Column`/`Row`
        // cross axis, `ListView` cross axis, or `Align` hands a child in
        // real layouts.
        Widget buildTile(double width) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: CruxListTile(
                leading: const SizedBox(width: 24, height: 24),
                title: _edgeCaseLongTitle,
                trailing: _edgeCaseLongTrailing,
                onTap: () {},
              ),
            ),
          ),
        );

        // Ample width: not in the pathological branch, so today's
        // (already-correct) layout gives the tile's natural, hugging
        // height under this same loose bound. Nothing about this content
        // (leading's fixed 44px frame, single-line ellipsized title and
        // trailing) changes height when width shrinks, so this is the
        // same height the narrow case below should produce too.
        await tester.pumpWidget(buildTile(400));
        final double naturalHeight = tester
            .getSize(find.byType(CruxListTile))
            .height;

        // The same 44px width as the existing "does not overflow at 44
        // logical pixels" regression test above, which puts the tile in
        // the pathological branch — but this time asserting on the
        // resulting height, which that test never did.
        await tester.pumpWidget(buildTile(44));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final double narrowHeight = tester
            .getSize(find.byType(CruxListTile))
            .height;
        expect(narrowHeight, naturalHeight);
      },
    );
  });

  group('color resolution', () {
    testWidgets(
      'title uses textPrimary, subtitle and trailing use textSecondary',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const CruxListTile(
              title: 'タイトル',
              subtitle: 'サブタイトル',
              trailing: '右',
            ),
          ),
        );

        final Text title = tester.widget<Text>(find.text('タイトル'));
        expect(title.style?.color, CruxColors.light.textPrimary);

        final Text subtitle = tester.widget<Text>(find.text('サブタイトル'));
        expect(subtitle.style?.color, CruxColors.light.textSecondary);

        // The exact weight differs per platform (the `title` token is
        // semibold on Apple platforms, medium on Material ones), so this
        // pins the relationship rather than a value: the title always reads
        // heavier than the subtitle beneath it.
        expect(
          title.style!.fontWeight!.value,
          greaterThan(subtitle.style!.fontWeight!.value),
        );

        final Text trailing = tester.widget<Text>(find.text('右'));
        expect(trailing.style?.color, CruxColors.light.textSecondary);
      },
    );
  });

  group('press feedback', () {
    testWidgets(
      'does not scale while pressed (state layer only, per spec.md decision)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxListTile(title: 'タイトル', onTap: () {})),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(CruxListTile)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        // No Transform (scale) anywhere in the subtree: full-width rows
        // must never shrink on press.
        expect(
          find.descendant(
            of: find.byType(CruxListTile),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );

        await gesture.up();
        await tester.pump();
      },
    );
  });

  group('horizontal padding', () {
    testWidgets(
      'default padding insets content by CruxSpacing.s16 from both edges',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxListTile(title: 'タイトル', trailing: '右'), width: 200),
        );

        final double tileLeft = tester
            .getTopLeft(find.byType(CruxListTile))
            .dx;
        final double tileRight = tester
            .getTopRight(find.byType(CruxListTile))
            .dx;
        final double titleLeft = tester.getTopLeft(find.text('タイトル')).dx;
        final double trailingRight = tester.getTopRight(find.text('右')).dx;

        expect(titleLeft - tileLeft, CruxSpacing.s16);
        expect(tileRight - trailingRight, CruxSpacing.s16);
      },
    );

    testWidgets(
      'padding: EdgeInsets.zero reproduces the previous flush-to-edge '
      'layout (content flush with the tile edges)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const CruxListTile(
              title: 'タイトル',
              trailing: '右',
              padding: EdgeInsets.zero,
            ),
            width: 200,
          ),
        );

        final double tileLeft = tester
            .getTopLeft(find.byType(CruxListTile))
            .dx;
        final double tileRight = tester
            .getTopRight(find.byType(CruxListTile))
            .dx;
        final double titleLeft = tester.getTopLeft(find.text('タイトル')).dx;
        final double trailingRight = tester.getTopRight(find.text('右')).dx;

        expect(titleLeft - tileLeft, 0);
        expect(tileRight - trailingRight, 0);
      },
    );

    testWidgets(
      'a custom padding is honored as-is, not hardcoded to the default or '
      'zero',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const CruxListTile(
              title: 'タイトル',
              trailing: '右',
              padding: EdgeInsets.symmetric(horizontal: CruxSpacing.s24),
            ),
            width: 200,
          ),
        );

        final double tileLeft = tester
            .getTopLeft(find.byType(CruxListTile))
            .dx;
        final double tileRight = tester
            .getTopRight(find.byType(CruxListTile))
            .dx;
        final double titleLeft = tester.getTopLeft(find.text('タイトル')).dx;
        final double trailingRight = tester.getTopRight(find.text('右')).dx;

        expect(titleLeft - tileLeft, CruxSpacing.s24);
        expect(tileRight - trailingRight, CruxSpacing.s24);
      },
    );
  });

  group('semantics', () {
    testWidgets('is marked as a button when onTap is set', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxListTile(title: 'タイトル', onTap: () {})),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(CruxListTile),
      );
      expect(node.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('is not marked as a button when onTap is null', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const CruxListTile(title: 'タイトル', onTap: null)),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(CruxListTile),
      );
      expect(node.flagsCollection.isButton, isFalse);

      handle.dispose();
    });
  });
}
