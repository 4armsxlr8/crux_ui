// Tests for SettingsScreen, the 設定 tab of the signed-in main shell: a
// CruxSegmentedControl bound straight to the shared AppState.sortOrder
// (並び順), a 文字サイズ slider (discrete, via `divisions`) and a 通知音量
// slider (continuous) that are local to this screen, and a
// CruxConfirmDialog-then-showCruxToast reset flow for those two local
// settings only -- 並び順 is shared app state, not a local display
// preference, so 設定をリセット deliberately leaves it untouched (see this
// screen's own class doc). ダークモード's cross-tab theming effect and
// データを同期 have their own coverage in app_state_flow_test.dart and are
// not repeated here -- only ダークモード's own Semantics merge is (below).
//
// This covers only what a test can pin down: the screen renders with its
// default values (matching AppState's own defaults), dragging each slider
// updates the value text shown next to its label, tapping a different
// segment updates the segmented control's own selected semantics, the
// reset/undo round trip, and the ダークモード row's merged accessibility
// semantics -- CruxSlider's/CruxSegmentedControl's own unit behavior
// (drag math, snapping, the kira sheen, and so on) is already covered by
// the package's own slider_test.dart/segmented_control_test.dart.

import 'dart:ui' show Tristate;

import 'package:example/main.dart';
import 'package:example/screens/main_shell.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Logs in with valid credentials, then switches to the 設定 tab, the way a
/// user would.
Future<void> _openSettingsScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pumpAndSettle();

  // Scoped to the nav bar: every tab stays mounted inside MainShell's
  // IndexedStack, so an unscoped find.text('設定') would also match
  // SettingsScreen's own headline once it exists in the tree.
  await tester.tap(
    find.descendant(
      of: find.byType(CruxNavBar<AppTab>),
      matching: find.text('設定'),
    ),
  );
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
/// 名前順 segment (AppState's own default is 期限順). Shared by the
/// "設定をリセット" tests below.
Future<void> _changeAllSettings(WidgetTester tester) async {
  await tester.drag(find.byType(CruxSlider).first, const Offset(2000, 0));
  await tester.pump();
  await tester.drag(find.byType(CruxSlider).last, const Offset(2000, 0));
  await tester.pump();
  await tester.tap(find.text('名前順'));
  await tester.pumpAndSettle();
}

