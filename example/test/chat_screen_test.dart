// Tests for ChatScreen, the ミモザ tab of MainShell (see main_shell_test.dart
// for the shell itself): typing a message and sending it appends your own
// bubble immediately, and ミモザ's canned reply lands after AppState's own
// reply delay. CruxInputBar's own unit behavior (the disabled-while-empty
// submit button, and so on) is already covered by the package's own
// input_bar_test.dart -- this only exercises it end-to-end, wired to
// AppState.sendUserMessage, inside a real screen.

import 'package:example/data/mimosa_world.dart';
import 'package:example/main.dart';
import 'package:example/screens/chat_screen.dart';
import 'package:example/screens/main_shell.dart';
import 'package:example/state/app_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Logs in with valid credentials and switches to the ミモザ tab, the way a
/// user would reach [ChatScreen].
Future<void> _openChatTab(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(CruxNavBar<AppTab>),
      matching: find.text('ミモザ'),
    ),
  );
  await tester.pumpAndSettle();
}

/// The bottom composer's own text field -- the second CruxInputBar in
/// ChatScreen's tree (the search bar above the message list is the first).
Finder _composerTextField() => find.descendant(
  of: find.byType(CruxInputBar).at(1),
  matching: find.byType(CupertinoTextField),
);

void main() {
  testWidgets('renders scrolled to the newest seeded message', (
    WidgetTester tester,
  ) async {
    await _openChatTab(tester);

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('おやすみ、また明日'), findsOneWidget);
  });

  testWidgets(
    'sending a message appends it as your own bubble immediately and clears '
    'the composer',
    (WidgetTester tester) async {
      await _openChatTab(tester);

      await tester.enterText(_composerTextField(), '明日は在宅にします');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('送信'));
      await tester.pump();

      expect(find.text('明日は在宅にします'), findsOneWidget);

      final CupertinoTextField composerField = tester
          .widget<CupertinoTextField>(_composerTextField());
      expect(composerField.controller!.text, isEmpty);
    },
  );

  testWidgets('ミモザ replies with the first canned message after the reply '
      'delay, not before', (WidgetTester tester) async {
    await _openChatTab(tester);

    await tester.enterText(_composerTextField(), '明日は在宅にします');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('送信'));
    await tester.pump();

    expect(find.text(mimosaCannedReplies.first), findsNothing);

    await tester.pump(mimosaReplyDelay);
    await tester.pump();

    expect(find.text(mimosaCannedReplies.first), findsOneWidget);
  });

  testWidgets('the send control does nothing while the composer is empty', (
    WidgetTester tester,
  ) async {
    await _openChatTab(tester);

    await tester.tap(find.bySemanticsLabel('送信'), warnIfMissed: false);
    await tester.pump();

    // The seeded conversation is untouched -- no stray bubble appeared.
    expect(find.text('おやすみ、また明日'), findsOneWidget);
  });

  testWidgets(
    "the user's own bubble is accent-filled and ミモザ's stays on the surface "
    "color, matching the mock's visual distinction between the two senders",
    (WidgetTester tester) async {
      await _openChatTab(tester);

      final CruxColors colors = CruxTheme.of(
        tester.element(find.byType(ChatScreen)),
      ).colors;

      // 'おやすみ、また明日' is a seeded user message; 'それでいい!今日もおつかれさま'
      // is the seeded ミモザ reply right before it.
      final Text myBubbleText = tester.widget<Text>(find.text('おやすみ、また明日'));
      expect(myBubbleText.style?.color, colors.onAccent);
      final Container myBubbleContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('おやすみ、また明日'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (myBubbleContainer.decoration! as ShapeDecoration).color,
        colors.accent,
      );

      final Text mimosaBubbleText = tester.widget<Text>(
        find.text('それでいい!今日もおつかれさま'),
      );
      expect(mimosaBubbleText.style?.color, colors.textPrimary);
    },
  );

  testWidgets(
    'dragging the message list dismisses a focused composer, closing the '
    'keyboard so MainShell can show its nav bar again',
    (WidgetTester tester) async {
      await _openChatTab(tester);

      // A real drag only fires ScrollView's onDrag dismiss when it actually
      // scrolls something; the seeded conversation alone does not overflow
      // the default test viewport, so this pads it well past that.
      final AppState appState = AppState.of(
        tester.element(find.byType(ChatScreen)),
      );
      for (var i = 0; i < 20; i++) {
        appState.sendUserMessage('埋め合わせのメッセージ $i');
      }
      await tester.pump();

      await tester.enterText(_composerTextField(), '書きかけの文章');
      await tester.pump();
      final FocusNode composerFocusNode = tester
          .widget<CupertinoTextField>(_composerTextField())
          .focusNode!;
      expect(composerFocusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Positive dy: this list is reverse: true (newest message at the
      // visual bottom), which flips which drag direction has scroll extent
      // to move into from the initial, already-at-the-newest position.
      await tester.drag(find.byType(ListView), const Offset(0, 80));
      await tester.pumpAndSettle();

      expect(composerFocusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets(
    'tapping the message list dismisses a focused composer, closing the '
    'keyboard so MainShell can show its nav bar again',
    (WidgetTester tester) async {
      await _openChatTab(tester);

      await tester.enterText(_composerTextField(), '書きかけの文章');
      await tester.pump();
      final FocusNode composerFocusNode = tester
          .widget<CupertinoTextField>(_composerTextField())
          .focusNode!;
      expect(composerFocusNode.hasFocus, isTrue);

      // Translucent hit-testing means this reaches the dismiss handler even
      // though it lands on a bubble -- bubbles have no tap handler of their
      // own to compete with it.
      await tester.tap(find.byType(ListView));
      await tester.pumpAndSettle();

      expect(composerFocusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets(
    'a ミモザ reply that arrives while the ミモザ tab is already showing does '
    'not raise the unread badge',
    (WidgetTester tester) async {
      await _openChatTab(tester);

      await tester.enterText(_composerTextField(), '明日は在宅にします');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('送信'));
      await tester.pump();

      await tester.pump(mimosaReplyDelay);
      await tester.pump();

      expect(find.text(mimosaCannedReplies.first), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CruxNavBar<AppTab>),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    },
  );
}
