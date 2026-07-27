// Tests for ChatScreen, one sample screen in this gallery's home index
// (see home_index_page_test.dart for the index itself): a search bar and a
// bottom-pinned composer, both built from CruxInputBar (IB-D13's "the same
// part works as both a search field and a chat composer"), plus a bubble
// list built from CruxCard.
//
// This covers only what a test can pin down: the screen renders with its
// seeded conversation, sending a typed message appends a new bubble, and
// the send button does nothing while the composer is empty (CruxInputBar's
// own contract -- exercised end-to-end here, in a real screen, rather than
// re-testing the atom's unit behavior already covered by
// test/input_bar_test.dart).

import 'package:example/main.dart';
import 'package:example/screens/chat_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Navigates from the home index to ChatScreen, the way a user would.
Future<void> _openChatScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.tap(find.text('チャット'));
  await tester.pumpAndSettle();
}

/// The bottom composer's own text field -- the second CruxInputBar in
/// ChatScreen's tree (the search bar above the message list is the first).
Finder _composerTextField() => find.descendant(
  of: find.byType(CruxInputBar).at(1),
  matching: find.byType(CupertinoTextField),
);

void main() {
  testWidgets(
    'renders with a search bar, a composer, and the seeded messages',
    (WidgetTester tester) async {
      await _openChatScreen(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(CruxInputBar), findsNWidgets(2));
      expect(find.byType(CruxCard), findsNWidgets(3));
      expect(find.text('こんにちは。今日の予定を教えてください。'), findsOneWidget);
    },
  );

  testWidgets('typing a message and tapping send appends a new bubble', (
    WidgetTester tester,
  ) async {
    await _openChatScreen(tester);

    await tester.enterText(_composerTextField(), '明日は在宅にします');
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('送信'));
    await tester.pumpAndSettle();

    expect(find.text('明日は在宅にします'), findsOneWidget);
    expect(find.byType(CruxCard), findsNWidgets(4));

    // Sending clears the composer back to empty, the same round trip
    // LoginScreen's own form does after a successful submit.
    final CupertinoTextField composerField = tester.widget<CupertinoTextField>(
      _composerTextField(),
    );
    expect(composerField.controller!.text, isEmpty);
  });

  testWidgets('the send button does nothing while the composer is empty', (
    WidgetTester tester,
  ) async {
    await _openChatScreen(tester);

    await tester.tap(find.bySemanticsLabel('送信'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // No new bubble appeared, and the seeded conversation is untouched.
    expect(find.byType(CruxCard), findsNWidgets(3));
  });
}