/// Scrolls 設定をリセット into view and taps it -- the screen's scrollable
/// content is taller than the default test surface, so the button starts
/// off-screen below it.
Future<void> _openResetConfirmation(WidgetTester tester) async {
  final Finder resetButton = find.widgetWithText(CruxButton, '設定をリセット');
  await tester.ensureVisible(resetButton);
  await tester.tap(resetButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'renders reaching from login, with both sliders and the segmented '
    'control at their default values',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSettingsScreen(tester);

      expect(find.text('文字サイズ'), findsOneWidget);
      // 2, not 1: CruxSlider always builds its own drag-value bubble
      // (kept invisible via Opacity while not dragging -- see slider.dart's
      // `_buildBubble`), which renders the exact same formatted string as
      // this screen's own value label next to it.
      expect(find.text('標準'), findsNWidgets(2));
      expect(find.text('通知音量'), findsOneWidget);
      expect(find.text('70%'), findsNWidgets(2));
      expect(find.text('タスクの並び順'), findsOneWidget);
      expect(find.text('追加順'), findsOneWidget);
      expect(find.text('期限順'), findsOneWidget);
      expect(find.text('名前順'), findsOneWidget);
      expect(find.byType(CruxSlider), findsNWidgets(2));
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

    await tester.tap(find.text('名前順'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(_segmentSemantics('名前順')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(_segmentSemantics('期限順')).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    handle.dispose();
  });

  // Coverage for the "設定をリセット" footer action: a CruxButton opens a
  // CruxConfirmDialog before anything changes, confirming resets 文字サイズ
  // and 通知音量 to their defaults (並び順 is untouched -- see this file's own
  // top comment) and shows a toast with a "元に戻す" action that restores the
  // values from just before the reset.

  testWidgets('tapping 設定をリセット opens a confirmation naming what will reset, '
      'without changing any value yet', (WidgetTester tester) async {
    await _openSettingsScreen(tester);
    await _changeAllSettings(tester);

    await _openResetConfirmation(tester);

    expect(find.text('設定をリセットしますか？'), findsOneWidget);
    expect(find.text('文字サイズ・通知音量が初期値に戻ります。'), findsOneWidget);
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

      await _openResetConfirmation(tester);
      await tester.tap(find.widgetWithText(CruxButton, 'キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('設定をリセットしますか？'), findsNothing);
      expect(find.text('特大'), findsNWidgets(2));
      expect(find.text('100%'), findsNWidgets(2));
    },
  );

  testWidgets('confirming the reset restores 文字サイズ/通知音量 to their defaults, '
      'leaves 並び順 untouched, and shows a confirmation toast with a 元に戻す '
      'action', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _openSettingsScreen(tester);
    await _changeAllSettings(tester);

    await _openResetConfirmation(tester);
    await tester.tap(find.widgetWithText(CruxButton, 'リセット'));
    await tester.pumpAndSettle();

    expect(find.text('標準'), findsNWidgets(2));
    expect(find.text('特大'), findsNothing);
    expect(find.text('70%'), findsNWidgets(2));
    expect(find.text('100%'), findsNothing);
    // 並び順 is shared AppState, not a local display preference -- the
    // reset leaves whatever _changeAllSettings selected (名前順) alone.
    expect(
      tester.getSemantics(_segmentSemantics('名前順')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('設定をリセットしました'), findsOneWidget);
    expect(find.text('元に戻す'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('元に戻す on the reset toast restores 文字サイズ/通知音量 to the values from '
      'just before the reset', (WidgetTester tester) async {
    await _openSettingsScreen(tester);
    await _changeAllSettings(tester);

    await _openResetConfirmation(tester);
    await tester.tap(find.widgetWithText(CruxButton, 'リセット'));
    await tester.pumpAndSettle();
    expect(find.text('標準'), findsNWidgets(2));

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(find.text('特大'), findsNWidgets(2));
    expect(find.text('100%'), findsNWidgets(2));
  });

  testWidgets(
    'tapping 元に戻す after logging out while the reset-undo toast is still '
    'showing does not crash',
    (WidgetTester tester) async {
      await _openSettingsScreen(tester);
      await _changeAllSettings(tester);

      await _openResetConfirmation(tester);
      await tester.tap(find.widgetWithText(CruxButton, 'リセット'));
      await tester.pumpAndSettle();
      expect(find.text('元に戻す'), findsOneWidget);

      // CruxToastHost sits above the Navigator in main.dart, so the
      // toast survives SettingsScreen being popped and disposed by
      // logging out.
      final Finder logoutRow = find.text('ログアウト');
      await tester.ensureVisible(logoutRow);
      await tester.tap(logoutRow);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CruxButton, 'ログアウト'));
      await tester.pumpAndSettle();
      expect(find.text('元に戻す'), findsOneWidget);

      await tester.tap(find.text('元に戻す'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  // Coverage for the 通知音量 row's own small "確認" button (CruxButton):
  // unlike "設定をリセット", tapping this shows a showCruxToast immediately,
  // with no CruxConfirmDialog in between, whose message reports whatever
  // the 通知音量 slider currently reads.

  testWidgets("tapping 通知音量's 確認 button shows a toast reporting the current "
      'volume, with no confirmation dialog', (WidgetTester tester) async {
    await _openSettingsScreen(tester);

    await tester.tap(find.widgetWithText(CruxButton, '確認'));
    await tester.pumpAndSettle();

    expect(find.text('設定をリセットしますか？'), findsNothing);
    expect(find.text('通知音量は70%です'), findsOneWidget);
  });

  testWidgets("dragging 通知音量 before tapping 確認 reports the new volume, not "
      'the default', (WidgetTester tester) async {
    await _openSettingsScreen(tester);

    await tester.drag(find.byType(CruxSlider).last, const Offset(2000, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(CruxButton, '確認'));
    await tester.pumpAndSettle();

    expect(find.text('通知音量は100%です'), findsOneWidget);
  });

  // Coverage for the ダークモード row's Semantics: MergeSemantics folds the
  // "ダークモード" label into CruxSwitch's own toggled/tap semantics node,
  // so a screen reader announces both together rather than an unlabeled
  // switch next to a separate, non-interactive label.

  testWidgets('ダークモード label and toggled state merge onto CruxSwitch’s own '
      'semantics node', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _openSettingsScreen(tester);

    // getSemanticsData(), not the node's own bare flags/label getters:
    // CruxSwitch's `container: true` still gives it its own
    // SemanticsNode below the MergeSemantics boundary (merely flagged
    // `isMergedIntoParent`), so only the dynamic merge getSemanticsData()
    // performs reflects what a screen reader actually announces --
    // reading the node's bare fields would report it as still unmerged.
    final SemanticsData data = tester
        .getSemantics(find.byType(CruxSwitch))
        .getSemanticsData();

    expect(data.label, 'ダークモード');
    // Tristate.isFalse (not Tristate.none): proves both that the toggled
    // flag reached this merged data at all and that it reads "off",
    // matching AppState's initial ダークモード value.
    expect(data.flagsCollection.isToggled, Tristate.isFalse);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });
}
