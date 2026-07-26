// Tests for LoginScreen, one sample screen in this gallery's home index
// (see home_index_page_test.dart for the index itself): a Form wrapping
// two CruxTextFormFields (email, password), each with its own
// `validator`, and a CruxButton that runs FormState.validate()/save() on
// tap.
//
// This covers the client-side validation contract (empty vs. malformed
// input on each field) and the honest, backend-free success path: per
// LoginScreen's own class doc, a validated form does not fake a network
// call or an auth result -- it flips this same screen to a visible
// "validated" success view in place, which the last two tests below check
// for, rather than navigating anywhere.

import 'package:example/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Navigates from the home index to LoginScreen, the way a user would.
Future<void> _openLoginScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.tap(find.text('ログイン'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty submit shows both fields’ validation messages', (
    WidgetTester tester,
  ) async {
    await _openLoginScreen(tester);

    await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
    await tester.pump();

    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
  });

  testWidgets('a malformed email shows the email validation message only', (
    WidgetTester tester,
  ) async {
    await _openLoginScreen(tester);

    await tester.enterText(
      find.byType(CruxTextFormField).at(0),
      'not-an-email',
    );
    // Long enough to pass the password field's own check, so only the
    // email message is under test here.
    await tester.enterText(
      find.byType(CruxTextFormField).at(1),
      'password123',
    );
    await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
    await tester.pump();

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsNothing);
  });

  testWidgets(
    'a too-short password shows the password validation message only',
    (WidgetTester tester) async {
      await _openLoginScreen(tester);

      await tester.enterText(
        find.byType(CruxTextFormField).at(0),
        'taro@example.com',
      );
      await tester.enterText(find.byType(CruxTextFormField).at(1), 'short');
      await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
      await tester.pump();

      expect(find.text('メールアドレスの形式が正しくありません'), findsNothing);
      expect(find.text('パスワードは8文字以上で入力してください'), findsOneWidget);
    },
  );

  testWidgets(
    'a valid submit flips to a visible success view, not a fake navigation',
    (WidgetTester tester) async {
      await _openLoginScreen(tester);

      await tester.enterText(
        find.byType(CruxTextFormField).at(0),
        'taro@example.com',
      );
      await tester.enterText(
        find.byType(CruxTextFormField).at(1),
        'password123',
      );
      await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
      await tester.pumpAndSettle();

      // The form is gone, replaced by the honest success view -- still on
      // LoginScreen, not a different screen.
      expect(find.byType(CruxTextFormField), findsNothing);
      expect(find.text('入力内容の検証に成功しました'), findsOneWidget);
      expect(find.text('もう一度試す'), findsOneWidget);
    },
  );

  testWidgets(
    "the password field's show/hide toggle reveals and re-hides the typed "
    'password -- the real, app-supplied icons wired up in LoginScreen '
    '(Material `Icons.visibility_outlined`/`visibility_off_outlined`, since '
    'this sample already depends on material.dart), not anything crux_ui '
    'invents itself',
    (WidgetTester tester) async {
      await _openLoginScreen(tester);

      final Finder passwordField = find.byType(CruxTextFormField).at(1);
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      CupertinoTextField cupertinoFieldOf(Finder field) =>
          tester.widget<CupertinoTextField>(
            find.descendant(
              of: field,
              matching: find.byType(CupertinoTextField),
            ),
          );

      expect(cupertinoFieldOf(passwordField).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(cupertinoFieldOf(passwordField).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(cupertinoFieldOf(passwordField).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    },
  );

  testWidgets('もう一度試す resets back to the empty form', (
    WidgetTester tester,
  ) async {
    await _openLoginScreen(tester);

    await tester.enterText(
      find.byType(CruxTextFormField).at(0),
      'taro@example.com',
    );
    await tester.enterText(
      find.byType(CruxTextFormField).at(1),
      'password123',
    );
    await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('もう一度試す'));
    await tester.pumpAndSettle();

    expect(find.byType(CruxTextFormField), findsNWidgets(2));
    expect(find.text('入力内容の検証に成功しました'), findsNothing);
  });
}
