// Tests for ComposeScreen, the きろく posting modal reached from the ホーム
// tab's floating きろくを書く button (a MaterialPageRoute(fullscreenDialog:
// true) push, see main_shell_test.dart for the shell it is pushed on top
// of): the screen renders reaching from ホーム with an empty composer, the
// character counter tracks what is typed, 投稿する does nothing while the
// composer is empty, and posting adds the きろく to ホーム's 「きょうのきろく」
// list, shows a confirmation toast, and closes the modal -- CruxComposer's
// own unit behavior (the over-limit highlight, the submit-gating rules
// themselves, and so on) is already covered by the package's own
// composer_test.dart.

import 'package:example/main.dart';
import 'package:example/screens/compose_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Logs in with valid credentials and opens [ComposeScreen] from the ホーム
/// tab's floating きろくを書く button, the way a user would.
Future<void> _openComposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsLabel('きろくを書く'));
  await tester.pumpAndSettle();
}

/// The composer's own text field.
Finder _composerTextField() => find.descendant(
  of: find.byType(CruxComposer),
  matching: find.byType(CupertinoTextField),
);

void main() {
  testWidgets('renders reaching from ホーム, with an empty composer', (
    WidgetTester tester,
  ) async {
    await _openComposeScreen(tester);

    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.byType(CruxComposer), findsOneWidget);
    expect(find.text('0 / 140'), findsOneWidget);
    expect(find.text('画像1件を添付中'), findsNothing);
  });

  testWidgets('the counter tracks the grapheme count as text is typed', (
    WidgetTester tester,
  ) async {
    await _openComposeScreen(tester);

    await tester.enterText(_composerTextField(), 'こんにちは');
    await tester.pumpAndSettle();

    expect(find.text('5 / 140'), findsOneWidget);
  });

  testWidgets('投稿する does nothing while the composer is empty', (
    WidgetTester tester,
  ) async {
    await _openComposeScreen(tester);

    await tester.tap(
      find.widgetWithText(CruxButton, '投稿する'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ComposeScreen), findsOneWidget);
  });

  testWidgets(
    'typing and tapping 投稿する adds the きろく to ホーム, shows a confirmation '
    'toast, and closes the modal',
    (WidgetTester tester) async {
      await _openComposeScreen(tester);

      await tester.enterText(_composerTextField(), '今日は良い天気です');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CruxButton, '投稿する'));
      await tester.pumpAndSettle();

      // Back on ホーム, not still showing the modal.
      expect(find.byType(ComposeScreen), findsNothing);
      expect(find.text('きろくを残したよ'), findsOneWidget);
      expect(find.text('今日は良い天気です'), findsOneWidget);
    },
  );

  testWidgets('the 画像を添付 action shows a removable attachment preview', (
    WidgetTester tester,
  ) async {
    await _openComposeScreen(tester);

    await tester.tap(find.bySemanticsLabel('画像を添付'));
    await tester.pumpAndSettle();

    expect(find.text('画像1件を添付中'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('添付を外す'));
    await tester.pumpAndSettle();

    expect(find.text('画像1件を添付中'), findsNothing);
  });
}
