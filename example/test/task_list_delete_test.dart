// Tests for TaskListScreen's swipe-to-delete + undo flow: each row is a
// Dismissible wrapped in a Semantics(onDismiss: ...) node, whose confirm
// (CruxConfirmDialog) then hide-and-toast (showCruxToast, "元に戻す"
// action) behavior is exercised here through the accessibility fallback --
// SemanticsAction.dismiss on that node -- rather than a raw drag gesture,
// since that fallback drives the exact same confirm/hide/undo flow a swipe
// does (see task_list_screen.dart's own class doc) and is deterministic in a
// widget test where a Dismissible's drag physics/animation timing are not.
// TaskListScreen's other coverage (greeting card, records, filter chips,
// add-task form) is out of scope here.

import 'package:example/main.dart';
import 'package:example/screens/main_shell.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// The task under test: the first row under the default 期限順 sort (see
/// `app_state_flow_test.dart`'s own ordering comment for why), so it is
/// always on screen with no scrolling needed.
const String _targetTask = '牛乳とパンを買う';

/// Logs in with valid credentials and lands on the signed-in main shell's
/// ホーム tab, the way a user would.
Future<void> _loginToHome(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pumpAndSettle();
}

/// Triggers [title]'s row delete through its own `Semantics(onDismiss:
/// ...)` node -- the accessibility path task_list_screen.dart wires to the
/// same confirm-then-hide flow a swipe gesture drives. Requires a live
/// [SemanticsHandle] (`tester.ensureSemantics()`) in the calling test.
Future<void> _dismissTask(WidgetTester tester, String title) async {
  final Finder semanticsFinder = find
      .ancestor(of: find.text(title), matching: find.byType(Semantics))
      .first;
  final SemanticsNode node = tester.getSemantics(semanticsFinder);
  node.owner!.performAction(node.id, SemanticsAction.dismiss);
  await tester.pumpAndSettle();
}

/// Adds a task titled [title] through the bottom "add a task" form, the way
/// a user would -- scrolls it into view first since it sits below the
/// visible task list.
Future<void> _addTask(WidgetTester tester, String title) async {
  final Finder field = find.byType(CruxTextFormField);
  await tester.ensureVisible(field);
  await tester.enterText(field, title);
  final Finder addButton = find.widgetWithText(CruxButton, '追加');
  await tester.ensureVisible(addButton);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
}

/// Confirms the ログアウト dialog from the 設定 tab, the way a user would --
/// used by tests that check what happens to an already-showing toast once
/// the screen that created it is popped and disposed.
Future<void> _logout(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CruxNavBar<AppTab>),
      matching: find.text('設定'),
    ),
  );
  await tester.pumpAndSettle();
  final Finder logoutRow = find.text('ログアウト');
  await tester.ensureVisible(logoutRow);
  await tester.tap(logoutRow);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CruxButton, 'ログアウト'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    "dismissing a task row opens a confirmation naming that task, with "
    'キャンセル and 削除 actions, and does not remove the row yet',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _loginToHome(tester);

      await _dismissTask(tester, _targetTask);

      expect(find.text('「$_targetTask」を削除しますか？'), findsOneWidget);
      expect(find.widgetWithText(CruxButton, 'キャンセル'), findsOneWidget);
      expect(find.widgetWithText(CruxButton, '削除'), findsOneWidget);
      expect(find.text(_targetTask), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('キャンセル closes the confirmation without deleting the row', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _loginToHome(tester);

    await _dismissTask(tester, _targetTask);
    await tester.tap(find.widgetWithText(CruxButton, 'キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('「$_targetTask」を削除しますか？'), findsNothing);
    expect(find.text(_targetTask), findsOneWidget);

    handle.dispose();
  });

  testWidgets(
    '削除 removes the row and shows a toast naming it with a 元に戻す action',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _loginToHome(tester);

      await _dismissTask(tester, _targetTask);
      await tester.tap(find.widgetWithText(CruxButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.text(_targetTask), findsNothing);
      expect(find.text('「$_targetTask」を削除しました'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('元に戻す on the toast restores the deleted row', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _loginToHome(tester);

    await _dismissTask(tester, _targetTask);
    await tester.tap(find.widgetWithText(CruxButton, '削除'));
    await tester.pumpAndSettle();
    expect(find.text(_targetTask), findsNothing);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(find.text(_targetTask), findsOneWidget);

    handle.dispose();
  });

  testWidgets("a task's own checkbox still toggles completion (strikethrough), "
      'unaffected by the row now being swipe-dismissible', (
    WidgetTester tester,
  ) async {
    await _loginToHome(tester);

    final Text titleBefore = tester.widget<Text>(find.text(_targetTask));
    expect(titleBefore.style?.decoration, TextDecoration.none);

    await tester.tap(find.byType(CruxCheckbox).first);
    await tester.pump();

    final Text titleAfter = tester.widget<Text>(find.text(_targetTask));
    expect(titleAfter.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('deleting two same-titled tasks in a row and tapping 元に戻す once '
      'restores both, not just the first', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _loginToHome(tester);

    const String duplicateTitle = '観葉植物に水をやる';
    await _addTask(tester, duplicateTitle);
    await _addTask(tester, duplicateTitle);
    expect(find.text(duplicateTitle), findsNWidgets(2));

    await _dismissTask(tester, duplicateTitle);
    await tester.tap(find.widgetWithText(CruxButton, '削除'));
    await tester.pumpAndSettle();
    expect(find.text(duplicateTitle), findsOneWidget);

    // Same title again -- CruxToastHost treats this as the same
    // message as the first delete's toast and keeps only one card.
    await _dismissTask(tester, duplicateTitle);
    await tester.tap(find.widgetWithText(CruxButton, '削除'));
    await tester.pumpAndSettle();
    expect(find.text(duplicateTitle), findsNothing);
    expect(find.text('元に戻す'), findsOneWidget);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(find.text(duplicateTitle), findsNWidgets(2));

    handle.dispose();
  });

  testWidgets(
    'tapping 元に戻す after logging out while the delete-undo toast is still '
    'showing does not crash',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _loginToHome(tester);

      await _dismissTask(tester, _targetTask);
      await tester.tap(find.widgetWithText(CruxButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('元に戻す'), findsOneWidget);

      // CruxToastHost sits above the Navigator in main.dart, so the
      // toast survives ホーム's TaskListScreen being popped and disposed.
      await _logout(tester);
      expect(find.text('元に戻す'), findsOneWidget);

      await tester.tap(find.text('元に戻す'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      handle.dispose();
    },
  );
}
