// Tests for LoginScreen, this app's launch screen: a Form wrapping two
// CruxTextFormFields (email, password), each with its own `validator`,
// and a CruxButton that runs FormState.validate()/save() on tap.
//
// This covers the client-side validation contract (empty vs. malformed
// input on each field), the password field's show/hide toggle, and the
// honest, backend-free success path: per LoginScreen's own class doc, a
// validated form does not check credentials against a server -- it runs a
// brief simulated round trip (a CruxButton.loading spell) and then
// replaces this screen with MainShell.

import 'package:example/main.dart';
import 'package:example/screens/login_screen.dart';
import 'package:example/screens/main_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Pumps the app fresh, landing on [LoginScreen].
Future<void> _pumpLoginScreen(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.pump();
}

void main() {
  testWidgets('an empty submit shows both fields’ validation messages', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);

    // Both fields start pre-filled with demo credentials (see LoginScreen's
    // own doc comment), so this clears them first to exercise the empty-
    // field validation path.
    await tester.enterText(find.byType(CruxTextFormField).at(0), '');
    await tester.enterText(find.byType(CruxTextFormField).at(1), '');
    await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
    await tester.pump();

    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
  });

  testWidgets(
    'the pre-filled demo credentials let a fresh launch sign in with a '
    'single tap, with no typing',
    (WidgetTester tester) async {
      await _pumpLoginScreen(tester);

      await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
    },
  );

  testWidgets('a malformed email shows the email validation message only', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);

    await tester.enterText(
      find.byType(CruxTextFormField).at(0),
      'not-an-email',
    );
    // Long enough to pass the password field's own check, so only the
    // email message is under test here.
    await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
    await tester.pump();

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsNothing);
  });

  testWidgets(
    'a too-short password shows the password validation message only',
    (WidgetTester tester) async {
      await _pumpLoginScreen(tester);

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
    "the password field's show/hide toggle reveals and re-hides the typed "
    'password -- the real, app-supplied icons wired up in LoginScreen '
    '(Material `Icons.visibility_outlined`/`visibility_off_outlined`, since '
    'this sample already depends on material.dart), not anything crux_ui '
    'invents itself',
    (WidgetTester tester) async {
      await _pumpLoginScreen(tester);

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

  testWidgets(
    'a valid submit shows a loading spinner in place of the label while the '
    'simulated round trip is in flight',
    (WidgetTester tester) async {
      await _pumpLoginScreen(tester);

      await tester.enterText(
        find.byType(CruxTextFormField).at(0),
        'taro@example.com',
      );
      await tester.enterText(
        find.byType(CruxTextFormField).at(1),
        'password123',
      );
      await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
      await tester.pump();

      // CruxSpinner animates continuously while it is on screen, so this
      // samples one fixed frame rather than calling pumpAndSettle (which
      // would time out waiting for it to stop).
      expect(find.byType(CruxSpinner), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Drains the simulated round trip's pending Timer before the test
      // ends -- flutter_test fails a test that leaves one running.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'a valid submit replaces the login screen with the four-tab main shell '
    'once the simulated round trip finishes',
    (WidgetTester tester) async {
      await _pumpLoginScreen(tester);

      await tester.enterText(
        find.byType(CruxTextFormField).at(0),
        'taro@example.com',
      );
      await tester.enterText(
        find.byType(CruxTextFormField).at(1),
        'password123',
      );
      await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
    },
  );
}
