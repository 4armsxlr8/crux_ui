// Tests for the shared, cross-tab AppState/ThemeModeScope wiring the login
// -> MainShell mock app is built around -- not any one screen's own local
// behavior (see task_list_delete_test.dart / settings_screen_test.dart /
// chat_screen_test.dart for those). Each test here starts from a fresh
// login and pins one thing a real user could notice moving between tabs:
//
// 1. Adding a task on ホーム appends a ミモザ chat reaction and raises the
//    ミモザ tab's unread badge.
// 2. Posting a きろく on ホーム appends a different ミモザ chat reaction and
//    raises the ミモザ tab's unread badge.
// 3. Changing 並び順 on 設定 re-sorts ホーム's task list.
// 4. Flipping ダークモード on 設定 changes the ambient CruxTheme's
//    brightness everywhere, including a tab that isn't the one currently
//    showing.

import 'package:example/data/mimosa_world.dart';
import 'package:example/main.dart';
import 'package:example/screens/main_shell.dart';
import 'package:example/screens/task_list_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

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

/// Taps the nav bar item labeled [label], scoped to [CruxNavBar] --
/// every tab stays mounted inside [MainShell]'s `IndexedStack`, so an
/// unscoped `find.text(label)` could also match that same label appearing
/// inside whichever screen it names (ホーム's own headline, for example).
Future<void> _tapNavItem(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CruxNavBar<AppTab>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding a task on ホーム appends a ミモザ chat reaction and raises the '
      'ミモザ tab unread badge', (WidgetTester tester) async {
    await _loginToHome(tester);

    await tester.enterText(find.byType(CruxTextFormField), 'ゴミを出す');
    final Finder addButton = find.widgetWithText(CruxButton, '追加');
    // The add-task form sits below the seeded task list, past the default
    // test surface's bottom edge.
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();

    // The unread badge, scoped to the nav bar so it can't match some
    // unrelated "1" elsewhere on ホーム.
    expect(
      find.descendant(
        of: find.byType(CruxNavBar<AppTab>),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await _tapNavItem(tester, 'ミモザ');

    expect(find.text('「ゴミを出す」をリストに入れたよ!応援してるね💪'), findsOneWidget);
  });

  testWidgets('posting a きろく on ホーム appends a ミモザ chat reaction and raises the '
      'ミモザ tab unread badge', (WidgetTester tester) async {
    await _loginToHome(tester);

    await tester.tap(find.bySemanticsLabel(mimosaComposeButtonLabel));
    await tester.pumpAndSettle();

    final Finder composerField = find.descendant(
      of: find.byType(CruxComposer),
      matching: find.byType(CupertinoTextField),
    );
    await tester.enterText(composerField, '今日は涼しかった');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CruxButton, mimosaRecordSubmitLabel),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(CruxNavBar<AppTab>),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await _tapNavItem(tester, 'ミモザ');

    expect(find.text(mimosaRecordAddedReply), findsOneWidget);
  });

  testWidgets("changing 並び順 on 設定 re-sorts ホーム's task list", (
    WidgetTester tester,
  ) async {
    await _loginToHome(tester);

    // Default sort is 期限順 (soonest due date first): among today's tasks,
    // 牛乳とパンを買う was added before 歯医者の予約確認's due date group, so it
    // renders above it.
    final double milkDyBefore = tester.getTopLeft(find.text('牛乳とパンを買う')).dy;
    final double dentalDyBefore = tester.getTopLeft(find.text('歯医者の予約確認')).dy;
    expect(milkDyBefore, lessThan(dentalDyBefore));

    await _tapNavItem(tester, '設定');
    await tester.tap(find.text('追加順'));
    await tester.pumpAndSettle();
    await _tapNavItem(tester, 'ホーム');

    // 追加順 (oldest added first): 歯医者の予約確認 was seeded before
    // 牛乳とパンを買う, so the order flips.
    final double milkDyAfter = tester.getTopLeft(find.text('牛乳とパンを買う')).dy;
    final double dentalDyAfter = tester.getTopLeft(find.text('歯医者の予約確認')).dy;
    expect(dentalDyAfter, lessThan(milkDyAfter));
  });

  testWidgets(
    'flipping ダークモード on 設定 changes the ambient CruxTheme brightness '
    'everywhere, including a tab not currently showing',
    (WidgetTester tester) async {
      await _loginToHome(tester);

      final BuildContext homeContextBefore = tester.element(
        find.byType(TaskListScreen),
      );
      expect(CruxTheme.of(homeContextBefore).brightness, Brightness.light);

      await _tapNavItem(tester, '設定');
      final Finder darkModeSwitch = find.byType(CruxSwitch);
      await tester.ensureVisible(darkModeSwitch);
      await tester.tap(darkModeSwitch);
      await tester.pumpAndSettle();
      // MainShell's other tabs stay mounted (Offstage, not disposed) while
      // 設定 is selected, so CruxTheme's InheritedWidget update already
      // reached ホーム's Element here -- switching back only makes it
      // paintable/findable again for this assertion.
      await _tapNavItem(tester, 'ホーム');

      final BuildContext homeContextAfter = tester.element(
        find.byType(TaskListScreen),
      );
      expect(CruxTheme.of(homeContextAfter).brightness, Brightness.dark);
    },
  );
}
