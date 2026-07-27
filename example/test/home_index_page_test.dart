// Tests for HomeIndexPage: the app's home screen, a gallery index listing
// one sample screen per component use case (see root CLAUDE.md's catalog
// operating rule). Each row is a CruxListTile built from
// title/subtitle text; tapping one pushes to that screen, and each pushed
// screen's shared header (AppHeader) provides a way back.

import 'package:example/main.dart';
import 'package:example/screens/chat_screen.dart';
import 'package:example/screens/compose_screen.dart';
import 'package:example/screens/login_screen.dart';
import 'package:example/screens/task_list_screen.dart';
import 'package:example/widgets/app_header.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists every sample screen with a title and subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    expect(find.text('ログイン'), findsOneWidget);
    expect(
      find.text('CruxTextFormField と Form によるバリデーション付きログインフォーム'),
      findsOneWidget,
    );
    expect(find.text('タスク一覧'), findsOneWidget);
    expect(find.text('カード・チップ・リストなど複数の atom を組み合わせたタスク管理画面'), findsOneWidget);
  });

  testWidgets(
    'tapping the ログイン row reaches LoginScreen, and back returns home',
    (WidgetTester tester) async {
      await tester.pumpWidget(const CruxExampleApp());

      await tester.tap(find.text('ログイン'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppHeader),
          matching: find.text('ログイン'),
        ),
        findsOneWidget,
      );

      // Every pushed screen needs a way back to the index.
      await tester.tap(find.bySemanticsLabel('戻る'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('タスク一覧'), findsOneWidget); // back on the index
    },
  );

  testWidgets('tapping the タスク一覧 row reaches TaskListScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    await tester.tap(find.text('タスク一覧'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('タスク一覧')),
      findsOneWidget,
    );
  });

  testWidgets('the new チャット row is listed and reaches ChatScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    expect(find.text('チャット'), findsOneWidget);
    expect(
      find.text('CruxInputBar による検索欄とチャット入力欄、送信で増える吹き出しリスト'),
      findsOneWidget,
    );

    await tester.tap(find.text('チャット'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('チャット')),
      findsOneWidget,
    );
  });

  testWidgets('the new 新規投稿 row is listed and reaches ComposeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    expect(find.text('新規投稿'), findsOneWidget);
    expect(
      find.text('CruxComposer による投稿本文の入力、文字数上限と画像添付ボタン付き（フルスクリーンダイアログで開く）'),
      findsOneWidget,
    );

    await tester.tap(find.text('新規投稿'));
    await tester.pumpAndSettle();

    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('新規投稿')),
      findsOneWidget,
    );
  });
}
