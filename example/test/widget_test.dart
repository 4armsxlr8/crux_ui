// Regression guard: this app used to be a token/atom catalog (a color
// table, a type scale, a spacing scale, per-variant state grids) before
// that coverage moved to widgetbook/. example/ is now one signed-in mock
// app -- ログイン screen, then a four-tab main shell -- reached the way a
// user reaches it, and none of that catalog content may reappear here.
// Coverage of each individual tab/screen lives in this directory's other
// test files, not here.

import 'package:example/main.dart';
import 'package:example/screens/login_screen.dart';
import 'package:example/screens/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Logs in with valid credentials and advances past the simulated network
/// delay and page-transition animation, landing on [MainShell].
///
/// Uses fixed [WidgetTester.pump] durations rather than
/// [WidgetTester.pumpAndSettle]: while the sign-in is in flight,
/// [LoginScreen] shows a [CruxSpinner], which animates continuously and
/// would make pumpAndSettle time out waiting for it to stop.
Future<void> _logIn(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('launches to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CruxExampleApp());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
  });

  testWidgets(
    'a valid sign-in reaches the four-tab main shell, not a token/atom '
    'catalog',
    (WidgetTester tester) async {
      await _logIn(tester);

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(CruxNavBar<AppTab>), findsOneWidget);
      expect(find.text('ホーム'), findsWidgets);
      // findsWidgets, not findsOneWidget: the ホーム tab's own greeting card
      // shows this app's name as a small label, in addition to the nav
      // item's own tab label below.
      expect(find.text('ミモザ'), findsWidgets);
      expect(find.text('家計簿'), findsOneWidget);
      expect(find.text('設定'), findsOneWidget);

      // The token table, type scale, spacing scale, and per-variant state
      // grid that used to live in this app were withdrawn to widgetbook/
      // and must not come back, on any tab -- skipOffstage: false so this
      // also scans the three tabs IndexedStack keeps mounted but offstage,
      // not only ホーム (the selected one).
      expect(find.text('カラー', skipOffstage: false), findsNothing);
      expect(find.text('タイプスケール', skipOffstage: false), findsNothing);
      expect(find.text('スペーシング', skipOffstage: false), findsNothing);
      expect(find.text('Playground', skipOffstage: false), findsNothing);
      expect(find.text('States matrix', skipOffstage: false), findsNothing);
      expect(find.text('Edge cases', skipOffstage: false), findsNothing);
    },
  );
}
