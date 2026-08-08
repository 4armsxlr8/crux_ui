// Tests for MainShell, the signed-in app shell: CruxNavBar's four tabs
// (ホーム / ミモザ / 家計簿 / 設定) over an IndexedStack, reached after a
// successful login. This covers what MainShell itself is responsible for --
// all four tabs showing with ホーム selected by default, switching tabs
// showing each one's own screen while keeping the others' state alive
// (IndexedStack never rebuilds an inactive tab from scratch), the ミモザ
// tab's unread badge appearing when a message arrives and clearing once
// that tab is selected, and the nav bar hiding itself while the on-screen
// keyboard is showing. Each tab's own screen content is covered by that
// screen's own test file, not here.

import 'package:example/data/mimosa_world.dart';
import 'package:example/main.dart';
import 'package:example/screens/main_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Logs in with valid credentials and lands on [MainShell], the way a user
/// would.
Future<void> _loginToMainShell(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pumpAndSettle();
}

/// Taps the nav bar tab labeled [label], scoped to [CruxNavBar] itself so
/// it cannot match another screen's own use of the same word (for example
/// ホーム's greeting card also shows the text "ミモザ").
Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CruxNavBar<AppTab>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all four tabs, with ホーム selected by default', (
    WidgetTester tester,
  ) async {
    await _loginToMainShell(tester);

    expect(find.byType(MainShell), findsOneWidget);
    final Finder navBar = find.byType(CruxNavBar<AppTab>);
    expect(navBar, findsOneWidget);
    expect(
      find.descendant(of: navBar, matching: find.text('ホーム')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('ミモザ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('家計簿')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('設定')),
      findsOneWidget,
    );

    // ホーム's own content is already showing.
    expect(find.text(mimosaHomeGreeting).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'switching tabs shows each tab’s own screen and hides the others',
    (WidgetTester tester) async {
      await _loginToMainShell(tester);

      expect(find.text(mimosaHomeGreeting).hitTestable(), findsOneWidget);

      await _tapTab(tester, 'ミモザ');
      expect(find.text(mimosaHomeGreeting).hitTestable(), findsNothing);
      expect(find.text('おやすみ、また明日').hitTestable(), findsOneWidget);

      await _tapTab(tester, '家計簿');
      expect(find.text('おやすみ、また明日').hitTestable(), findsNothing);
      expect(find.text('8月の支出').hitTestable(), findsOneWidget);

      await _tapTab(tester, '設定');
      expect(find.text('8月の支出').hitTestable(), findsNothing);
      expect(find.text('タスクの並び順').hitTestable(), findsOneWidget);

      await _tapTab(tester, 'ホーム');
      expect(find.text('タスクの並び順').hitTestable(), findsNothing);
      expect(find.text(mimosaHomeGreeting).hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'switching away from ホーム and back preserves its own in-progress state',
    (WidgetTester tester) async {
      await _loginToMainShell(tester);

      final Finder addTaskField = find.descendant(
        of: find.byType(CruxTextFormField),
        matching: find.byType(CupertinoTextField),
      );
      await tester.ensureVisible(addTaskField);
      await tester.enterText(addTaskField, '牛乳を買う');
      await tester.pump();

      await _tapTab(tester, '設定');
      await _tapTab(tester, 'ホーム');

      final CupertinoTextField field = tester.widget<CupertinoTextField>(
        addTaskField,
      );
      expect(field.controller!.text, '牛乳を買う');
    },
  );

  testWidgets('adding a task shows an unread badge on the ミモザ tab, cleared by '
      'selecting it', (WidgetTester tester) async {
    await _loginToMainShell(tester);

    final Finder navBar = find.byType(CruxNavBar<AppTab>);
    final Finder badge = find.descendant(of: navBar, matching: find.text('1'));
    expect(badge, findsNothing);

    final Finder addTaskField = find.descendant(
      of: find.byType(CruxTextFormField),
      matching: find.byType(CupertinoTextField),
    );
    await tester.ensureVisible(addTaskField);
    await tester.enterText(addTaskField, '観葉植物に水をやる');
    final Finder addButton = find.widgetWithText(CruxButton, '追加');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();

    expect(badge, findsOneWidget);

    await _tapTab(tester, 'ミモザ');

    expect(badge, findsNothing);
  });

  testWidgets(
    'hides the nav bar while the keyboard is showing, and restores it once '
    'dismissed',
    (WidgetTester tester) async {
      await _loginToMainShell(tester);
      addTearDown(tester.view.resetViewInsets);

      expect(find.byType(CruxNavBar<AppTab>), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      expect(find.byType(CruxNavBar<AppTab>), findsNothing);

      tester.view.resetViewInsets();
      await tester.pump();

      expect(find.byType(CruxNavBar<AppTab>), findsOneWidget);
    },
  );
}
