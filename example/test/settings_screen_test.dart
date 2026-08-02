// Tests for SettingsScreen, one sample screen in this gallery's home index
// (see home_index_page_test.dart for the index itself): a real settings
// form built around CruxSlider (a discrete 文字サイズ slider using
// `divisions`, and a continuous 通知音量 slider with none) and a three-way
// CruxSegmentedControl (並び順), reached from the home index's "設定" row.
//
// This covers only what a test can pin down: the screen renders with its
// default values, dragging each slider updates the value text shown next to
// its label, and tapping a different segment updates the segmented
// control's own selected semantics -- CruxSlider's/
// CruxSegmentedControl's own unit behavior (drag math, snapping, the kira
// sheen, and so on) is already covered by the package's own
// slider_test.dart/segmented_control_test.dart.

import 'dart:ui' show Tristate;

import 'package:example/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Navigates from the home index to SettingsScreen, the way a user would.
Future<void> _openSettingsScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.tap(find.text('設定'));
  await tester.pumpAndSettle();
}

/// The nearest [Semantics] ancestor of a segmented control option's own
/// label -- the node [CruxSegmentedControl] builds for that segment
/// (mirrors the package's own segmented_control_test.dart's
/// `_segmentSemantics`).
Finder _segmentSemantics(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Semantics)).first;

