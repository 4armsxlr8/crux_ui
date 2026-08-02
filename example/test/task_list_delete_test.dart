// Tests for the delete/undo flow TaskListScreen's task rows gained
// alongside CruxDialog/CruxConfirmDialog/CruxToast: each completable
// row's own CruxIconButton opens a CruxConfirmDialog before the row is
// removed, and the CruxToast shown afterward carries a "元に戻す" action
// that brings the row back. TaskListScreen's pre-existing coverage (the
// light/dark toggle, the card/chip/add-task-form content, the completion
// checkbox) stays in widget_test.dart, unchanged; this file only covers the
// new delete/undo behavior plus one guard that the checkbox still works
// unaffected by the delete button now sitting next to it.

import 'package:example/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Navigates from the home index to TaskListScreen, the way a user would.
Future<void> _openTaskListScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.tap(find.text('タスク一覧'));
  await tester.pumpAndSettle();
}

/// The delete icon button for the task row titled [title], found by the
/// accessible label `_DemoTaskRow` gives it (`'「$title」を削除'` --
/// task_list_screen.dart).
Finder _deleteButtonFor(String title) => find.bySemanticsLabel('「$title」を削除');

void main() {
  testWidgets(
    "tapping a task row's delete button opens a confirmation naming that "
    'task, with キャンセル and 削除 actions, and does not remove the row yet',
    (WidgetTester tester) async {
      await _openTaskListScreen(tester);

      await tester.tap(_deleteButtonFor('買い物メモを作成'));
      await tester.pumpAndSettle();

      expect(find.text('「買い物メモを作成」を削除しますか？'), findsOneWidget);
      expect(find.widgetWithText(CruxButton, 'キャンセル'), findsOneWidget);
      expect(find.widgetWithText(CruxButton, '削除'), findsOneWidget);
      expect(find.text('買い物メモを作成'), findsOneWidget);
    },
  );

  testWidgets('キャンセル closes the confirmation without deleting the row', (
    WidgetTester tester,
  ) async {
    await _openTaskListScreen(tester);

    await tester.tap(_deleteButtonFor('買い物メモを作成'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CruxButton, 'キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('「買い物メモを作成」を削除しますか？'), findsNothing);
    expect(find.text('買い物メモを作成'), findsOneWidget);
  });

  testWidgets(
    '削除 removes the row and shows a toast naming it with a 元に戻す action',
    (WidgetTester tester) async {
      await _openTaskListScreen(tester);

      await tester.tap(_deleteButtonFor('買い物メモを作成'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CruxButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.text('買い物メモを作成'), findsNothing);
      expect(find.text('「買い物メモを作成」を削除しました'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
    },
  );

  testWidgets('元に戻す on the toast restores the deleted row', (
    WidgetTester tester,
  ) async {
    await _openTaskListScreen(tester);

    await tester.tap(_deleteButtonFor('買い物メモを作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CruxButton, '削除'));
    await tester.pumpAndSettle();
    expect(find.text('買い物メモを作成'), findsNothing);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(find.text('買い物メモを作成'), findsOneWidget);
  });

  testWidgets("a task's own checkbox still toggles completion (strikethrough), "
      'unaffected by the delete button now sitting next to it', (
    WidgetTester tester,
  ) async {
    await _openTaskListScreen(tester);

    final Text titleBefore = tester.widget<Text>(find.text('買い物メモを作成'));
    expect(titleBefore.style?.decoration, TextDecoration.none);

    await tester.tap(find.byType(CruxCheckbox).first);
    await tester.pump();

    final Text titleAfter = tester.widget<Text>(find.text('買い物メモを作成'));
    expect(titleAfter.style?.decoration, TextDecoration.lineThrough);
  });
}
