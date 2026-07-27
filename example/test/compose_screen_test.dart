// Tests for ComposeScreen, one sample screen in this gallery's home index
// (see home_index_page_test.dart for the index itself): a "new post" screen
// built around CruxComposer, reached as the app's first modal route
// (MaterialPageRoute(fullscreenDialog: true), see home_index_page.dart).
//
// This covers only what a test can pin down: the screen renders reaching
// from home with an empty composer, the character counter tracks what is
// typed, the 投稿 button does nothing while the composer is empty and
// posts (then clears the composer and shows a dismissible confirmation)
// once it isn't, and the app-supplied 画像を添付 action shows a removable
// attachment preview -- CruxComposer's own unit behavior (the over-limit
// highlight, the submit-gating rules themselves, and so on) is already
// covered by the package's own composer_test.dart.

import 'package:example/main.dart';
import 'package:example/screens/compose_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Navigates from the home index to ComposeScreen, the way a user would.
Future<void> _openComposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.tap(find.text('新規投稿'));
  await tester.pumpAndSettle();
}

/// The composer's own text field.
Finder _composerTextField() => find.descendant(
  of: find.byType(CruxComposer),
  matching: find.byType(CupertinoTextField),
);

void main() {
  testWidgets('renders reaching from home, with an empty composer', (
    WidgetTester tester,
  ) async {
    await _openComposeScreen(tester);

    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.byType(CruxComposer), findsOneWidget);
    expect(find.text('0 / 140'), findsOneWidget);
    expect(find.text('投稿しました'), findsNothing);
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

  testWidgets('投稿 does nothing while the composer is empty', (
    WidgetTester tester,
  ) async {
    await _openComposeScreen(tester);

    await tester.tap(
      find.widgetWithText(CruxButton, '投稿'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('投稿しました'), findsNothing);
  });

  testWidgets('typing and tapping 投稿 posts, clears the composer, and shows a '
      'dismissible confirmation', (WidgetTester tester) async {
    await _openComposeScreen(tester);

    await tester.enterText(_composerTextField(), '今日は良い天気です');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CruxButton, '投稿'));
    await tester.pumpAndSettle();

    expect(find.text('投稿しました'), findsOneWidget);
    expect(find.text('今日は良い天気です'), findsOneWidget);

    // Posting clears the composer back to empty, the same round trip
    // ChatScreen's own composer makes after a successful send.
    final CupertinoTextField composerField = tester.widget<CupertinoTextField>(
      _composerTextField(),
    );
    expect(composerField.controller!.text, isEmpty);

    await tester.tap(find.bySemanticsLabel('閉じる'));
    await tester.pumpAndSettle();

    expect(find.text('投稿しました'), findsNothing);
  });

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