/// Changes all three of [SettingsScreen]'s settings away from their
/// defaults, the way a reader of the screen actually would: drags both
/// sliders all the way right (標準 -> 特大 / 70% -> 100%) and selects the
/// 期限順 segment. Shared by the "設定をリセット" tests below.
Future<void> _changeAllSettings(WidgetTester tester) async {
  await tester.drag(find.byType(CruxSlider).first, const Offset(2000, 0));
  await tester.pump();
  await tester.drag(find.byType(CruxSlider).last, const Offset(2000, 0));
  await tester.pump();
  await tester.tap(find.text('期限順'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders reaching from home, with both sliders and the segmented '
      'control at their default values', (WidgetTester tester) async {
    await _openSettingsScreen(tester);

    expect(find.text('文字サイズ'), findsOneWidget);
    // 2, not 1: CruxSlider always builds its own drag-value bubble (kept
    // invisible via Opacity while not dragging -- see slider.dart's
    // `_buildBubble`), which renders the exact same formatted string as this
    // screen's own value label next to it.
    expect(find.text('標準'), findsNWidgets(2));
    expect(find.text('通知音量'), findsOneWidget);
    expect(find.text('70%'), findsNWidgets(2));
    expect(find.text('並び順'), findsOneWidget);
    expect(find.text('追加順'), findsOneWidget);
    expect(find.text('期限順'), findsOneWidget);
    expect(find.text('優先度順'), findsOneWidget);
    expect(find.byType(CruxSlider), findsNWidgets(2));
  });

  testWidgets('dragging the 文字サイズ slider all the way right selects 特大', (
    WidgetTester tester,
  ) async {
    await _openSettingsScreen(tester);

    // The 文字サイズ slider is declared before 通知音量, so it is the first
    // CruxSlider in the tree.
    await tester.drag(find.byType(CruxSlider).first, const Offset(2000, 0));
    await tester.pump();

    // 2 (row label + the slider's own hidden drag-value bubble) -- see the
    // "renders" test above's comment on why.
    expect(find.text('特大'), findsNWidgets(2));
    expect(find.text('標準'), findsNothing);
  });

  testWidgets('dragging the 通知音量 slider all the way right shows 100%', (
    WidgetTester tester,
  ) async {
    await _openSettingsScreen(tester);

    await tester.drag(find.byType(CruxSlider).last, const Offset(2000, 0));
    await tester.pump();

    expect(find.text('100%'), findsNWidgets(2));
    expect(find.text('70%'), findsNothing);
  });

  testWidgets('tapping a different 並び順 segment updates the selection', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _openSettingsScreen(tester);

    expect(
      tester.getSemantics(_segmentSemantics('追加順')).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.text('期限順'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(_segmentSemantics('期限順')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(_segmentSemantics('追加順')).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    handle.dispose();
  });

  // Coverage for the "設定のリセット" footer action SettingsScreen gained
  // alongside CruxConfirmDialog/showCruxToast, mirroring
  // task_list_delete_test.dart's own confirm/cancel/undo shape for its
  // delete flow: a CruxButton opens a CruxConfirmDialog before anything
  // changes, confirming resets every setting on this screen to its default
  // and shows a toast with a "元に戻す" action that restores the values from
  // just before the reset (not the screen's original defaults, in case the
  // reset itself changed something that was already non-default).

  testWidgets('tapping 設定をリセット opens a confirmation naming what will reset, '
      'without changing any value yet', (WidgetTester tester) async {
    await _openSettingsScreen(tester);
    await _changeAllSettings(tester);

    await tester.tap(find.widgetWithText(CruxButton, '設定をリセット'));
    await tester.pumpAndSettle();

    expect(find.text('設定をリセットしますか？'), findsOneWidget);
    expect(find.text('文字サイズ・通知音量・並び順が初期値に戻ります。'), findsOneWidget);
    expect(find.widgetWithText(CruxButton, 'キャンセル'), findsOneWidget);
    expect(find.widgetWithText(CruxButton, 'リセット'), findsOneWidget);
    // Still showing the changed values, not the defaults -- the dialog
    // itself must not have applied anything yet.
    expect(find.text('特大'), findsNWidgets(2));
  });

  testWidgets(
    'キャンセル on the reset confirmation leaves changed values untouched',
    (WidgetTester tester) async {
      await _openSettingsScreen(tester);
      await _changeAllSettings(tester);

      await tester.tap(find.widgetWithText(CruxButton, '設定をリセット'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CruxButton, 'キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('設定をリセットしますか？'), findsNothing);
      expect(find.text('特大'), findsNWidgets(2));
      expect(find.text('100%'), findsNWidgets(2));
    },
  );

  testWidgets(
    'confirming the reset restores every value to its default and shows a '
    'confirmation toast with a 元に戻す action',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSettingsScreen(tester);
      await _changeAllSettings(tester);

      await tester.tap(find.widgetWithText(CruxButton, '設定をリセット'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CruxButton, 'リセット'));
      await tester.pumpAndSettle();

      expect(find.text('標準'), findsNWidgets(2));
      expect(find.text('特大'), findsNothing);
      expect(find.text('70%'), findsNWidgets(2));
      expect(find.text('100%'), findsNothing);
      expect(
        tester
            .getSemantics(_segmentSemantics('追加順'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(find.text('設定をリセットしました'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets(
    '元に戻す on the reset toast restores the values from just before the '
    'reset',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSettingsScreen(tester);
      await _changeAllSettings(tester);

      await tester.tap(find.widgetWithText(CruxButton, '設定をリセット'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CruxButton, 'リセット'));
      await tester.pumpAndSettle();
      expect(find.text('標準'), findsNWidgets(2));

      await tester.tap(find.text('元に戻す'));
      await tester.pumpAndSettle();

      expect(find.text('特大'), findsNWidgets(2));
      expect(find.text('100%'), findsNWidgets(2));
      expect(
        tester
            .getSemantics(_segmentSemantics('期限順'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      handle.dispose();
    },
  );

  // Coverage for the 通知音量 row's small "テスト" button (CruxButton): unlike
  // "設定をリセット", tapping this shows a showCruxToast immediately, with no
  // CruxConfirmDialog in between, whose message reports whatever the
  // 通知音量 slider currently reads.

  testWidgets("tapping 通知音量's テスト button shows a toast reporting the current "
      'volume, with no confirmation dialog', (WidgetTester tester) async {
    await _openSettingsScreen(tester);

    await tester.tap(find.widgetWithText(CruxButton, 'テスト'));
    await tester.pumpAndSettle();

    expect(find.text('設定をリセットしますか？'), findsNothing);
    expect(find.text('通知音量は70%です'), findsOneWidget);
  });

  testWidgets("dragging 通知音量 before tapping テスト reports the new volume, not "
      'the default', (WidgetTester tester) async {
    await _openSettingsScreen(tester);

    await tester.drag(find.byType(CruxSlider).last, const Offset(2000, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(CruxButton, 'テスト'));
    await tester.pumpAndSettle();

    expect(find.text('通知音量は100%です'), findsOneWidget);
  });
}
